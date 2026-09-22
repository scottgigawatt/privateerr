#!/usr/bin/env python3

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test-recovery-api.py: Validate settings replacement against an isolated real Gluetun.
#
# Usage: python3 test/runtime/test-recovery-api.py
# Requires a built privateerr:recovery-review image and Docker.
# Pass --env-file .env to additionally test live PIA recovery.
#

import argparse
import base64
import json
import os
import secrets
import shutil
import subprocess
import tempfile
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMAGE = os.environ.get("PRIVATEERR_TEST_IMAGE", "privateerr:recovery-review")
GLUETUN = os.environ.get("GLUETUN_TEST_IMAGE", "qmcgaw/gluetun:v3.41.3")
RUN_ID = f"privateerr-recovery-{uuid.uuid4().hex[:12]}"

# Every created resource carries this run identifier so cleanup cannot remove another stack.
LABEL = "io.privateerr.recovery-test"


def docker(*args, stdin=None, check=True):
    """Run Docker without printing output that could contain test credentials."""
    return subprocess.run(
        ["docker", *args],
        input=stdin,
        text=True,
        capture_output=True,
        check=check,
        timeout=120,
    )


def main(env_file=None):
    """Verify API handoff, optionally including live PIA recovery with supplied credentials."""

    # Record resources as they are created so partial setup failures can be cleaned up.
    containers = []
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

            # Use the checked-out wrapper and a per-run API key for the isolated control server.
            wrapper = directory / "wrapper.sh"
            shutil.copyfile(ROOT / "config/gluetun/scripts/gluetun-entrypoint-wrapper.sh", wrapper)
            os.environ["PRIVATEERR_GLUETUN_API_KEY"] = secrets.token_hex(24)
            (directory / "curl-auth").write_text(
                f'header = "X-API-Key: {os.environ["PRIVATEERR_GLUETUN_API_KEY"]}"\n'
            )

            # Start real PIA generation only when the caller supplied a credential file.
            if env_file is not None:
                privateerr = docker(
                    "create",
                    "--name",
                    f"{RUN_ID}-privateerr",
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
                    "PRIVATEERR_AUTO_RECOVER=true",
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
                    "DISABLE_IPV6=no",
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
                "VPN_PORT_FORWARDING_PROVIDER=private internet access",
                "--env",
                "VPN_PORT_FORWARDING_USERNAME",
                "--env",
                "VPN_PORT_FORWARDING_PASSWORD",
                "--env",
                "PRIVATEERR_AUTO_RECOVER=true",
                "--env",
                "PRIVATEERR_GLUETUN_API_KEY",
                "--volume",
                f"{config}:/gluetun",
                "--volume",
                f"{wrapper}:/wrapper.sh:ro",
                "--entrypoint",
                "/bin/sh",
                GLUETUN,
                "/wrapper.sh",
            ).stdout.strip()
            containers.append(gluetun)
            docker("start", gluetun)

            # Probe the control API from outside the VPN network namespace.
            probe = docker(
                "create",
                "--name",
                f"{RUN_ID}-probe",
                "--label",
                f"{LABEL}={RUN_ID}",
                "--network",
                RUN_ID,
                "--volume",
                f"{directory}:/test:ro",
                "--entrypoint",
                "sleep",
                IMAGE,
                "1800",
            ).stdout.strip()
            containers.append(probe)
            docker("start", probe)

            def request(method, route, body=None, authenticate=True):
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
                if authenticate:
                    args.extend(["--config", "/test/curl-auth"])
                if body is not None:
                    args.extend(
                        ["--header", "Content-Type: application/json", "--data-binary", "@-"]
                    )
                args.append(f"http://gluetun:8000{route}")
                response = docker(
                    *args, stdin=json.dumps(body) if body is not None else None, check=False
                )
                content, _, status = response.stdout.rpartition("\n")
                return status, content

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
                live_recovery(gluetun, probe, privateerr, containers, config, request)
                return

            # Snapshot container identity and submit a complete synthetic connection update.
            before = json.loads(docker("inspect", gluetun).stdout)[0]
            new_key = base64.b64encode(secrets.token_bytes(32)).decode()
            new_public = base64.b64encode(secrets.token_bytes(32)).decode()
            update = {
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
            after = json.loads(docker("inspect", gluetun).stdout)[0]
            assert before["State"]["StartedAt"] == after["State"]["StartedAt"]
            assert before["NetworkSettings"]["SandboxID"] == after["NetworkSettings"]["SandboxID"]

            # An invalid candidate must not replace the currently applied key.
            assert (
                request("PUT", "/v1/vpn/settings", {"wireguard": {"private_key": "invalid"}})[0]  # pragma: allowlist secret
                == "400"
            )
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


def live_recovery(gluetun, probe, privateerr, containers, config, request):
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

    # Keep a dependent client in Gluetun's namespace throughout the outage and recovery.
    dependent = docker(
        "create",
        "--name",
        f"{RUN_ID}-dependent",
        "--label",
        f"{LABEL}={RUN_ID}",
        "--network",
        f"container:{gluetun}",
        "--entrypoint",
        "sleep",
        IMAGE,
        "1800",
    ).stdout.strip()
    containers.append(dependent)
    docker("start", dependent)
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
    assert "PIA_REGION_ID=ca\n" in metadata
    after = json.loads(docker("inspect", gluetun).stdout)[0]
    assert before["State"]["StartedAt"] == after["State"]["StartedAt"]
    assert before["NetworkSettings"]["SandboxID"] == after["NetworkSettings"]["SandboxID"]
    dependent_after = json.loads(docker("inspect", dependent).stdout)[0]
    assert dependent_before["State"]["StartedAt"] == dependent_after["State"]["StartedAt"]
    docker("exec", dependent, "curl", "-fsS", "--max-time", "20", "https://api.ipify.org")
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
    main(parser.parse_args().env_file)
