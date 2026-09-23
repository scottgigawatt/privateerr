#!/usr/bin/env python3

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test-recovery-api.py: Validate settings replacement against an isolated real Gluetun.
#
# Usage: make test-recovery-api, make test-recovery-live, or scripts/compose/test.sh smoke
# Requires a built privateerr:recovery-review image and Docker.
# Pass --env-file .env to additionally test live PIA recovery.
#

import argparse
import base64
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import tempfile
import time
import uuid
from collections.abc import Mapping
from pathlib import Path
from typing import Protocol

from privateerr.data import object_fields
from privateerr.settings import ConnectionSettings

ROOT = Path(__file__).resolve().parents[2]
IMAGE = os.environ.get("PRIVATEERR_TEST_IMAGE", "privateerr:recovery-review")
GLUETUN = os.environ.get(
    "GLUETUN_TEST_IMAGE",
    "qmcgaw/gluetun:v3.41.3@sha256:fa19cc76b2af13d57a8d3dc3066f2ada061b1c761b8aecf989b3877c0486e027",
)
RUN_ID = f"privateerr-recovery-{uuid.uuid4().hex[:12]}"

# Every created resource carries this run identifier so cleanup cannot remove another stack.
LABEL = "io.privateerr.recovery-test"


def docker(
    *args: str, stdin: str | None = None, check: bool = True
) -> subprocess.CompletedProcess[str]:
    """Run Docker without printing output that could contain test credentials."""

    return subprocess.run(
        ["docker", *args],
        input=stdin,
        text=True,
        capture_output=True,
        check=check,
        timeout=120,
    )


