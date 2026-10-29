#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# supervisor.py: Generate PIA settings and recover sustained Gluetun outages in one process.
#
# The supervisor:
#   - Invokes unmodified upstream PIA scripts through the Python generator.
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
import time
from collections.abc import Callable
from enum import Enum, auto
from types import FrameType

from .client import APIUnavailable, Client
from .config import Config, ConfigurationError
from .data import is_list, is_object, object_fields
from .diagnostics import FileOperationError, check_recovery_directory, filesystem_operation
from .generation import Endpoint, GenerationFailed, Generator, reap_children
from .log import add_file_log, configure_logging
from .scripts import install_gluetun_scripts
from .settings import InvalidSettings, Store, assignments, contains_settings, region_description

LOG = logging.getLogger("privateerr")


class Shutdown(BaseException):
    """Unwind active work on container shutdown without treating it as a recovery failure."""


class Pending(Enum):
    """Describe whether an earlier update permits another recovery decision."""

    # No candidate remains to confirm; ordinary monitoring may continue.
    RESOLVED = auto()

    # The candidate cannot be checked safely; preserve it and defer new recovery work.
    UNAVAILABLE = auto()

    # Gluetun has the candidate settings, but its tunnel has not recovered yet.
    UNHEALTHY = auto()


def select_endpoint(
    catalog: dict[str, object],
    region: str,
    current: str,
    failed: set[str],
    *,
    pinned: bool,
    forwarding: bool,
) -> Endpoint:
    """Prefer untried eligible endpoints in the saved region, then the permitted current endpoint.

    Args:
        catalog: Validated outer PIA catalog object; individual regions are checked here.
        region: Saved region to prefer, or the configured region when selection is pinned.
        current: Active endpoint used only if no untried eligible server remains.
        failed: Addresses already attempted during this outage.
        pinned: Restrict selection to the requested region.
        forwarding: Require a region that advertises port-forwarding support.

    Returns:
        The selected IPv4 address and its matching PIA server name.

    Raises:
        GenerationFailed: If no permitted endpoint is available.
    """
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

        # Ignore malformed catalog entries instead of passing untrusted endpoint text to upstream scripts.
        for raw_server in wireguard_servers:
            try:
                server = object_fields(raw_server)
                address, name = server["ip"], server["cn"]

                if not isinstance(address, str) or not isinstance(name, str):
                    continue

                ip = str(ipaddress.IPv4Address(address))

                if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]*", name):
                    continue
            except KeyError, ValueError, TypeError:
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

    def failure(self, operation: str, error: Exception) -> None:
        """Log an actionable category without serializing arbitrary exception contents.

        Args:
            operation: Fixed description of the failed recovery phase.
            error: Failure to classify; only recognized diagnostic fields are logged.
        """

        if isinstance(error, FileOperationError):
            detail = error.diagnostic()
        elif isinstance(error, APIUnavailable):
            detail = f"API {error.diagnostic()}; check connectivity and route authorization."
        elif isinstance(error, ConfigurationError):
            # Recovery must never serialize an unexpected exception value containing credentials.
            detail = "Invalid generation inputs; check PIA_USER and PIA_PASS in your private environment file."
        elif isinstance(error, GenerationFailed):
            # Only messages authored here may be surfaced; subprocess output has its own redaction.
            reasons = {
                "PIA generation exceeded its deadline.",
                "PIA setup requested interactive input; check the required environment settings.",
                "PIA generation failed; retained saved configuration.",
                "Recovery requires Gluetun's custom WireGuard provider.",
                "No valid region catalog is available.",
                "No permitted endpoint is available.",
                "Gluetun returned an invalid endpoint address.",
            }
            detail = str(error) if str(error) in reasons else "PIA generation failed."
        elif isinstance(error, InvalidSettings):
            detail = "Configuration validation failed; check the matching configuration pair."
        elif isinstance(error, OSError):
            detail = "Filesystem operation failed; check configured storage access."
        else:
            detail = "Unexpected response or configuration structure; check version compatibility."

        self.status(f"{operation}: {detail}", logging.WARNING)

    def status(self, message: str, level: int = logging.INFO) -> None:
        """Log state changes without repeating the same message on every health probe."""

        if message != self.last_message:
            LOG.log(level, message)
            self.last_message = message

    def resolve_pending(self) -> Pending:
        """Check an earlier API update before deciding whether to save or replace its candidate.

        Returns:
            Whether the pending update is resolved, cannot be checked, or is applied
            but still unhealthy. Only matching settings and health permit publication.
        """
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
        except (APIUnavailable, InvalidSettings, OSError) as error:
            # A disk failure after API submission must not be mistaken for an unapplied update.
            self.failure("Cannot reconcile or persist pending settings", error)
            return Pending.UNAVAILABLE

        self.failed_ips.clear()
        LOG.info(
            "Gluetun tunnel recovered; saved the matching WireGuard configuration and PIA metadata. "
            "VPN region: %s.",
            region_description(self.config.metadata_path),
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
            LOG.info(
                "Generated candidate VPN region: %s; not yet applied.",
                region_description(stage / "privateerr.env"),
            )

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
            except APIUnavailable as error:
                self.failure("Settings update was not confirmed", error)
                LOG.info("Retained the pending candidate; checking Gluetun before retrying.")

    def step(self) -> None:
        """Observe once; API failures never trigger blind regeneration."""

        # Control API access is required before health failures can justify a settings change.
        reap_children()

        try:
            status = self.client.get("/v1/vpn/status").get("status")
        except APIUnavailable as error:
            self.failure("Cannot access Gluetun control API", error)
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
        ) as error:
            self.failure("Recovery preparation failed", error)
            LOG.warning(
                "Saved configuration retained; next recovery attempt in %s seconds.", self.delay
            )

        # Bound retries after submission or failure; a healthy tunnel resets the retry delay.
        self.next_attempt = self.clock() + self.delay
        self.delay = min(self.delay * 2, 3600)
        self.failed_since = self.clock()

    def run(self) -> None:
        """Prepare startup files, report readiness, and enter recovery or idle keepalive mode."""

        # Long-running deployments need integration before readiness, including saved-file reuse.
        if not self.config.one_shot:
            install_gluetun_scripts(
                self.config.bin_home / "gluetun", self.config.config_path.parent.parent / "scripts"
            )
            LOG.info(
                "Installed Gluetun integration scripts: %s",
                self.config.config_path.parent.parent / "scripts",
            )

        # Finish any interrupted publication before validating the saved configuration.
        self.store.resume()
        reuse = False

        # Recovery restarts reuse a valid pair; one-shot mode intentionally generates fresh files.
        if self.config.recover:
            try:
                self.store.saved_settings()
                reuse = True
            except OSError, InvalidSettings:
                pass

        if reuse:
            LOG.info(
                "Reusing validated configuration; VPN region: %s. "
                "Gluetun health will determine whether refresh is needed.",
                region_description(self.config.metadata_path),
            )

        # Existing readable files can start Gluetun even if later recovery cannot write replacements.
        # Keep that compatibility while making degraded recovery visible before the first outage.
        try:
            check_recovery_directory(self.config.config_path.parent)
        except FileOperationError as error:
            if not reuse:
                raise

            self.failure("Configuration directory write check failed", error)
            LOG.warning(
                "Continuing with saved configuration; recovery may fail until storage access is fixed. "
                "No ownership or permissions were changed."
            )
        else:
            LOG.info(
                "Configuration directory check passed: %s (create, write, replace, and remove).",
                self.config.config_path.parent,
            )

        if not reuse:
            with self.generator.generate() as stage:
                self.store.publish(stage)

            LOG.info("Saved WireGuard configuration: %s", self.config.config_path)
            LOG.info("Saved PIA metadata: %s", self.config.metadata_path)
            LOG.info("Saved VPN region: %s", region_description(self.config.metadata_path))

        # Readiness covers valid outputs and any integration required by the selected mode.
        with filesystem_operation("write readiness marker", self.config.marker):
            self.config.marker.touch()

        if not self.config.one_shot:
            LOG.info("Configuration and integration scripts are ready for Gluetun.")

        # Allow Gluetun time to start before health probes begin.
        if self.config.recover:
            LOG.info(
                "Automatic recovery enabled; waiting %s seconds for Gluetun before monitoring.",
                self.config.failure_seconds,
            )
            self.wait(self.config.failure_seconds)

            while True:
                self.step()
                self.wait(self.config.interval)
        elif self.config.keepalive:
            LOG.info("Automatic recovery is disabled; keeping Privateerr running.")
            # Legacy keepalive reports readiness without performing recovery work.
            while True:
                self.wait(86400)
        else:
            LOG.info("Generation complete.")


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
    configure_logging()

    try:
        config = Config.from_environment(dict(os.environ))

        # Create writable parent directories before any generator or logging operation needs them.
        for path in (config.config_path, config.metadata_path, config.marker, config.log_path):
            with filesystem_operation("prepare output directory", path.parent):
                path.parent.mkdir(parents=True, exist_ok=True)

        # A previous run's marker must not report healthy until this startup validates its files.
        with filesystem_operation("clear readiness marker", config.marker):
            config.marker.unlink(missing_ok=True)

        # Keep application and redacted upstream records in the persistent log and console.
        with filesystem_operation("open persistent log", config.log_path):
            add_file_log(config.log_path)

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
    except FileOperationError as error:
        LOG.error("%s", error.diagnostic())
        return 1
    except OSError:
        # Low-level exceptions may contain private paths or values; report a fixed diagnostic.
        LOG.error("Cannot complete startup; check file permissions and the PIA generation scripts.")
        return 1
