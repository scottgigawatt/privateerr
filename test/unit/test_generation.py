#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test_generation.py: Exercise the real supervisor and Python generator using isolated upstream fixtures.
#

"""Exercise the real supervisor and Python generator using isolated upstream fixtures."""

import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class GenerationTests(unittest.TestCase):
    """Exercise process lifecycle and file publication with deterministic upstream output."""

    def setUp(self):
        """Build a disposable PIA fixture and isolate all supervisor output paths."""

        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.pia = self.root / "pia"
        self.pia.mkdir()
        (self.root / "catalog").write_text('{"regions":[]}\n')

        # Replace only upstream PIA setup; run the real entrypoint, supervisor, and Python generator.
        setup = self.pia / "run_setup.sh"
        setup.write_text("""#!/bin/sh
set -eu
[ "$PREFERRED_REGION" = ca ]
if [ -n "${TEST_IPV6_RESULT:-}" ]; then
    printf '%s' "${DISABLE_IPV6-unset}" > "$TEST_IPV6_RESULT"
fi
if [ "${TEST_FAIL:-false}" = true ]; then
    printf broken > "$PIA_CONF_PATH"
    exit 1
fi
if [ "${TEST_HANG:-false}" = true ]; then
    sleep 60 &
    printf '%s' "$!" > "$TEST_CHILD_PID"
    wait
fi
key=$(printf '%032d' 1 | base64 | tr -d '\\n')
cat > "$PIA_CONF_PATH" <<CONFIG
[Interface]
PrivateKey = $key
Address = 10.0.0.2
[Peer]
PublicKey = $key
Endpoint = 198.51.100.10:1337
CONFIG
printf 'WG_HOSTNAME=example-one\\nPIA_TOKEN=test-token-redact\\n'  # pragma: allowlist secret
""")
        setup.chmod(0o700)

        # Keep output and catalog access inside the temporary tree without contacting PIA.
        self.env = {
            **os.environ,
            "PIA_BIN_HOME": str(self.pia),
            "PIA_CONF_PATH": str(self.root / "wireguard/wg0.conf"),
            "PRIVATEERR_METADATA_PATH": str(self.root / "wireguard/privateerr.env"),
            "PRIVATEERR_LOG_PATH": str(self.root / "privateerr.log"),
            "PRIVATEERR_HEALTHCHECK_MARKER": str(self.root / "ready"),
            "PRIVATEERR_KEEPALIVE": "false",
            "PRIVATEERR_AUTO_RECOVER": "false",
            "PRIVATEERR_SERVERLIST_URL": (self.root / "catalog").as_uri(),
            "PRIVATEERR_BIN_HOME": str(ROOT / "docker"),
            "TEST_CHILD_PID": str(self.root / "child.pid"),
        }
        self.env["PYTHONPATH"] = str(ROOT / "docker")
        self.env["PYTHONDONTWRITEBYTECODE"] = "1"
        self.command = [sys.executable, "-m", "privateerr"]

    def run_supervisor(self, **overrides: str) -> subprocess.CompletedProcess[bytes]:
        """Run one bounded supervisor process with optional scenario overrides."""

        return subprocess.run(
            self.command, env=self.env | overrides, capture_output=True, timeout=12
        )

    def saved(self):
        """Snapshot both published files for byte-for-byte preservation checks."""

        return tuple(
            Path(self.env[name]).read_bytes()
            for name in ("PIA_CONF_PATH", "PRIVATEERR_METADATA_PATH")
        )

    def test_success_redaction_and_failure_preservation(self):
        """Keep secrets out of logs and retain the last valid pair after generation fails."""

        self.assertEqual(self.run_supervisor().returncode, 0)
        saved = self.saved()
        self.assertTrue((self.root / "ready").exists())
        self.assertNotIn("test-token-redact", (self.root / "privateerr.log").read_text())

        # A failed replacement must preserve both published files and clear readiness.
        self.assertNotEqual(self.run_supervisor(TEST_FAIL="true").returncode, 0)
        self.assertEqual(self.saved(), saved)
        self.assertFalse((self.root / "ready").exists())
        self.assertEqual(list((self.root / "wireguard").glob(".privateerr-stage.*")), [])
        self.assertEqual(Path(self.env["PIA_CONF_PATH"]).stat().st_mode & 0o777, 0o600)

    def test_log_open_failure_is_visible_in_container_output(self):
        """An unusable persistent log must explain itself even before file logging starts."""

        result = self.run_supervisor(PRIVATEERR_LOG_PATH=str(self.root))
        self.assertNotEqual(result.returncode, 0)
        output = (result.stdout + result.stderr).decode()
        self.assertIn("ERROR [privateerr] Cannot open persistent log", output)
        self.assertIn("expected a file", output)
        self.assertIn("(EISDIR)", output)
        self.assertNotIn("Traceback", output)
        self.assertFalse((self.root / "ready").exists())

    def test_timeout_stops_generation_and_preserves_configuration(self):
        """Cancel a hung generation without replacing the saved configuration."""

        self.assertEqual(self.run_supervisor().returncode, 0)
        saved = self.saved()
        started = time.monotonic()

        # The fixture spawns a child process so timeout handling must stop the whole group.
        result = self.run_supervisor(TEST_HANG="true", PRIVATEERR_GENERATION_TIMEOUT_SECONDS="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertLess(time.monotonic() - started, 8)
        self.assertEqual(self.saved(), saved)
        self.assert_child_stopped()

    def assert_child_stopped(self):
        """Accept a reaped or terminated child, but never one that is still running."""

        pid = (self.root / "child.pid").read_text()
        status = Path(f"/proc/{pid}/stat")

        # A terminated orphan can briefly remain as a zombie until the container init reaps it.
        self.assertTrue(not status.exists() or status.read_text().split()[2] == "Z")

    def test_shutdown_interrupts_keepalive_and_active_generation(self):
        """Honor termination while idle and while supervising an upstream child."""

        for active in (False, True):
            with self.subTest(active_generation=active):
                (self.root / "ready").unlink(missing_ok=True)

                # Capture output in a file so pipe backpressure cannot affect shutdown timing.
                with tempfile.TemporaryFile() as output:
                    process = subprocess.Popen(
                        self.command,
                        env=self.env
                        | {"PRIVATEERR_KEEPALIVE": "true", "TEST_HANG": str(active).lower()},
                        stdout=output,
                        stderr=output,
                    )

                    try:
                        # Wait for the intended state before sending SIGTERM to avoid a startup race.
                        ready = self.root / ("child.pid" if active else "ready")
                        until = time.monotonic() + 8

                        while (
                            not ready.exists()
                            and process.poll() is None
                            and time.monotonic() < until
                        ):
                            time.sleep(0.05)

                        self.assertTrue(ready.exists())
                        process.send_signal(signal.SIGTERM)
                        self.assertEqual(process.wait(timeout=7), 0)

                        if active:
                            self.assert_child_stopped()

                    # Reap the process even if an assertion fails before normal shutdown completes.
                    finally:
                        if process.poll() is None:
                            process.kill()
                            process.wait()

    def test_existing_ipv6_settings_preserve_operator_choices(self):
        """Only Docker-applied settings may suppress an explicit upstream IPv6 request."""

        from privateerr.generation import prepare_ipv6

        root = self.root / "proc"
        for interface in ("all", "default"):
            (root / interface).mkdir(parents=True)

        cases = (
            ("yes", "1", "1", "no"),
            ("yes", "0", "0", "yes"),
            ("yes", "1", "0", "yes"),
            ("yes", "0", "1", "yes"),
            ("no", "1", "1", "no"),
            ("", "1", "1", ""),
        )

        for request, current, default, expected in cases:
            with self.subTest(request=request, current=current, default=default):
                (root / "all/disable_ipv6").write_text(current)
                (root / "default/disable_ipv6").write_text(default)
                environment = {"DISABLE_IPV6": request}
                prepare_ipv6(environment, root)
                self.assertEqual(environment["DISABLE_IPV6"], expected)
