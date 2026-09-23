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

"""Generate startup configuration, then monitor and repair sustained tunnel failures.

Gluetun owns the VPN connection and port lease. This process invokes PIA setup,
submits replacement connection settings through Gluetun's API, and saves them
only after readback and health checks confirm recovery. It never recreates
Gluetun or the applications sharing its network namespace.
"""

import ipaddress
import logging
import os
import re
import shutil
import signal
import subprocess
import tempfile
import time
from collections.abc import Callable
from collections.abc import Generator as IteratorGenerator
from contextlib import contextmanager
from dataclasses import dataclass
from enum import Enum, auto
from pathlib import Path
from types import FrameType

from .client import APIUnavailable, Client
from .config import Config, ConfigurationError
from .data import is_list, is_object, object_fields
from .settings import InvalidSettings, Store, assignments, contains_settings

LOG = logging.getLogger("privateerr")


class Shutdown(BaseException):
    """Unwind active work on container shutdown without treating it as a recovery failure."""


class GenerationFailed(Exception):
    """Report failed or timed-out upstream generation without exposing its environment."""


class Pending(Enum):
    """Describe whether an earlier update permits another recovery decision."""

    # No candidate remains to confirm; ordinary monitoring may continue.
    RESOLVED = auto()

    # The candidate cannot be checked safely; preserve it and defer new recovery work.
    UNAVAILABLE = auto()

    # Gluetun has the candidate settings, but its tunnel has not recovered yet.
    UNHEALTHY = auto()


@dataclass(frozen=True)
class Endpoint:
    """Pair a validated server address with the PIA name used for port forwarding."""

    ip: str
    name: str


def select_endpoint(
    catalog: dict[str, object],
    region: str,
    current: str,
    failed: set[str],
    *,
    pinned: bool,
    forwarding: bool,
) -> Endpoint:
    """Prefer untried eligible endpoints in the saved region, then the permitted current endpoint."""
    eligible: list[tuple[bool, Endpoint]] = []
    regions = catalog["regions"]

    if not is_list(regions):
        raise GenerationFailed("No valid region catalog is available.")

    # Respect region pinning and forwarding requirements before considering individual servers.
    for raw_item in regions:
        if not is_object(raw_item):
            continue

        item = object_fields(raw_item)

        if forwarding and item.get("port_forward") is not True:
            continue

        if pinned and item.get("id") != region:
            continue

        servers = item.get("servers", {})

        if not is_object(servers):
            continue

        wireguard_servers = object_fields(servers).get("wg")

        if not is_list(wireguard_servers):
            continue

        # Ignore malformed catalog entries instead of passing untrusted text to the shell adapter.
        for raw_server in wireguard_servers:
            try:
                server = object_fields(raw_server)
                address, name = server["ip"], server["cn"]

                if not isinstance(address, str) or not isinstance(name, str):
                    continue

                ip = str(ipaddress.IPv4Address(address))

                if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]*", name):
                    continue
            except (KeyError, ValueError, TypeError):
                continue

            eligible.append((item.get("id") != region, Endpoint(ip, name)))

    # Stable sorting prefers the saved region without running another latency benchmark.
    eligible.sort(key=lambda item: item[0])

    # Try addresses not yet associated with this outage before reusing the current endpoint.
    for _, endpoint in eligible:
        if endpoint.ip not in failed:
            return endpoint

    # Fresh credentials can repair a stale registration even when no alternative server remains.
    for _, endpoint in eligible:
        if endpoint.ip == current:
            return endpoint

    raise GenerationFailed("No permitted endpoint is available.")


def reap_children() -> None:
    """Collect exited descendants adopted when the supervisor runs as container PID 1."""

    # Reap only children that have already exited so monitoring never waits on a live descendant.
    while True:
        try:
            pid, _ = os.waitpid(-1, os.WNOHANG)
        except ChildProcessError:
            return

        if pid == 0:
            return


