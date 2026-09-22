#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test_compose.py: Keep the optional application compatible with older deployment settings.
#

"""Validate real Compose interpolation without starting deployment containers."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ComposeTests(unittest.TestCase):
    """Keep existing service selection and new application defaults independently valid."""

    def model(self, *, application=False, legacy=False):
        """Resolve example settings with the real Compose binary installed in Buccaneerr."""
        content = (ROOT / "example.env").read_text()
        if legacy:
            content = "\n".join(
                line
                for line in content.splitlines()
                if not line.startswith(("QBITTORRENT_", "HOST_TORRENTS_", "COMPOSE_PROFILES="))
            )
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
            if application:
                command.extend(["--profile", "downloads"])
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

    def test_older_environment_does_not_start_application(self):
        services = self.model(legacy=True)
        self.assertNotIn("qbittorrent", services)
        self.assertEqual(services["gluetun"]["environment"]["QBITTORRENT_PORT_SYNC"], "false")
        self.assertEqual(services["gluetun"]["ports"][0]["host_ip"], "127.0.0.1")
        self.assertEqual(services["gluetun"]["ports"][0]["published"], "0")

    def test_selected_application_uses_shared_network_and_persistent_storage(self):
        for legacy in (False, True):
            with self.subTest(legacy=legacy):
                services = self.model(application=True, legacy=legacy)
                application = services["qbittorrent"]
                self.assertEqual(application["network_mode"], "service:gluetun")
                self.assertNotIn("ports", application)
                self.assertEqual(len(application["volumes"]), 2)
                self.assertEqual(
                    application["depends_on"]["gluetun"]["condition"], "service_healthy"
                )
