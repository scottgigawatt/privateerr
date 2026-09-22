#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test_compose.py: Verify the complete example and its environment-driven application settings.
#

"""Validate real Compose interpolation without starting deployment containers."""

import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ComposeTests(unittest.TestCase):
    """Check the default service graph and shared application settings."""

    def model(self, *, overrides=""):
        """Resolve example defaults and operator overrides with Buccaneerr's Compose binary."""
        content = (ROOT / "example.env").read_text()

        # Edit settings in place, as operators do, before Compose resolves dependent values.
        for override in overrides.splitlines():
            name, value = override.split("=", 1)
            content = re.sub(rf"^{name}=.*$", f"{name}={value}", content, flags=re.MULTILINE)

        with tempfile.TemporaryDirectory() as temporary:
            environment = Path(temporary) / "example.env"
            environment.write_text(content)
            command = [
                "docker",
                "compose",
                "--file",
                str(ROOT / "docker-compose.yml"),
                "--env-file",
                str(environment),
            ]
            command.extend(["config", "--format", "json"])
            result = subprocess.run(
                command,
                env={"PATH": os.environ["PATH"]},
                capture_output=True,
                text=True,
                check=True,
                timeout=30,
            )
            return json.loads(result.stdout)["services"]

    def test_example_enables_complete_recovery_stack(self):
        services = self.model()
        self.assertEqual(set(services), {"privateerr", "gluetun", "qbittorrent", "buccaneerr"})
        self.assertNotIn("profiles", services["qbittorrent"])
        privateerr = services["privateerr"]
        self.assertFalse(privateerr.get("privileged", False))
        self.assertEqual(privateerr["cap_drop"], ["ALL"])
        self.assertIn("no-new-privileges:true", privateerr["security_opt"])
        self.assertEqual(
            privateerr["sysctls"],
            {
                "net.ipv6.conf.all.disable_ipv6": "1",
                "net.ipv6.conf.default.disable_ipv6": "1",
            },
        )
        self.assertIn("qbittorrent", services["buccaneerr"]["depends_on"])
        self.assertEqual(services["buccaneerr"]["environment"]["BUCCANEERR_TEST_RECOVERY"], "true")
        self.assertEqual(services["privateerr"]["environment"]["PRIVATEERR_AUTO_RECOVER"], "true")
        self.assertEqual(services["gluetun"]["environment"]["PRIVATEERR_AUTO_RECOVER"], "true")
        self.assertEqual(services["gluetun"]["environment"]["QBITTORRENT_PORT_SYNC"], "true")
        self.assertEqual(services["gluetun"]["ports"][0]["published"], "8080")

    def test_environment_owns_defaults_and_operator_overrides(self):
        source = (ROOT / "docker-compose.yml").read_text()
        self.assertIsNone(re.search(r"\$\{[^}]+:-", source))
        services = self.model(
            overrides="PRIVATEERR_AUTO_RECOVER=false\nQBITTORRENT_WEBUI_PORT=8090\n"
        )
        self.assertEqual(services["privateerr"]["environment"]["PRIVATEERR_AUTO_RECOVER"], "false")
        self.assertEqual(services["gluetun"]["ports"][0]["published"], "8090")
        self.assertEqual(services["gluetun"]["ports"][0]["target"], 8090)
        self.assertEqual(services["qbittorrent"]["environment"]["WEBUI_PORT"], "8090")
        self.assertEqual(
            services["gluetun"]["environment"]["QBITTORRENT_API_URL"], "http://127.0.0.1:8090"
        )
        self.assertEqual(
            services["buccaneerr"]["environment"]["QBITTORRENT_API_URL"], "http://127.0.0.1:8090"
        )
        self.assertIn("http://127.0.0.1:8090/", services["qbittorrent"]["healthcheck"]["test"])
        environment = services["gluetun"]["environment"]
        self.assertEqual(
            environment["VPN_PORT_FORWARDING_UP_COMMAND"],
            '/bin/sh -c "/gluetun/scripts/qbittorrent-port-forwarding.sh up {{PORT}} {{VPN_INTERFACE}}"',
        )
        self.assertEqual(
            environment["VPN_PORT_FORWARDING_DOWN_COMMAND"],
            '/bin/sh -c "/gluetun/scripts/qbittorrent-port-forwarding.sh down"',
        )

    def test_selected_application_uses_shared_network_and_persistent_storage(self):
        services = self.model()
        application = services["qbittorrent"]
        self.assertEqual(application["network_mode"], "service:gluetun")
        self.assertNotIn("ports", application)
        self.assertTrue(application["depends_on"]["gluetun"]["restart"])
        self.assertEqual(len(application["volumes"]), 2)
        self.assertEqual(application["depends_on"]["gluetun"]["condition"], "service_healthy")