def stop_group(process: subprocess.Popen[bytes]) -> None:
    """Stop the generator and any surviving descendants before removing staged secrets."""

    # Give the shell adapter and its children a short opportunity to exit cleanly.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass

    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass
    finally:
        # The parent can exit before its children; kill any remaining members of the same group.
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
    def generate(self, endpoint: Endpoint | None = None) -> IteratorGenerator[Path]:
        """Yield a validated temporary pair, then remove staged secrets when the caller finishes."""

        # Generate beside the saved files without overwriting the last usable configuration.
        with tempfile.TemporaryDirectory(
            prefix=".privateerr-stage.", dir=self.config.config_path.parent
        ) as temporary:
            stage = Path(temporary)

            # Redirect adapter output into the private staging directory for this attempt.
            env = self.config.environment.copy()
            env.update(
                PIA_CONF_PATH=str(stage / "wg0.conf"),
                PRIVATEERR_METADATA_PATH=str(stage / "privateerr.env"),
                PRIVATEERR_LOG_PATH=str(self.config.log_path),
                PRIVATEERR_HEALTHCHECK_MARKER=str(self.config.marker),
            )

            # Only this recovery decision may override endpoint selection for the adapter.
            for name in ("PRIVATEERR_CANDIDATE_IP", "PRIVATEERR_CANDIDATE_NAME"):
                env.pop(name, None)

            if endpoint is not None:
                env.update(
                    PRIVATEERR_CANDIDATE_IP=endpoint.ip, PRIVATEERR_CANDIDATE_NAME=endpoint.name
                )

            # A separate process group lets shutdown stop every upstream child, not just Bash.
            process = subprocess.Popen(
                ["bash", str(self.config.bin_home / "privateerr-generate.sh")],
                env=env,
                stdin=subprocess.DEVNULL,
                start_new_session=True,
            )

            # A failed or timed-out attempt leaves the previously published pair untouched.
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

            # Exit status alone is insufficient; callers receive only a valid matching pair.
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
        clock: Callable[[], float] = time.monotonic,
        wait: Callable[[float], None] = time.sleep,
    ):
        self.config = config
        self.store = store
        self.client = client
        self.generator = generator
        self.clock = clock
        self.wait = wait

        # Track outage age separately from retry timing; both use the injected monotonic clock.
        self.failed_since: float | None = None
        self.next_attempt = 0.0
        self.delay = config.cooldown

        # Forget failed endpoints only after a healthy tunnel is observed.
        self.failed_ips: set[str] = set()
        self.last_message = ""

    def status(self, message: str) -> None:
        """Log state changes without repeating the same message on every health probe."""
        if message != self.last_message:
            LOG.info(message)
            self.last_message = message

    def resolve_pending(self) -> Pending:
        """Check an earlier API update before deciding whether to save or replace its candidate."""
        if not self.store.pending.exists():
            return Pending.RESOLVED

        # An incomplete copy was never eligible for submission and can be discarded.
        if not (self.store.pending / "ready").is_file():
            shutil.rmtree(self.store.pending)
            return Pending.RESOLVED

        # Read back settings because a timed-out PUT may still have succeeded inside Gluetun.
        try:
            candidate = self.store.candidate_settings(self.store.pending)
            active = self.client.get("/v1/vpn/settings")

            if not contains_settings(active, candidate):
                self.status(
                    "Gluetun did not retain the pending settings; keeping the last saved configuration."
                )
                shutil.rmtree(self.store.pending)
                return Pending.RESOLVED

            # Matching keys are not enough; keep the candidate pending until the tunnel is healthy.
            if not self.client.healthy():
                return Pending.UNHEALTHY

            # Publish only the pair now verified against the running tunnel.
            self.store.publish(self.store.pending)
            shutil.rmtree(self.store.pending)
        except (APIUnavailable, InvalidSettings, OSError):
            # Preserve uncertain state so the next probe can retry reconciliation safely.
            return Pending.UNAVAILABLE

        self.failed_ips.clear()
        LOG.info(
            "Gluetun tunnel recovered; saved the matching WireGuard configuration and PIA metadata."
        )

        # Port leasing belongs to Gluetun; a missing lease does not invalidate a healthy tunnel.
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
        """Generate and submit one replacement while retaining enough state to verify it later."""

        # Never apply PIA settings to an unrelated provider or VPN protocol.
        active = self.client.get("/v1/vpn/settings")

        provider = object_fields(active.get("provider", {}))

        if active.get("type") != "wireguard" or provider.get("name") != "custom":
            raise GenerationFailed("Recovery requires Gluetun's custom WireGuard provider.")

        # Dedicated IP tokens stay with upstream selection; public endpoints use the catalog.
        endpoint = None
        token = self.config.environment.get("DIP_TOKEN", "no")

        if not token or token.startswith(("n", "N")):
            selection = object_fields(provider["server_selection"])
            current = object_fields(selection["wireguard"])["endpoint_ip"]

            if not isinstance(current, str):
                raise GenerationFailed("Gluetun returned an invalid endpoint address.")

            self.failed_ips.add(current)
            pinned = self.config.environment.get("AUTOCONNECT", "true") == "false"
            region = assignments(self.config.metadata_path).get("PIA_REGION_ID", "unknown")

            # A pinned deployment must stay in its configured region even if saved metadata differs.
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

            # Retain the candidate before PUT so startup can check an interrupted request.
            self.store.retain(stage, self.store.pending)

            try:
                self.client.apply(self.store.candidate_settings(stage))
            except APIUnavailable:
                LOG.info("Settings update was not confirmed; checking Gluetun before retrying.")

    def step(self) -> None:
        """Observe once; API failures never trigger blind regeneration."""

        # Control API access is required before health failures can justify a settings change.
        reap_children()

        try:
            status = self.client.get("/v1/vpn/status").get("status")
        except APIUnavailable:
            self.status(
                "Cannot access Gluetun control API; check its address, API key and route permissions."
            )
            self.failed_since = None
            return

        # Respect intentional stops and let Gluetun finish transitions before intervening.
        if status == "stopped":
            self.status("Gluetun VPN is stopped; automatic recovery is paused.")
            return

        if status in ("starting", "stopping"):
            self.status("Gluetun is changing tunnel state; waiting for the transition to finish.")
            return

        # Unknown states are not proof of a stale PIA registration.
        if status not in ("running", "crashed"):
            self.status(
                "Gluetun returned an unknown VPN status; check the supported Gluetun version."
            )
            self.failed_since = None
            return

        # Defer new work if settings cannot be checked; a known unhealthy tunnel may need a retry.
        if self.resolve_pending() is Pending.UNAVAILABLE:
            self.status(
                "Cannot reconcile pending settings; check Gluetun API connectivity and permissions."
            )
            return

        # Successful health probes reset the outage history and the growing retry delay.
        if self.client.healthy():
            self.status("Gluetun tunnel is healthy.")
            self.failed_since = None
            self.delay = self.config.cooldown
            self.failed_ips.clear()
            return

        # Require a sustained outage and an expired cooldown before requesting another registration.
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
        except (
            APIUnavailable,
            GenerationFailed,
            InvalidSettings,
            OSError,
            KeyError,
            TypeError,
            ValueError,
        ):
            LOG.info(
                "Recovery preparation failed; retained saved configuration and will retry after cooldown."
            )

        # Bound retries after submission or failure; a healthy tunnel resets the retry delay.
        self.next_attempt = self.clock() + self.delay
        self.delay = min(self.delay * 2, 3600)
        self.failed_since = self.clock()

    def run(self) -> None:
        """Prepare startup files, report readiness, and enter recovery or legacy keepalive mode."""

        # Finish any interrupted publication before validating the saved configuration.
        self.store.resume()
        reuse = False

        # Recovery restarts reuse a valid pair; one-shot mode intentionally generates fresh files.
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

        # Readiness means valid files exist, allowing Gluetun to start without a dependency cycle.
        self.config.marker.touch()
        LOG.info("Configuration is ready for Gluetun.")

        # Allow Gluetun time to start before health probes begin.
        if self.config.recover:
            LOG.info(
                "Automatic recovery enabled; allowing %ss for startup.", self.config.failure_seconds
            )
            self.wait(self.config.failure_seconds)

            while True:
                self.step()
                self.wait(self.config.interval)
        elif self.config.keepalive:
            # Legacy keepalive reports readiness without performing recovery work.
            while True:
                self.wait(86400)