def main(env_file: Path | None = None, smoke: bool = False) -> None:
    """Verify API handoff, optionally including live PIA recovery with supplied credentials."""

    # Record resources as they are created so partial setup failures can be cleaned up.
    containers: list[str] = []
    privateerr: str | None = None
    network = None

    with tempfile.TemporaryDirectory(prefix=RUN_ID) as temporary:
        directory = Path(temporary)

        try:
            docker("pull", GLUETUN)
            network = docker(
                "network", "create", "--label", f"{LABEL}={RUN_ID}", RUN_ID
            ).stdout.strip()
            config = directory / "gluetun"
            wireguard = config / "wireguard"
            wireguard.mkdir(parents=True)

            # Use synthetic keys by default; live tests read credentials without printing them.
            if env_file is None:
                private_key = base64.b64encode(secrets.token_bytes(32)).decode()
                public_key = base64.b64encode(secrets.token_bytes(32)).decode()
                (wireguard / "wg0.conf").write_text(
                    f"[Interface]\nPrivateKey = {private_key}\nAddress = 10.0.0.2/32\n"
                    f"[Peer]\nPublicKey = {public_key}\nEndpoint = 192.0.2.1:51820\n"
                )
                (wireguard / "privateerr.env").write_text("PIA_WG_SERVER_NAME=example-one\n")
            else:
                resolved = docker(
                    "compose",
                    "--env-file",
                    str(env_file),
                    "--file",
                    str(ROOT / "docker-compose.yml"),
                    "config",
                    "--environment",
                ).stdout
                values = dict(line.split("=", 1) for line in resolved.splitlines() if "=" in line)

                if values.get("PIA_USER", "") in ("", "p1234567") or values.get("PIA_PASS", "") in (
                    "",
                    "abc123",
                    "shiverMeTimbers123",
                ):
                    raise RuntimeError("Live test requires non-example PIA credentials")

                os.environ["PIA_USER"] = values["PIA_USER"]
                os.environ["PIA_PASS"] = values["PIA_PASS"]
                os.environ["VPN_PORT_FORWARDING_USERNAME"] = values["PIA_USER"]
                os.environ["VPN_PORT_FORWARDING_PASSWORD"] = values["PIA_PASS"]

            # Mount the production forwarding hook and an isolated application configuration.
            scripts = config / "scripts"
            scripts.mkdir()
            shutil.copy(
                ROOT / "config/gluetun/scripts/qbittorrent-port-forwarding.sh",
                scripts / "qbittorrent-port-forwarding.sh",
            )
            application = directory / "qbittorrent"
            (application / "qBittorrent").mkdir(parents=True)
            shutil.copyfile(
                ROOT / "config/qbittorrent/qBittorrent/qBittorrent.conf",
                application / "qBittorrent/qBittorrent.conf",
            )
            qbittorrent_image = os.environ.get(
                "QBITTORRENT_TEST_IMAGE", "lscr.io/linuxserver/qbittorrent:latest"
            )
            docker("pull", qbittorrent_image)

            # Use the checked-out wrapper and a per-run API key for the isolated control server.
            wrapper = directory / "wrapper.sh"
            shutil.copyfile(ROOT / "config/gluetun/scripts/gluetun-entrypoint-wrapper.sh", wrapper)
            os.environ["PRIVATEERR_GLUETUN_API_KEY"] = secrets.token_hex(24)

            # Start real PIA generation only when the caller supplied a credential file.
            if env_file is not None:
                # Smoke mode models an image-only upgrade with the legacy container options.
                isolation = (
                    ["--privileged"]
                    if smoke
                    else [
                        "--cap-drop",
                        "ALL",
                        "--security-opt",
                        "no-new-privileges:true",
                        "--sysctl",
                        "net.ipv6.conf.all.disable_ipv6=1",
                        "--sysctl",
                        "net.ipv6.conf.default.disable_ipv6=1",
                    ]
                )
                recovery_environment = [] if smoke else ["--env", "PRIVATEERR_AUTO_RECOVER=true"]
                privateerr = docker(
                    "create",
                    "--name",
                    f"{RUN_ID}-privateerr",
                    *isolation,
                    *recovery_environment,
                    "--label",
                    f"{LABEL}={RUN_ID}",
                    "--network",
                    RUN_ID,
                    "--volume",
                    f"{config}:/gluetun",
                    "--env",
                    "PIA_USER",
                    "--env",
                    "PIA_PASS",
                    "--env",
                    "PRIVATEERR_GLUETUN_API_KEY",
                    "--env",
                    "PRIVATEERR_KEEPALIVE=true",
                    "--env",
                    "VPN_PROTOCOL=wireguard",
                    "--env",
                    "PIA_CONNECT=false",
                    "--env",
                    "PIA_PF=true",
                    "--env",
                    "PIA_DNS=true",
                    "--env",
                    "DIP_TOKEN=no",
                    "--env",
                    "DISABLE_IPV6=yes",
                    "--env",
                    "AUTOCONNECT=false",
                    "--env",
                    "PRIVATEERR_RECOVERY_INTERVAL_SECONDS=2",
                    "--env",
                    "PRIVATEERR_RECOVERY_FAILURE_SECONDS=15",
                    "--env",
                    "PRIVATEERR_RECOVERY_COOLDOWN_SECONDS=30",
                    IMAGE,
                ).stdout.strip()
                containers.append(privateerr)
                docker("start", privateerr)

                # Configuration readiness must precede the Gluetun container startup.
                for _ in range(100):
                    if (
                        docker("exec", privateerr, "privateerr-healthcheck", check=False).returncode
                        == 0
                    ):
                        break

                    time.sleep(2)
                else:
                    raise RuntimeError("Privateerr did not generate an initial PIA configuration")

                print(
                    "PASS: Privateerr generated a real PIA registration using the default ca region.",
                    flush=True,
                )

            # Keep Gluetun on the test network, with forwarding enabled only for the live test.
            forwarding = "on" if env_file else "off"
            gluetun = docker(
                "create",
                "--name",
                f"{RUN_ID}-gluetun",
                "--label",
                f"{LABEL}={RUN_ID}",
                "--network",
                RUN_ID,
                "--network-alias",
                "gluetun",
                "--cap-add",
                "NET_ADMIN",
                "--device",
                "/dev/net/tun:/dev/net/tun",
                "--env",
                "VPN_SERVICE_PROVIDER=custom",
                "--env",
                "VPN_TYPE=wireguard",
                "--env",
                f"VPN_PORT_FORWARDING={forwarding}",
                "--env",
                "VERSION_INFORMATION=off",
                "--env",
                "QBITTORRENT_API_WAIT_SECONDS=300",
                "--env",
                'VPN_PORT_FORWARDING_UP_COMMAND=/bin/sh -c "/gluetun/scripts/qbittorrent-port-forwarding.sh up {{PORT}} {{VPN_INTERFACE}}"',
                "--env",
                'VPN_PORT_FORWARDING_DOWN_COMMAND=/bin/sh -c "/gluetun/scripts/qbittorrent-port-forwarding.sh down"',
                "--env",
                "VPN_PORT_FORWARDING_PROVIDER=private internet access",
                "--env",
                "VPN_PORT_FORWARDING_USERNAME",
                "--env",
                "VPN_PORT_FORWARDING_PASSWORD",
                "--env",
                f"PRIVATEERR_AUTO_RECOVER={str(not smoke).lower()}",
                "--env",
                "PRIVATEERR_GLUETUN_API_KEY",
                "--volume",
                f"{config}:/gluetun",
                "--volume",
                f"{config}:/tmp/gluetun",
                "--volume",
                f"{wrapper}:/wrapper.sh:ro",
                "--entrypoint",
                "/bin/sh",
                GLUETUN,
                "/wrapper.sh",
            ).stdout.strip()
            containers.append(gluetun)
            docker("start", gluetun)

            # Run a real application in the VPN namespace, with no published host ports.
            qbittorrent = docker(
                "create",
                "--name",
                f"{RUN_ID}-qbittorrent",
                "--label",
                f"{LABEL}={RUN_ID}",
                "--network",
                f"container:{gluetun}",
                "--volume",
                f"{application}:/config",
                "--env",
                "PUID=0",
                "--env",
                "PGID=0",
                qbittorrent_image,
            ).stdout.strip()
            containers.append(qbittorrent)
            docker("start", qbittorrent)
            wait_qbittorrent(qbittorrent)

            # Exercise the original Buccaneerr validator with automatic recovery disabled.
            if smoke:
                for _ in range(120):
                    state = json.loads(docker("inspect", gluetun).stdout)[0]["State"]

                    if state.get("Health", {}).get("Status") == "healthy":
                        break

                    time.sleep(2)
                else:
                    raise RuntimeError(
                        "Gluetun did not become healthy during the compatibility test"
                    )

                validator = docker(
                    "create",
                    "--name",
                    f"{RUN_ID}-validator",
                    "--label",
                    f"{LABEL}={RUN_ID}",
                    "--network",
                    f"container:{gluetun}",
                    "--volume",
                    f"{wireguard}:/config:ro",
                    "--volume",
                    f"{config}:/gluetun:ro",
                    "--env",
                    "BUCCANEERR_LOG_PATH=/tmp/validation.log",
                    os.environ.get("BUCCANEERR_TEST_IMAGE", "privateerr-buccaneerr:test"),
                ).stdout.strip()
                containers.append(validator)
                docker("start", validator)
                result = docker("wait", validator)

                if result.stdout.strip() != "0":
                    print(docker("logs", validator).stdout)
                    raise RuntimeError("Buccaneerr rejected the recovery-disabled stack")

                wait_application_port(qbittorrent, config)
                assert privateerr is not None
                validate_privateerr_isolation(privateerr, legacy=True)
                print(
                    "PASS: recovery-disabled generation, Gluetun startup, and Buccaneerr forwarding validation.",
                    flush=True,
                )
                return

            # Probe the control API from outside the VPN network namespace.
            probe = docker(
                "create",
                "--name",
                f"{RUN_ID}-probe",
                "--label",
                f"{LABEL}={RUN_ID}",
                "--network",
                RUN_ID,
                "--entrypoint",
                "sleep",
                IMAGE,
                "1800",
            ).stdout.strip()
            containers.append(probe)
            docker("start", probe)

            def request(
                method: str,
                route: str,
                body: Mapping[str, object] | None = None,
                authenticate: bool = True,
            ) -> tuple[str, str]:
                """Return status and body without logging private API settings."""

                args = [
                    "exec",
                    "-i",
                    probe,
                    "curl",
                    "--silent",
                    "--connect-timeout",
                    "2",
                    "--max-time",
                    "20",
                    "--write-out",
                    "\n%{http_code}",
                    "--request",
                    method,
                ]

                # Send authentication and optional JSON through stdin, never a key file or argv.
                configuration: list[str] = []

                if authenticate:
                    configuration.append(
                        "header = "
                        + json.dumps("X-API-Key: " + os.environ["PRIVATEERR_GLUETUN_API_KEY"])
                    )

                if body is not None:
                    configuration.append('header = "Content-Type: application/json"')
                    configuration.append("data-binary = " + json.dumps(json.dumps(body)))

                args.extend(["--config", "-", f"http://gluetun:8000{route}"])
                response = docker(*args, stdin="\n".join(configuration) + "\n", check=False)
                content, _, status = response.stdout.rpartition("\n")
                return status, content

            # Application API bypass is restricted to loopback, not the Docker bridge.
            for _ in range(30):
                response = docker(
                    "exec",
                    probe,
                    "curl",
                    "--silent",
                    "--max-time",
                    "5",
                    "--output",
                    "/dev/null",
                    "--write-out",
                    "%{http_code}",
                    "http://gluetun:8080/api/v2/app/preferences",
                    check=False,
                )

                if response.stdout == "403":
                    break

                time.sleep(1)
            else:
                raise RuntimeError("qBittorrent API did not require authentication off loopback")

            # Wait for authenticated API access before testing replacement settings.
            for _ in range(40):
                status, _ = request("GET", "/v1/vpn/status")

                if status == "200":
                    break

                time.sleep(1)
            else:
                raise RuntimeError("Gluetun control API did not become ready")

            assert request("GET", "/v1/vpn/settings", authenticate=False)[0] == "401"

            # Exercise real endpoint failure and recovery when credentials were supplied.
            if env_file is not None:
                assert privateerr is not None
                live_recovery(gluetun, probe, privateerr, qbittorrent, config, request)
                validate_privateerr_isolation(privateerr)
                return

            # Exercise actual application preferences without needing a PIA account in CI.
            hook = "/gluetun/scripts/qbittorrent-port-forwarding.sh"
            docker("exec", gluetun, hook, "up", "45678", "tun0")
            preferences = qbittorrent_preferences(qbittorrent)
            assert preferences["listen_port"] == 45678
            assert preferences["current_network_interface"] == "tun0"
            assert preferences["upnp"] is False
            assert preferences["random_port"] is False
            docker("exec", gluetun, hook, "down")
            assert qbittorrent_preferences(qbittorrent)["current_network_interface"] == "lo"
            print(
                "PASS: real qBittorrent accepts forwarded-port updates and safe down-hook binding."
            )

            # Snapshot container identity and submit a complete synthetic connection update.
            before = json.loads(docker("inspect", gluetun).stdout)[0]
            new_key = base64.b64encode(secrets.token_bytes(32)).decode()
            new_public = base64.b64encode(secrets.token_bytes(32)).decode()
            update: ConnectionSettings = {
                "wireguard": {"private_key": new_key, "addresses": ["10.0.0.3/32"]},
                "provider": {
                    "server_selection": {
                        "names": ["example-two"],
                        "wireguard": {
                            "endpoint_ip": "192.0.2.2",
                            "endpoint_port": 51821,
                            "public_key": new_public,
                        },
                    }
                },
            }
            code, response = request("PUT", "/v1/vpn/settings", update)

            if code != "200":
                response = response.replace(new_key, "[redacted]").replace(new_public, "[redacted]")
                logs = docker("logs", gluetun).stdout + docker("logs", gluetun).stderr

                for line in logs.splitlines():
                    if any(word in line.lower() for word in ("control", "role", "auth", "routes")):
                        print(line.replace(os.environ["PRIVATEERR_GLUETUN_API_KEY"], "[redacted]"))

                print("Authenticated GET settings status:", request("GET", "/v1/vpn/settings")[0])
                raise RuntimeError(f"Settings update returned HTTP {code}: {response[:500]}")

            # Read settings back to verify connection replacement and unrelated field retention.
            code, payload = request("GET", "/v1/vpn/settings")
            assert code == "200"
            active = json.loads(payload)
            assert active["wireguard"]["private_key"] == new_key
            assert active["wireguard"]["addresses"] == ["10.0.0.3/32"]
            assert active["provider"]["server_selection"] == {
                **active["provider"]["server_selection"],
                **update["provider"]["server_selection"],
            }
            assert active["provider"]["name"] == "custom"
            assert active["provider"]["port_forwarding"]["enabled"] is False

            # Settings replacement must preserve the container and the application's network namespace.
            after = json.loads(docker("inspect", gluetun).stdout)[0]
            assert before["State"]["StartedAt"] == after["State"]["StartedAt"]
            assert before["NetworkSettings"]["SandboxID"] == after["NetworkSettings"]["SandboxID"]

            # An invalid candidate must not replace the currently applied key.
            invalid_key = {"private_key": "invalid"}  # pragma: allowlist secret
            assert request("PUT", "/v1/vpn/settings", {"wireguard": invalid_key})[0] == "400"
            assert (
                json.loads(request("GET", "/v1/vpn/settings")[1])["wireguard"]["private_key"]
                == new_key
            )
            print(
                "PASS: real Gluetun authenticated API updates all connection fields without restarting its container."
            )
            print(
                "PASS: unrelated settings preserved; invalid updates rejected; network namespace unchanged."
            )
            print(
                "PIA connectivity and port forwarding are not exercised by this credential-free test."
            )
        finally:
            # Delete only resources recorded by this run and still carrying its ownership label.
            for container in reversed(containers):
                result = docker("inspect", container, check=False)

                if result.returncode == 0:
                    labels = json.loads(result.stdout)[0]["Config"]["Labels"]

                    if labels.get(LABEL) == RUN_ID:
                        docker("rm", "--force", container)

            if network:
                result = docker("network", "inspect", network, check=False)

                if (
                    result.returncode == 0
                    and json.loads(result.stdout)[0]["Labels"].get(LABEL) == RUN_ID
                ):
                    docker("network", "rm", network)


