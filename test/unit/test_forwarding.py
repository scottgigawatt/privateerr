#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test_forwarding.py: Verify forwarding-hook failures without a live application.
#

"""Check rejected inputs, failed updates, and bounded application readiness."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOOK = ROOT / "config/gluetun/scripts/qbittorrent-port-forwarding.sh"


class ForwardingTests(unittest.TestCase):
    """Use a command stub to distinguish a reachable API from a successful update."""

    def run_hook(
        self, *args: str, post_fails: bool = False, unavailable: bool = False, enabled: bool = True
    ) -> subprocess.CompletedProcess[str]:
        """Return the real shell helper's status and logs with a deterministic API stub."""

        with tempfile.TemporaryDirectory() as temporary:
            # Simulate API unavailability separately from a rejected preferences update.
            wget = Path(temporary) / "wget"
            wget.write_text(
                "#!/bin/sh\n"
                'if [ "$UNAVAILABLE" = true ]; then exit 1; fi\n'
                "for arg do\n"
                '    if [ "$arg" = --post-data ] && [ "$POST_FAILS" = true ]; then exit 1; fi\n'
                "done\n"
                "printf '{}\\n'\n"
            )
            wget.chmod(0o755)
            return subprocess.run(
                ["sh", str(HOOK), *args],
                env={
                    **os.environ,
                    "PATH": temporary + ":" + os.environ["PATH"],
                    "POST_FAILS": str(post_fails).lower(),
                    "UNAVAILABLE": str(unavailable).lower(),
                    # Attempt readiness once so failure tests do not spend time retrying.
                    "QBITTORRENT_API_WAIT_SECONDS": "0",
                    "QBITTORRENT_PORT_SYNC": str(enabled).lower(),
                },
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
            )

    def test_failed_update_is_not_logged_as_success(self):
        """Report rejected up and down updates as failures rather than successful changes."""

        for args in (("up", "45678", "tun0"), ("down",)):
            with self.subTest(args=args):
                result = self.run_hook(*args, post_fails=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("Set qBittorrent", result.stdout)
                self.assertNotIn("Reset qBittorrent", result.stdout)

    def test_invalid_input_never_reaches_success(self):
        """Reject invalid ports and unsafe or unsupported interface names."""

        for port, interface in (
            ("0", "tun0"),
            ("65536", "tun0"),
            ("abc", "tun0"),
            ("42", "lo"),
            ("42", 'tun0"'),
        ):
            with self.subTest(port=port, interface=interface):
                self.assertNotEqual(self.run_hook("up", port, interface).returncode, 0)

    def test_readiness_timeout_is_reported(self):
        """Explain when the application API cannot become ready within its deadline."""

        result = self.run_hook("up", "45678", "tun0", unavailable=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("did not become ready", result.stdout)

    def test_successful_update_is_reported(self):
        """Acknowledge an update only after the application accepts it."""

        result = self.run_hook("up", "45678", "tun0")
        self.assertEqual(result.returncode, 0)
        self.assertIn("Set qBittorrent", result.stdout)

    def test_disabled_application_does_not_wait_for_api(self):
        """Exit quietly when port synchronization is disabled."""

        for args in (("up", "45678", "tun0"), ("down",)):
            with self.subTest(args=args):
                # An unavailable API must not turn an explicit opt-out into an error or log message.
                result = self.run_hook(*args, enabled=False, unavailable=True)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