def main() -> int:
    """Initialize private files and handle shutdown without disclosing configuration values."""

    # New configuration, staging, and log files must not be readable by other users.
    os.umask(0o077)

    def shutdown(signum: int, frame: FrameType | None) -> None:
        """Unwind through generator cleanup on Docker stop or an interactive interrupt."""

        # Ignore repeated signals while the active process group is being stopped.
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        raise Shutdown

    # Signal-driven unwinding interrupts sleeps and requests while still running cleanup blocks.
    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    logging.basicConfig(level=logging.INFO, format="[privateerr] %(asctime)s %(message)s")

    try:
        config = Config.from_environment(dict(os.environ))

        # Create writable parent directories before any generator or logging operation needs them.
        for path in (config.config_path, config.metadata_path, config.marker, config.log_path):
            path.parent.mkdir(parents=True, exist_ok=True)

        # A previous run's marker must not report healthy until this startup validates its files.
        config.marker.unlink(missing_ok=True)

        # Keep supervisor messages in the persistent log as well as Docker's console output.
        handler = logging.FileHandler(config.log_path)
        handler.setFormatter(logging.Formatter("[privateerr] %(asctime)s %(message)s"))
        LOG.addHandler(handler)

        # Share one store across generation and recovery so a single process owns publication.
        store = Store(config)
        Supervisor(config, store, Client(config), Generator(config, store)).run()
        return 0
    except Shutdown:
        # An intentional container stop is successful, not a failed recovery attempt.
        return 0
    except (ConfigurationError, GenerationFailed, InvalidSettings) as error:
        LOG.error("%s", error)
        return 1
    except OSError:
        # Low-level exceptions may contain private paths or values; report a fixed diagnostic.
        LOG.error("Cannot complete startup; check file permissions and the generation adapter.")
        return 1
