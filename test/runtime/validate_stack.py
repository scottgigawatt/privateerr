#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# validate_stack.py: Verify qBittorrent and automatic recovery inside the demo VPN namespace.
#

"""Exercise the running application without a Docker socket or access to host networking."""

import ipaddress
import json
import logging
import os
import signal
import subprocess
import sys
import time
import uuid
from collections.abc import Callable, Generator, Mapping
from contextlib import contextmanager
from pathlib import Path
from types import FrameType
from typing import TypedDict, cast
from urllib.error import URLError
from urllib.request import ProxyHandler, Request, build_opener


class InterfaceState(TypedDict):
    """The local WireGuard identity used to prove that registration changed."""

    private_key: str


class PeerState(TypedDict):
    """The remote IPv4 endpoint targeted by the temporary fault."""

    endpoint_ip: str


class SelectionState(TypedDict):
    """The PIA identity needed to compare saved metadata."""

    names: list[str]
    wireguard: PeerState


class ProviderState(TypedDict):
    """The provider fields inspected by stack validation."""

    server_selection: SelectionState


class VPNState(TypedDict):
    """Only the response fields required by the stack checks."""

    wireguard: InterfaceState
    provider: ProviderState


def fields(value: object) -> Mapping[str, object]:
    """Require an object before reading fields from JSON, whose keys are always strings."""

    if not isinstance(value, dict):
        raise ValueError("Unexpected JSON response shape.")

    return cast(Mapping[str, object], value)


class StackCheck:
    """Read application and VPN state without exposing API keys or WireGuard material."""

    def __init__(self, environment: Mapping[str, str]):
        self.application = environment.get("QBITTORRENT_API_URL", "http://127.0.0.1:8080")
        self.api = environment.get("BUCCANEERR_GLUETUN_URL", "http://127.0.0.1:8000")
        self.health = environment.get("BUCCANEERR_HEALTH_URL", "http://127.0.0.1:9999")
        self.key = environment.get("PRIVATEERR_GLUETUN_API_KEY", "")
        self.interface = environment.get("BUCCANEERR_VPN_INTERFACE", "tun0")

        # Read saved connection files and Gluetun's lease from the shared read-only mounts.
        self.config = Path(environment.get("BUCCANEERR_CONFIG_PATH", "/config"))
        self.lease = Path(environment.get("BUCCANEERR_GLUETUN_PATH", "/gluetun")) / "forwarded_port"
        self.require_forwarding = (
            environment.get("BUCCANEERR_REQUIRE_PORT_FORWARD", "true") == "true"
        )
        self.recovery = environment.get("BUCCANEERR_TEST_RECOVERY", "false") == "true"
        self.application_wait = int(environment.get("BUCCANEERR_APPLICATION_WAIT_SECONDS", "300"))
        self.recovery_wait = int(environment.get("BUCCANEERR_RECOVERY_WAIT_SECONDS", "600"))

        # Keep local API probes independent of inherited HTTP proxy settings.
        self.opener = build_opener(ProxyHandler({}))

    def read(self, url: str, *, authenticate: bool = False) -> bytes:
        """Bound response size and socket waits; keep authentication on control API calls."""

        headers = {"X-API-Key": self.key} if authenticate else {}

        with self.opener.open(Request(url, headers=headers), timeout=5) as response:
            return response.read(1024 * 1024)

    def settings(self) -> VPNState:
        """Validate the connection fields used by recovery assertions before inspecting them."""

        active = fields(json.loads(self.read(self.api + "/v1/vpn/settings", authenticate=True)))
        key = fields(active["wireguard"])["private_key"]
        selection = fields(fields(active["provider"])["server_selection"])
        names = selection["names"]
        endpoint = fields(selection["wireguard"])["endpoint_ip"]

        # Malformed API data must fail validation before a firewall rule is installed.
        if not isinstance(key, str) or not isinstance(endpoint, str) or not isinstance(names, list):
            raise ValueError("Unexpected VPN settings response.")

        server_names = cast(list[object], names)

        if not server_names or not isinstance(server_names[0], str):
            raise ValueError("Missing VPN server name.")

        return {
            "wireguard": {"private_key": key},
            "provider": {
                "server_selection": {
                    "names": [server_names[0]],
                    "wireguard": {"endpoint_ip": endpoint},
                }
            },
        }

    def healthy(self) -> bool:
        """Treat a failed Gluetun health request as an unavailable tunnel."""

        try:
            self.read(self.health)
            return True
        except (OSError, URLError):
            return False

    def application_ready(self) -> bool:
        """Require the real Web API and, when enabled, the exact live VPN port lease."""

        try:
            preferences = fields(
                json.loads(self.read(self.application + "/api/v2/app/preferences"))
            )

            if not self.require_forwarding:
                return "listen_port" in preferences

            # Require the application to use the lease itself with automatic port changes disabled.
            port = int(self.lease.read_text().strip())
            return (
                1 <= port <= 65535
                and preferences.get("listen_port") == port
                and preferences.get("current_network_interface") == self.interface
                and preferences.get("upnp") is False
                and preferences.get("random_port") is False
            )
        except (OSError, URLError, ValueError):
            return False

    def recovered(self, old_key: str) -> bool:
        """Wait for a healthy replacement, synchronized application, and completed publication."""

        try:
            active = self.settings()
            key = active["wireguard"]["private_key"]
            name = active["provider"]["server_selection"]["names"][0]

            # Do not declare recovery while a candidate or interrupted publication remains unresolved.
            pending = any(
                (self.config / entry).exists()
                for entry in (".privateerr-pending", ".privateerr-commit")
            )
            return (
                key != old_key
                and not pending
                and f"PrivateKey = {key}" in (self.config / "wg0.conf").read_text()
                and f"PIA_WG_SERVER_NAME={name}\n" in (self.config / "privateerr.env").read_text()
                and self.healthy()
                and self.application_ready()
            )
        except (OSError, URLError, ValueError, KeyError, IndexError):
            return False


