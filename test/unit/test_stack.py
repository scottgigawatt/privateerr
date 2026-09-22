#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test_stack.py: Check application readiness, recovery evidence, and fault cleanup.
#

"""Exercise stack validation without modifying a real firewall."""

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

SPEC = importlib.util.spec_from_file_location(
    "validate_stack", Path(__file__).resolve().parents[1] / "runtime/validate_stack.py"
)
STACK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(STACK)


class StackTests(unittest.TestCase):
    """Require application state and saved configuration, not merely a reported port lease."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.check = STACK.StackCheck(
            {"BUCCANEERR_CONFIG_PATH": str(self.root), "BUCCANEERR_GLUETUN_PATH": str(self.root)}
        )
        (self.root / "forwarded_port").write_text("45678")
        self.preferences = {
            "listen_port": 45678,
            "current_network_interface": "tun0",
            "upnp": False,
            "random_port": False,
        }
        self.check.read = Mock(side_effect=lambda _: json.dumps(self.preferences).encode())

    def test_application_requires_exact_port_and_interface(self):
        self.assertTrue(self.check.application_ready())
        for field, value in (
            ("listen_port", 12),
            ("current_network_interface", "lo"),
            ("upnp", True),
            ("random_port", True),
        ):
            with self.subTest(field=field), patch.dict(self.preferences, {field: value}):
                self.assertFalse(self.check.application_ready())

    def test_recovery_requires_published_matching_pair(self):
        self.check.settings = Mock(
            return_value={
                "wireguard": {"private_key": "example-key"},  # pragma: allowlist secret
                "provider": {"server_selection": {"names": ["example-server"]}},
            }
        )
        self.check.healthy = Mock(return_value=True)
        self.assertFalse(self.check.recovered("old-example-key"))
        (self.root / "wg0.conf").write_text("PrivateKey = example-key\n")
        (self.root / "privateerr.env").write_text("PIA_WG_SERVER_NAME=example-server\n")
        self.assertTrue(self.check.recovered("old-example-key"))
        self.assertFalse(self.check.recovered("example-key"))
        (self.root / ".privateerr-pending").mkdir()
        self.assertFalse(self.check.recovered("old-example-key"))

    def test_firewall_fault_is_removed_after_failure(self):
        with patch.object(STACK.subprocess, "run") as run:
            with self.assertRaisesRegex(RuntimeError, "test interruption"):
                with STACK.blocked_endpoint("192.0.2.1"):
                    raise RuntimeError("test interruption")
            inserted, removed = [call.args[0] for call in run.call_args_list]
            self.assertEqual(inserted[:4], ["iptables", "-I", "OUTPUT", "1"])
            self.assertEqual(removed[:3], ["iptables", "-D", "OUTPUT"])
            self.assertEqual(inserted[4:], removed[3:])

    def test_container_stop_removes_the_fault(self):
        with patch.object(STACK.subprocess, "run") as run:
            with self.assertRaises(SystemExit) as stopped:
                with STACK.blocked_endpoint("192.0.2.1"):
                    STACK.stop(15, None)

            self.assertEqual(stopped.exception.code, 143)
            self.assertEqual(run.call_args.args[0][:3], ["iptables", "-D", "OUTPUT"])