def validate_privateerr_isolation(container: str, *, legacy: bool = False) -> None:
    """Check runtime privileges and clean upstream logs after real generation or recovery."""

    info = json.loads(docker("inspect", container).stdout)[0]
    host = info["HostConfig"]
    status = dict(
        line.split(":", 1)
        for line in docker("exec", container, "cat", "/proc/1/status").stdout.splitlines()
        if ":" in line
    )

    # Exercise image-only upgrades separately from the hardened deployment configuration.
    if legacy:
        assert host["Privileged"] is True
        assert not any(
            value.startswith("PRIVATEERR_AUTO_RECOVER=") for value in info["Config"]["Env"]
        )
    else:
        assert host["Privileged"] is False
        assert host["CapDrop"] == ["ALL"]
        assert int(status["CapEff"].strip(), 16) == 0
        assert status["NoNewPrivs"].strip() == "1"

    # Check effective namespace policy and logs, not merely the requested Compose settings.
    ipv6 = docker(
        "exec",
        container,
        "sysctl",
        "-n",
        "net.ipv6.conf.all.disable_ipv6",
        "net.ipv6.conf.default.disable_ipv6",
    )
    assert ipv6.stdout.split() == ["1", "1"]
    logs = docker("logs", container)
    assert not re.search(
        r"sysctl:|You should consider disabling IPv6|needs to be run as root|Read-only file system|Permission denied",
        logs.stdout + logs.stderr,
        re.IGNORECASE,
    ), "Privateerr emitted an IPv6 or permission diagnostic"
    mode = "legacy image-only upgrade" if legacy else "unprivileged recovery with zero capabilities"
    print(f"PASS: {mode}; no IPv6 or permission warnings.", flush=True)