def wait_for(predicate: Callable[[], bool], seconds: float, failure: str) -> None:
    """Poll within a monotonic deadline and report a useful failure without private state."""

    deadline = time.monotonic() + seconds

    while time.monotonic() < deadline:
        if predicate():
            return

        time.sleep(2)

    raise RuntimeError(failure)


@contextmanager
def blocked_endpoint(address: str) -> Generator[None]:
    """Remove only this test's labeled firewall rule, including when validation fails."""

    address = str(ipaddress.IPv4Address(address))

    # Tag this temporary rule so cleanup cannot remove another check's endpoint block.
    rule = [
        "-d",
        address,
        "-m",
        "comment",
        "--comment",
        "buccaneerr-" + uuid.uuid4().hex,
        "-j",
        "DROP",
    ]
    subprocess.run(
        ["iptables", "-I", "OUTPUT", "1", *rule], check=True, capture_output=True, timeout=10
    )

    try:
        yield
    finally:
        # Gluetun may already have rebuilt its firewall while replacing the tunnel.
        subprocess.run(
            ["iptables", "-D", "OUTPUT", *rule], check=False, capture_output=True, timeout=10
        )


def stop(signum: int, frame: FrameType | None) -> None:
    """Unwind the active fault test so normal container shutdown restores its firewall rule."""

    raise SystemExit(128 + signum)


def main() -> None:
    """Validate the complete demo and optionally prove recovery with a controlled outage."""

    # Preserve entrypoint logging while handling shutdown in the process that owns the fault.
    logging.basicConfig(
        level=logging.INFO,
        format="%(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(
                os.environ.get("BUCCANEERR_LOG_PATH", "/buccaneerr-config/logs/buccaneerr.log")
            ),
        ],
    )
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    # Establish application readiness before deliberately interrupting the tunnel.
    check = StackCheck(os.environ)
    wait_for(
        check.application_ready,
        check.application_wait,
        "qBittorrent did not adopt the VPN port and interface.",
    )
    logging.info("PASS: qBittorrent Web API and VPN port settings are ready.")

    if check.recovery:
        if not check.key:
            raise RuntimeError("Set PRIVATEERR_GLUETUN_API_KEY before testing automatic recovery.")

        active = check.settings()
        endpoint = active["provider"]["server_selection"]["wireguard"]["endpoint_ip"]
        old_key = active["wireguard"]["private_key"]
        logging.info("Testing automatic recovery by temporarily blocking the active VPN endpoint.")

        with blocked_endpoint(endpoint):
            # Share one deadline across observing the outage and proving recovery.
            deadline = time.monotonic() + check.recovery_wait
            wait_for(
                lambda: not check.healthy(),
                max(0, deadline - time.monotonic()),
                "The blocked endpoint did not produce an unhealthy tunnel.",
            )
            wait_for(
                lambda: check.recovered(old_key),
                max(0, deadline - time.monotonic()),
                "Automatic recovery did not restore the VPN, saved configuration, and qBittorrent.",
            )

        logging.info(
            "PASS: automatic recovery replaced the registration and restored qBittorrent's VPN port."
        )

    logging.info("All checks passed. The tunnel and application are shipshape.")


if __name__ == "__main__":
    try:
        main()
    except (
        OSError,
        URLError,
        ValueError,
        KeyError,
        RuntimeError,
        subprocess.SubprocessError,
    ) as error:
        # API and command exceptions can contain private response details; never print those.
        message = (
            str(error)
            if isinstance(error, RuntimeError)
            else "Stack validation failed; check service health and configuration."
        )
        raise SystemExit(message) from None
