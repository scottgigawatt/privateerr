#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test_region_lookup.py: Check public region lookup output and isolated failure handling.
#

"""Exercise the Make lookup with synthetic catalog responses and no network or credentials."""

import json
import os
import pty
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


class RegionLookupTests(unittest.TestCase):
    """Keep catalog downloads and formatting inside an isolated command environment."""

    def setUp(self) -> None:
        """Replace curl and Docker with controlled commands; retain real jq formatting."""

        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        fixture = self.root / "catalog"
        fixture.write_text(
            json.dumps(
                {
                    "regions": [
                        {"name": "Zulu Place", "id": "zulu_id", "port_forward": False},
                        {"name": "Alpha Location", "id": "alpha_id", "port_forward": True},
                    ]
                }
            )
            + "\npublic-signature\n"
        )
        (self.bin / "curl").write_text(
            "#!/bin/sh\nset -eu\n"
            'while [ "$#" -gt 0 ]; do\n'
            '    case "$1" in --output) destination=$2; shift ;; esac\n'
            "    shift\ndone\n"
            'case "${REGION_TEST_MODE:-valid}" in\n'
            "    transport) exit 22 ;;\n"
            '    malformed) printf "not-json\\n" >"${destination}" ;;\n'
            '    empty) printf \'{"regions":[]}\\n\' >"${destination}" ;;\n'
            '    *) cat "${REGION_TEST_FIXTURE}" >"${destination}" ;;\n'
            "esac\n"
        )
        (self.bin / "docker").write_text(
            '#!/bin/sh\nprintf "Unexpected Docker invocation\\n" >&2\nexit 99\n'
        )
        for command in self.bin.iterdir():
            command.chmod(0o755)
        self.environment = {
            "PATH": str(self.bin) + os.pathsep + os.defpath,
            "TMPDIR": str(self.root),
            "REGION_TEST_FIXTURE": str(fixture),
        }
        self.command = [
            "make",
            "--no-print-directory",
            "list-pia-regions",
            "ENV_FILE=" + str(self.root / "missing.env"),
        ]

    def run_lookup(self, **overrides: str) -> subprocess.CompletedProcess[str]:
        """Run against the synthetic catalog with no inherited operator environment."""

        return subprocess.run(
            self.command,
            env={**self.environment, **overrides},
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )

    def test_all_regions_are_sorted_aligned_and_plain_when_redirected(self) -> None:
        """Retain both forwarding states and align a location containing spaces."""

        result = self.run_lookup()
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = result.stdout.splitlines()
        self.assertEqual(len(lines), 3)
        self.assertIn("PORT FORWARDING", lines[0])
        self.assertIn("Alpha Location", lines[1])
        self.assertIn("Zulu Place", lines[2])
        self.assertEqual(lines[1].index("alpha_id"), lines[2].index("zulu_id"))
        self.assertEqual(lines[1].index("Yes"), lines[2].index("No"))
        self.assertNotIn("\x1b", result.stdout)
        self.assertEqual(list(self.root.glob("privateerr-regions.*")), [])
        self.assertFalse((self.root / "missing.env").exists())

    def test_failed_or_invalid_downloads_propagate_without_partial_tables(self) -> None:
        """Transport, malformed JSON, and empty catalogs cannot report an empty success."""

        for mode in ("transport", "malformed", "empty"):
            with self.subTest(mode=mode):
                result = self.run_lookup(REGION_TEST_MODE=mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertEqual(list(self.root.glob("privateerr-regions.*")), [])

    def test_terminal_colors_and_no_color_opt_out(self) -> None:
        """Color supplements the same Yes/No text and respects an explicit terminal opt-out."""

        for no_color in ("", "1"):
            with self.subTest(no_color=no_color):
                master, slave = pty.openpty()
                try:
                    result = subprocess.run(
                        self.command,
                        env={**self.environment, "NO_COLOR": no_color},
                        stdout=slave,
                        stderr=subprocess.PIPE,
                        check=False,
                        timeout=10,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr.decode())
                    output = os.read(master, 16384).decode()
                finally:
                    os.close(master)
                    os.close(slave)

                self.assertIn("Yes", output)
                self.assertIn("No", output)
                if no_color:
                    self.assertNotIn("\x1b", output)
                else:
                    self.assertIn("\x1b[32mYes\x1b[0m", output)
                    self.assertIn("\x1b[31mNo\x1b[0m", output)
                    self.assertIn("LOCATION", re.sub(r"\x1b\[[0-9;]*m", "", output))