def qbittorrent_preferences(container: str) -> dict[str, object]:
    """Read application preferences only over loopback within the shared VPN namespace."""

    result = docker(
        "exec",
        container,
        "curl",
        "-fsS",
        "--max-time",
        "5",
        "http://127.0.0.1:8080/api/v2/app/preferences",
        check=False,
    )

    if result.returncode:
        return {}

    try:
        return object_fields(json.loads(result.stdout))
    except ValueError:
        return {}


def wait_qbittorrent(container: str) -> None:
    """Allow application initialization without exposing its temporary Web UI password."""

    for _ in range(90):
        if qbittorrent_preferences(container):
            return

        time.sleep(2)

    raise RuntimeError("qBittorrent Web API did not become ready")


def wait_application_port(container: str, config: Path) -> None:
    """Require the application to adopt the live lease, interface, and mapping restrictions."""

    for _ in range(90):
        preferences = qbittorrent_preferences(container)
        lease = config / "forwarded_port"
        port = lease.read_text().strip() if lease.exists() else ""

        if (
            port.isdigit()
            and int(port) > 0
            and preferences.get("listen_port") == int(port)
            and preferences.get("current_network_interface") == "tun0"
            and preferences.get("upnp") is False
            and preferences.get("random_port") is False
        ):
            return

        time.sleep(2)

    raise RuntimeError("qBittorrent did not adopt Gluetun's forwarded port and VPN interface")


