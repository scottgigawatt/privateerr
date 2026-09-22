#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test_generation.py: Exercise the real supervisor and shell adapter using isolated upstream fixtures.
#

"""Exercise the real supervisor and shell adapter using isolated upstream fixtures."""

import os
import signal
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class GenerationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.pia = self.root / "pia"
        self.pia.mkdir()
        (self.root / "catalog").write_text('{"regions":[]}\n')
        setup = self.pia / "run_setup.sh"
        setup.write_text("""#!/bin/sh
set -eu
[ "$PREFERRED_REGION" = ca ]
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
        self.command = ["sh", str(ROOT / "docker/privateerr-entrypoint.sh")]

    def run_supervisor(self, **overrides):
        return subprocess.run(
            self.command, env=self.env | overrides, capture_output=True, timeout=12
        )

    def saved(self):
        return tuple(
            Path(self.env[name]).read_bytes()
            for name in ("PIA_CONF_PATH", "PRIVATEERR_METADATA_PATH")
        )

    def test_success_redaction_and_failure_preservation(self):
        self.assertEqual(self.run_supervisor().returncode, 0)
        saved = self.saved()
        self.assertTrue((self.root / "ready").exists())
        self.assertNotIn("test-token-redact", (self.root / "privateerr.log").read_text())
        self.assertNotEqual(self.run_supervisor(TEST_FAIL="true").returncode, 0)
        self.assertEqual(self.saved(), saved)
        self.assertFalse((self.root / "ready").exists())
        self.assertEqual(list((self.root / "wireguard").glob(".privateerr-stage.*")), [])
        self.assertEqual(Path(self.env["PIA_CONF_PATH"]).stat().st_mode & 0o777, 0o600)

    def test_timeout_stops_generation_and_preserves_configuration(self):
        self.assertEqual(self.run_supervisor().returncode, 0)
        saved = self.saved()
        started = time.monotonic()
        result = self.run_supervisor(TEST_HANG="true", PRIVATEERR_GENERATION_TIMEOUT_SECONDS="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertLess(time.monotonic() - started, 8)
        self.assertEqual(self.saved(), saved)
        self.assert_child_stopped()

    def assert_child_stopped(self):
        pid = (self.root / "child.pid").read_text()
        status = Path(f"/proc/{pid}/stat")
        # A terminated orphan can briefly remain as a zombie until the container init reaps it.
        self.assertTrue(not status.exists() or status.read_text().split()[2] == "Z")

    def test_shutdown_interrupts_keepalive_and_active_generation(self):
        for active in (False, True):
            with self.subTest(active_generation=active):
                (self.root / "ready").unlink(missing_ok=True)
                with tempfile.TemporaryFile() as output:
                    process = subprocess.Popen(
                        self.command,
                        env=self.env
                        | {"PRIVATEERR_KEEPALIVE": "true", "TEST_HANG": str(active).lower()},
                        stdout=output,
                        stderr=output,
                    )
                    try:
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
                    finally:
                        if process.poll() is None:
                            process.kill()
                            process.wait()
