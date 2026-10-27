#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test_generation_details.py: Exercise bounded PIA output, metadata, and recovery invocation.
#

"""Test Python-owned generation with synthetic upstream scripts and no PIA credentials."""

import base64
import logging
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from privateerr.client import APIUnavailable
from privateerr.config import Config
from privateerr.generation import Endpoint, GenerationFailed, Generator
from privateerr.log import formatter, redact
from privateerr.settings import Store


class GenerationDetailTests(unittest.TestCase):
    """Exercise the real subprocess runner in an isolated upstream directory."""

    def setUp(self):
        """Keep every generated script, candidate, and token in disposable storage."""

        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config = Config.from_environment(
            {
                "PIA_BIN_HOME": str(self.root),
                "PIA_CONF_PATH": str(self.root / "wireguard/wg0.conf"),
                "PRIVATEERR_METADATA_PATH": str(self.root / "wireguard/privateerr.env"),
                "PIA_PF": "true",
            }
        )
        self.config.config_path.parent.mkdir()
        self.generator = Generator(self.config, Store(self.config))

    def script(self, name: str, content: str) -> None:
        """Write a controlled upstream substitute invoked by the production runner."""

        (self.root / name).write_text("#!/bin/sh\nset -eu\n" + content)

    def test_redaction_handles_spaces_controls_and_unknown_tokens(self):
        """Known values must be removed before generic field redaction can split them."""

        environment = {"PIA_PASS": "password with spaces", "PIA_USER": "example-user"}
        result = redact(
            "\x1b[31mPIA_PASS=password with spaces PIA_USER=example-user PIA_TOKEN=unseen-token\x1b[0m",
            environment,
        )
        self.assertNotIn("password", result)
        self.assertNotIn("with spaces", result)
        self.assertNotIn("example-user", result)
        self.assertNotIn("unseen-token", result)
        self.assertNotIn("\x1b", result)

    def test_overlapping_credentials_are_redacted_longest_first(self):
        """A username contained in a password must not expose the remaining password suffix."""

        result = redact(
            "example-user-password",
            {"PIA_USER": "example-user", "PIA_PASS": "example-user-password"},
        )
        self.assertEqual(result, "[redacted]")

    def test_logging_retains_source_and_final_partial_line(self):
        """Skip blank lines without losing output that has no trailing newline."""

        self.script("run_setup.sh", "printf '\\nWG_HOSTNAME=example-one\\nlast message'\n")

        with self.assertLogs("PIA/run_setup.sh", level="INFO") as captured:
            hostname = self.generator.run_script(
                "run_setup.sh", self.config.environment, time.monotonic() + 3
            )

        self.assertEqual(hostname, "example-one")
        self.assertTrue(captured.output[-1].endswith("last message"))
        self.assertEqual(len(captured.output), 3)
        record = logging.LogRecord("PIA/run_setup.sh", logging.INFO, "", 0, "message", (), None)
        self.assertRegex(
            formatter().format(record), r"^\d{4}-\d\d-\d\dT.*Z INFO \[PIA/run_setup.sh\] message$"
        )

    def test_partial_output_cannot_bypass_deadline(self):
        """An upstream process that never completes a line must still time out promptly."""

        self.script("run_setup.sh", "printf partial\nsleep 30\n")
        started = time.monotonic()

        with self.assertRaises(GenerationFailed):
            self.generator.run_script("run_setup.sh", self.config.environment, started + 0.25)

        self.assertLess(time.monotonic() - started, 3)

    def test_oversized_output_is_discarded_and_remains_bounded(self):
        """Do not emit fragments of an oversized line that could contain credentials."""

        self.script(
            "run_setup.sh",
            'python3 -c \'print("private-fragment" * 7000); print("after oversized line")\'\n',
        )

        with self.assertLogs("PIA/run_setup.sh", level="INFO") as captured:
            self.generator.run_script("run_setup.sh", self.config.environment, time.monotonic() + 3)

        self.assertNotIn("private-fragment", "\n".join(captured.output))
        self.assertIn("Omitted an oversized", "\n".join(captured.output))
        self.assertTrue(captured.output[-1].endswith("after oversized line"))

    def test_continuous_output_cannot_bypass_deadline(self):
        """Drain an active pipe while enforcing the same total generation deadline."""

        self.script("run_setup.sh", "while :; do printf 'busy\\n'; done\n")
        started = time.monotonic()

        with patch("privateerr.generation.logging.getLogger"):
            with self.assertRaises(GenerationFailed):
                self.generator.run_script("run_setup.sh", self.config.environment, started + 0.2)

        self.assertLess(time.monotonic() - started, 3)

    def test_metadata_escapes_shell_expansion_and_uses_catalog_fields(self):
        """Catalog labels must remain literal when Gluetun sources generated metadata."""

        stage = self.root / "wireguard"
        (stage / "wg0.conf").write_text("Endpoint = 192.0.2.10:1337\n")
        catalog: dict[str, object] = {
            "regions": [
                {
                    "id": "example-region",
                    "name": 'Example $(command) `command` "region"',
                    "port_forward": True,
                    "geo": False,
                    "servers": {"wg": [{"ip": "192.0.2.10", "cn": "example-one"}]},
                }
            ]
        }

        with patch("privateerr.generation.Client.catalog", return_value=catalog):
            self.generator.write_metadata(stage, "example-one", time.monotonic() + 3)

        metadata = (stage / "privateerr.env").read_text()
        self.assertIn("PIA_REGION_ID=example-region\n", metadata)
        self.assertIn("PIA_PORT_FORWARDING_SUPPORTED=true\n", metadata)
        self.assertIn("PIA_GEOLOCATED_REGION=false\n", metadata)
        self.assertIn(r"\$(command) \`command\` \"region\"", metadata)

        sourced = subprocess.run(
            [
                "sh",
                "-c",
                '. "$1"; printf "%s" "$PIA_REGION_NAME"',
                "sh",
                str(stage / "privateerr.env"),
            ],
            capture_output=True,
            text=True,
            check=True,
            timeout=3,
        )
        self.assertEqual(sourced.stdout, 'Example $(command) `command` "region"')

    def test_targeted_registration_uses_upstream_scripts_and_removes_token(self):
        """Recovery passes its selected endpoint to upstream without a shell adapter."""

        token = self.root / "token"
        self.script("get_token.sh", f"printf 'example-token\\nexpiration\\n' > '{token}'\n")
        key = base64.b64encode(bytes(range(32))).decode()
        self.script(
            "connect_to_wireguard_with_token.sh",
            f"""[ "$PIA_TOKEN" = example-token ]
[ "$WG_SERVER_IP" = 192.0.2.10 ]
[ "$WG_HOSTNAME" = example-one ]
cat > "$PIA_CONF_PATH" <<CONFIG
[Interface]
PrivateKey = {key}
Address = 10.0.0.2
[Peer]
PublicKey = {key}
Endpoint = 192.0.2.10:1337
CONFIG
""",
        )

        with (
            patch("privateerr.generation.TOKEN_PATH", token),
            patch("privateerr.generation.Client.catalog", side_effect=APIUnavailable),
            self.assertLogs(level="INFO") as captured,
        ):
            with self.generator.generate(Endpoint("192.0.2.10", "example-one")) as stage:
                self.assertTrue((stage / "privateerr.env").exists())
                self.assertFalse(token.exists())

        output = "\n".join(captured.output)
        self.assertIn("PIA/get_token.sh", output)
        self.assertIn("PIA/connect_to_wireguard_with_token.sh", output)
        self.assertNotIn("example-token", output)
        self.assertEqual(list((self.root / "wireguard").glob(".privateerr-stage.*")), [])
