#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# supervisor.py: Generate PIA settings and recover sustained Gluetun outages in one process.
#
# The supervisor:
#   - Invokes unmodified upstream PIA scripts through the generation adapter.
#   - Validates and saves matching configuration before reporting startup readiness.
#   - Reconciles uncertain API updates before generating another replacement.
#   - Uses bounded subprocesses, a monotonic clock, and interruptible shutdown.
#

"""Generate PIA settings and recover sustained Gluetun outages in one process."""

import ipaddress
import logging
import os
import re
import shutil
import signal
import subprocess
import tempfile
import time
from contextlib import contextmanager
from dataclasses import dataclass
from enum import Enum, auto
from pathlib import Path

from .client import APIUnavailable, Client
from .config import Config, ConfigurationError
from .settings import InvalidSettings, Store, assignments, contains_settings

LOG = logging.getLogger("privateerr")


class Shutdown(BaseException):
    """Unwind active work on container shutdown without treating it as a recovery failure."""


class GenerationFailed(Exception):
    """Report failed or timed-out upstream generation without exposing its environment."""


class Pending(Enum):
    """Describe whether an earlier update permits another recovery decision."""

    RESOLVED = auto()
    UNAVAILABLE = auto()
    UNHEALTHY = auto()


@dataclass(frozen=True)
class Endpoint:
    ip: str
    name: str


def select_endpoint(
    catalog: dict, region: str, current: str, failed: set[str], *, pinned: bool, forwarding: bool
) -> Endpoint:
    """Prefer untried eligible endpoints in the saved region, then the permitted current endpoint."""
    eligible = []
    for item in catalog["regions"]:
        if not isinstance(item, dict):
            continue
        if forwarding and item.get("port_forward") is not True:
            continue
        if pinned and item.get("id") != region:
            continue
        servers = item.get("servers", {})
        if not isinstance(servers, dict) or not isinstance(servers.get("wg"), list):
            continue
        for server in servers["wg"]:
            try:
                ip = str(ipaddress.IPv4Address(server["ip"]))
                name = server["cn"]
                if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]*", name):
                    continue
            except (KeyError, ValueError, TypeError):
                continue
            eligible.append((item.get("id") != region, Endpoint(ip, name)))
    eligible.sort(key=lambda item: item[0])
    for _, endpoint in eligible:
        if endpoint.ip not in failed:
            return endpoint
    for _, endpoint in eligible:
        if endpoint.ip == current:
            return endpoint
    raise GenerationFailed("No permitted endpoint is available.")


def reap_children() -> None:
    """Collect exited descendants adopted when the supervisor runs as container PID 1."""
    while True:
        try:
            pid, _ = os.waitpid(-1, os.WNOHANG)
        except ChildProcessError:
            return
        if pid == 0:
            return


def stop_group(process: subprocess.Popen) -> None:
    """Stop the generator and any surviving descendants before removing staged secrets."""
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass
    finally:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()


class Generator:
    """Keep shell at the upstream integration boundary and supervise its whole process group."""

    def __init__(self, config: Config, store: Store):
        self.config = config
        self.store = store

    @contextmanager
    def generate(self, endpoint: Endpoint | None = None):
        with tempfile.TemporaryDirectory(
            prefix=".privateerr-stage.", dir=self.config.config_path.parent
        ) as temporary:
            stage = Path(temporary)
            env = self.config.environment.copy()
            env.update(
                PIA_CONF_PATH=str(stage / "wg0.conf"),
                PRIVATEERR_METADATA_PATH=str(stage / "privateerr.env"),
                PRIVATEERR_LOG_PATH=str(self.config.log_path),
                PRIVATEERR_HEALTHCHECK_MARKER=str(self.config.marker),
            )
            for name in ("PRIVATEERR_CANDIDATE_IP", "PRIVATEERR_CANDIDATE_NAME"):
                env.pop(name, None)
            if endpoint is not None:
                env.update(
                    PRIVATEERR_CANDIDATE_IP=endpoint.ip, PRIVATEERR_CANDIDATE_NAME=endpoint.name
                )
            process = subprocess.Popen(
                ["bash", str(self.config.bin_home / "privateerr-generate.sh")],
                env=env,
                stdin=subprocess.DEVNULL,
                start_new_session=True,
            )
            try:
                try:
                    code = process.wait(timeout=self.config.generation_timeout)
                except subprocess.TimeoutExpired:
                    raise GenerationFailed("PIA generation exceeded its deadline.") from None
                if code != 0:
                    raise GenerationFailed("PIA generation failed; retained saved configuration.")
            finally:
                stop_group(process)
                reap_children()
            self.store.candidate_settings(stage)
            yield stage