class APIRequest(Protocol):
    """Describe the authenticated request callback used by the live fault test."""

    def __call__(
        self,
        method: str,
        route: str,
        body: Mapping[str, object] | None = None,
        authenticate: bool = True,
    ) -> tuple[str, str]: ...


def live_recovery(
    gluetun: str, probe: str, privateerr: str, qbittorrent: str, config: Path, request: APIRequest
) -> None:
    """Blackhole the active endpoint and verify recovery, forwarding and leak protection."""

    def healthy():
        """Read tunnel health independently of Gluetun process status."""

        result = docker(
            "exec", probe, "curl", "-fsS", "--max-time", "5", "http://gluetun:9999", check=False
        )
        return result.returncode == 0

    def wait_healthy():
        """Allow up to four minutes for a successful tunnel health probe."""

        for _ in range(120):
            if healthy():
                return

            time.sleep(2)

        raise RuntimeError("Gluetun did not regain tunnel health")

    def wait_forwarding():
        """Wait for an assigned port without treating it as a tunnel health signal."""

        for _ in range(90):
            code, body = request("GET", "/v1/portforward")

            if code == "200" and json.loads(body).get("port", 0) > 0:
                return

            time.sleep(2)

        raise RuntimeError("Gluetun did not restore PIA port forwarding")

    # Establish a working baseline before injecting a failure into the active endpoint.
    wait_healthy()
    wait_forwarding()
    before = json.loads(docker("inspect", gluetun).stdout)[0]
    active = json.loads(request("GET", "/v1/vpn/settings")[1])
    old_ip = active["provider"]["server_selection"]["wireguard"]["endpoint_ip"]
    old_key = active["wireguard"]["private_key"]

    # Keep the actual torrent application running across the tunnel replacement.
    dependent = qbittorrent
    wait_application_port(qbittorrent, config)
    dependent_before = json.loads(docker("inspect", dependent).stdout)[0]

    # Record only success/failure; do not print public IPs or configuration.
    internet = docker(
        "exec", dependent, "curl", "-fsS", "--max-time", "20", "https://api.ipify.org"
    )
    direct = docker("exec", probe, "curl", "-fsS", "--max-time", "20", "https://api.ipify.org")

    if internet.stdout.strip() == direct.stdout.strip():
        raise RuntimeError("Dependent traffic is not using a distinct VPN exit")

    print(
        "PASS: initial PIA tunnel, forwarding, and shared-network client connectivity.", flush=True
    )

    # Block only the current endpoint inside the disposable VPN container.
    docker("exec", gluetun, "iptables", "-I", "OUTPUT", "1", "-d", old_ip, "-j", "DROP")

    # Gluetun retries its minute-level check for up to two further minutes.
    for _ in range(180):
        if not healthy():
            break

        time.sleep(2)
    else:
        raise RuntimeError("Fault injection did not make the tunnel unhealthy")

    # Attempt direct traffic through eth0 to verify firewall protection during the outage.
    leak = docker(
        "exec",
        dependent,
        "curl",
        "-kfsS",
        "--interface",
        "eth0",
        "--max-time",
        "5",
        "https://1.1.1.1/cdn-cgi/trace",
        check=False,
    )

    if leak.returncode == 0:
        raise RuntimeError("Traffic escaped through eth0 during the VPN outage")

    print(
        "PASS: blocked endpoint caused an outage; direct non-VPN traffic remained blocked.",
        flush=True,
    )

    # Require both a newly registered key and restored health before declaring recovery.
    for _ in range(150):
        code, body = request("GET", "/v1/vpn/settings")

        if code == "200":
            candidate = json.loads(body)

            if candidate["wireguard"]["private_key"] != old_key and healthy():
                break

        time.sleep(2)
    else:
        # Keep failure diagnostics public and limited to controller status transitions.
        logs = docker("logs", privateerr, check=False)

        for line in (logs.stdout + logs.stderr).splitlines():
            if line.startswith("[privateerr-entrypoint.sh]"):
                print(line)

        raise RuntimeError("Privateerr did not recover the blocked PIA endpoint")

    wait_forwarding()
    wait_application_port(qbittorrent, config)

    # Wait until Privateerr has saved the verified pair and removed the pending candidate.
    for _ in range(30):
        if not (config / "wireguard/.privateerr-pending").exists():
            break

        time.sleep(2)
    else:
        raise RuntimeError("Verified configuration was not persisted")

    # Check saved metadata, pinned region, and container continuity after the handoff.
    saved = (config / "wireguard/wg0.conf").read_text()
    metadata = (config / "wireguard/privateerr.env").read_text()
    assert candidate["wireguard"]["private_key"] in saved
    assert candidate["provider"]["server_selection"]["names"][0] in metadata
    assert candidate["provider"]["server_selection"]["wireguard"]["endpoint_ip"] != old_ip

    # Report only the public region identifier when pinned-region validation fails.
    saved_region = next(
        (
            line.removeprefix("PIA_REGION_ID=")
            for line in metadata.splitlines()
            if line.startswith("PIA_REGION_ID=")
        ),
        "missing",
    )
    assert saved_region == "ca", f"Expected pinned ca region; saved region was {saved_region!r}"
    after = json.loads(docker("inspect", gluetun).stdout)[0]
    assert before["State"]["StartedAt"] == after["State"]["StartedAt"]
    assert before["NetworkSettings"]["SandboxID"] == after["NetworkSettings"]["SandboxID"]
    dependent_after = json.loads(docker("inspect", dependent).stdout)[0]
    assert dependent_before["State"]["StartedAt"] == dependent_after["State"]["StartedAt"]
    docker("exec", dependent, "curl", "-fsS", "--max-time", "20", "https://api.ipify.org")
    public_ip = docker(
        "exec", dependent, "curl", "-fsS", "--max-time", "20", "https://api.ipify.org"
    ).stdout.strip()

    # Verify incoming TCP through the assigned public port, beyond API preference readback.
    port = qbittorrent_preferences(qbittorrent)["listen_port"]
    assert isinstance(port, int)

    # Application sockets may reopen shortly after the preference update returns.
    for _ in range(15):
        try:
            with socket.create_connection((public_ip, port), timeout=5):
                break
        except OSError:
            time.sleep(2)
    else:
        # Report only listener presence, never credentials or full application logs.
        listeners = docker("exec", dependent, "cat", "/proc/net/tcp").stdout
        listening = any(
            line.split()[1].endswith(f":{port:04X}") and line.split()[3] == "0A"
            for line in listeners.splitlines()[1:]
        )
        print(f"Forwarded TCP port has a local listening socket: {listening}", flush=True)
        raise RuntimeError("The assigned PIA port was not reachable from outside the VPN")

    print("PASS: incoming TCP reaches qBittorrent through the PIA forwarded port.", flush=True)
    print(
        "PASS: new PIA endpoint and keys, matching saved metadata, restored forwarding and dependent connectivity.",
        flush=True,
    )
    print(
        "PASS: Gluetun and the dependent container retained their identities and start times.",
        flush=True,
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Test isolated Gluetun recovery and clean up labeled resources."
    )
    parser.add_argument(
        "--env-file",
        type=Path,
        help="Enable live PIA tests using credentials from this Compose environment file",
    )
    parser.add_argument(
        "--smoke", action="store_true", help="Validate a live stack with recovery disabled"
    )
    arguments = parser.parse_args()

    if arguments.smoke and arguments.env_file is None:
        parser.error("--smoke requires --env-file")

    main(arguments.env_file, arguments.smoke)