class Supervisor:
    """Make one recovery decision at a time with injectable I/O and a monotonic clock."""

    def __init__(
        self,
        config: Config,
        store: Store,
        client: Client,
        generator: Generator,
        *,
        clock=time.monotonic,
        wait=time.sleep,
    ):
        self.config = config
        self.store = store
        self.client = client
        self.generator = generator
        self.clock = clock
        self.wait = wait
        self.failed_since = None
        self.next_attempt = 0.0
        self.delay = config.cooldown
        self.failed_ips: set[str] = set()
        self.last_message = ""

    def status(self, message: str) -> None:
        if message != self.last_message:
            LOG.info(message)
            self.last_message = message

    def resolve_pending(self) -> Pending:
        if not self.store.pending.exists():
            return Pending.RESOLVED
        if not (self.store.pending / "ready").is_file():
            shutil.rmtree(self.store.pending)
            return Pending.RESOLVED
        try:
            candidate = self.store.candidate_settings(self.store.pending)
            active = self.client.get("/v1/vpn/settings")
            if not contains_settings(active, candidate):
                self.status(
                    "Gluetun did not retain the pending settings; keeping the last saved configuration."
                )
                shutil.rmtree(self.store.pending)
                return Pending.RESOLVED
            if not self.client.healthy():
                return Pending.UNHEALTHY
            self.store.publish(self.store.pending)
            shutil.rmtree(self.store.pending)
        except (APIUnavailable, InvalidSettings, OSError):
            return Pending.UNAVAILABLE
        self.failed_ips.clear()
        LOG.info(
            "Gluetun tunnel recovered; saved the matching WireGuard configuration and PIA metadata."
        )
        if self.config.environment.get("PIA_PF") == "true":
            try:
                port = self.client.get("/v1/portforward").get("port", 0)
                assigned = isinstance(port, int) and port > 0
            except APIUnavailable:
                assigned = False
            LOG.info(
                "Gluetun reports an assigned forwarded port."
                if assigned
                else "Tunnel is healthy; Gluetun is still responsible for restoring port forwarding."
            )
        return Pending.RESOLVED

    def recover(self) -> None:
        active = self.client.get("/v1/vpn/settings")
        if active.get("type") != "wireguard" or active.get("provider", {}).get("name") != "custom":
            raise GenerationFailed("Recovery requires Gluetun's custom WireGuard provider.")
        endpoint = None
        token = self.config.environment.get("DIP_TOKEN", "no")
        if not token or token.startswith(("n", "N")):
            current = active["provider"]["server_selection"]["wireguard"]["endpoint_ip"]
            self.failed_ips.add(current)
            pinned = self.config.environment.get("AUTOCONNECT", "true") == "false"
            region = assignments(self.config.metadata_path).get("PIA_REGION_ID", "unknown")
            if pinned:
                region = self.config.environment["PREFERRED_REGION"]
            endpoint = select_endpoint(
                self.client.catalog(),
                region,
                current,
                self.failed_ips,
                pinned=pinned,
                forwarding=self.config.environment.get("PIA_PF") == "true",
            )
        LOG.info("Sustained tunnel failure; generating a fresh PIA registration.")
        with self.generator.generate(endpoint) as stage:
            # Recheck after generation because the operator or tunnel may have changed state.
            if self.client.get("/v1/vpn/status").get("status") not in ("running", "crashed"):
                return
            if self.client.healthy():
                LOG.info(
                    "Gluetun recovered during generation; leaving the running tunnel unchanged."
                )
                return
            self.store.retain(stage, self.store.pending)
            try:
                self.client.apply(self.store.candidate_settings(stage))
            except APIUnavailable:
                LOG.info("Settings update was not confirmed; checking Gluetun before retrying.")

    def step(self) -> None:
        """Observe once; API failures never trigger blind regeneration."""
        reap_children()
        try:
            status = self.client.get("/v1/vpn/status").get("status")
        except APIUnavailable:
            self.status(
                "Cannot access Gluetun control API; check its address, API key and route permissions."
            )
            self.failed_since = None
            return
        if status == "stopped":
            self.status("Gluetun VPN is stopped; automatic recovery is paused.")
            return
        if status in ("starting", "stopping"):
            self.status("Gluetun is changing tunnel state; waiting for the transition to finish.")
            return
        if status not in ("running", "crashed"):
            self.status(
                "Gluetun returned an unknown VPN status; check the supported Gluetun version."
            )
            self.failed_since = None
            return
        if self.resolve_pending() is Pending.UNAVAILABLE:
            self.status(
                "Cannot reconcile pending settings; check Gluetun API connectivity and permissions."
            )
            return
        if self.client.healthy():
            self.status("Gluetun tunnel is healthy.")
            self.failed_since = None
            self.delay = self.config.cooldown
            self.failed_ips.clear()
            return
        now = self.clock()
        if self.failed_since is None:
            self.failed_since = now
        self.status(
            "Gluetun tunnel is unhealthy; waiting for the failure threshold before refreshing."
        )
        if now - self.failed_since < self.config.failure_seconds or now < self.next_attempt:
            return
        try:
            self.recover()
        except (APIUnavailable, GenerationFailed, InvalidSettings, OSError, KeyError, TypeError):
            LOG.info(
                "Recovery preparation failed; retained saved configuration and will retry after cooldown."
            )
        self.next_attempt = self.clock() + self.delay
        self.delay = min(self.delay * 2, 3600)
        self.failed_since = self.clock()

    def run(self) -> None:
        self.store.resume()
        reuse = False
        if self.config.recover:
            try:
                self.store.saved_settings()
                reuse = True
            except (OSError, InvalidSettings):
                pass
        if reuse:
            LOG.info(
                "Reusing validated configuration; Gluetun health will determine whether refresh is needed."
            )
        else:
            with self.generator.generate() as stage:
                self.store.publish(stage)
        self.config.marker.touch()
        LOG.info("Configuration is ready for Gluetun.")
        if self.config.recover:
            LOG.info(
                "Automatic recovery enabled; allowing %ss for startup.", self.config.failure_seconds
            )
            self.wait(self.config.failure_seconds)
            while True:
                self.step()
                self.wait(self.config.interval)
        elif self.config.keepalive:
            while True:
                self.wait(86400)


def main() -> int:
    """Initialize private files and handle shutdown without disclosing configuration values."""
    os.umask(0o077)

    def shutdown(signum, frame):
        # Ignore repeated signals while the active process group is being stopped.
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        raise Shutdown

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    logging.basicConfig(level=logging.INFO, format="[privateerr] %(asctime)s %(message)s")
    try:
        config = Config.from_environment(dict(os.environ))
        for path in (config.config_path, config.metadata_path, config.marker, config.log_path):
            path.parent.mkdir(parents=True, exist_ok=True)
        config.marker.unlink(missing_ok=True)
        handler = logging.FileHandler(config.log_path)
        handler.setFormatter(logging.Formatter("[privateerr] %(asctime)s %(message)s"))
        LOG.addHandler(handler)
        store = Store(config)
        Supervisor(config, store, Client(config), Generator(config, store)).run()
        return 0
    except Shutdown:
        return 0
    except (ConfigurationError, GenerationFailed, InvalidSettings) as error:
        LOG.error("%s", error)
        return 1
    except OSError:
        LOG.error("Cannot complete startup; check file permissions and the generation adapter.")
        return 1
