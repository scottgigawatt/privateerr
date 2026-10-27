#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test_scripts.py: Verify automatic installation without changing operator configuration.
#

"""Exercise script replacement, permissions, and failed publication in disposable directories."""

import errno
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from privateerr.diagnostics import FileOperationError
from privateerr.scripts import SCRIPT_NAMES, install_gluetun_scripts

SOURCE = Path(__file__).resolve().parents[2] / "docker/gluetun"


class ScriptTests(unittest.TestCase):
    """Use the packaged sources and an isolated shared configuration tree."""

    def setUp(self):
        """Keep generated scripts and unrelated sentinel files outside the checkout."""

        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.destination = self.root / "scripts"

    def test_install_and_refresh_preserve_other_files(self):
        """Fresh and repeated installation must manage only the two executable scripts."""

        private = self.root / "wg0.conf"
        private.write_bytes(b"private connection material")
        private.chmod(0o600)

        install_gluetun_scripts(SOURCE, self.destination)
        custom = self.destination / "custom.sh"
        custom.write_text("operator script\n")

        # Simulate stale or edited generated scripts, including lost execute permission.
        for name in SCRIPT_NAMES:
            (self.destination / name).write_text("outdated\n")
            (self.destination / name).chmod(0o600)

        install_gluetun_scripts(SOURCE, self.destination)

        for name in SCRIPT_NAMES:
            self.assertEqual((self.destination / name).read_bytes(), (SOURCE / name).read_bytes())
            self.assertEqual((self.destination / name).stat().st_mode & 0o777, 0o755)

        self.assertEqual(custom.read_text(), "operator script\n")
        self.assertEqual(private.read_bytes(), b"private connection material")
        self.assertEqual(private.stat().st_mode & 0o777, 0o600)
        self.assertEqual(
            {path.name for path in self.destination.iterdir()}, {*SCRIPT_NAMES, "custom.sh"}
        )

    def test_missing_source_preserves_installed_scripts(self):
        """A failed staging copy must leave the previous scripts available and remove staging."""

        install_gluetun_scripts(SOURCE, self.destination)
        incomplete = self.root / "incomplete"
        incomplete.mkdir()
        (incomplete / SCRIPT_NAMES[0]).write_text("replacement\n")

        with self.assertRaises(FileOperationError):
            install_gluetun_scripts(incomplete, self.destination)

        for name in SCRIPT_NAMES:
            self.assertEqual((self.destination / name).read_bytes(), (SOURCE / name).read_bytes())

        self.assertEqual({path.name for path in self.destination.iterdir()}, set(SCRIPT_NAMES))

    def test_failed_replace_preserves_complete_file(self):
        """Atomic replacement failure must not truncate an installed script or leak staging."""

        install_gluetun_scripts(SOURCE, self.destination)

        with (
            patch.object(Path, "replace", side_effect=OSError(errno.EROFS, "private detail")),
            self.assertRaises(FileOperationError) as caught,
        ):
            install_gluetun_scripts(SOURCE, self.destination)

        self.assertIn("install Gluetun scripts", caught.exception.diagnostic())
        self.assertIn("read-only filesystem", caught.exception.diagnostic())
        self.assertNotIn("private detail", caught.exception.diagnostic())

        for name in SCRIPT_NAMES:
            self.assertEqual((self.destination / name).read_bytes(), (SOURCE / name).read_bytes())

        self.assertEqual({path.name for path in self.destination.iterdir()}, set(SCRIPT_NAMES))

    def test_directory_symlink_is_rejected(self):
        """Do not follow a scripts-directory link into another configuration directory."""

        external = self.root / "external"
        external.mkdir()
        self.destination.symlink_to(external, target_is_directory=True)

        with self.assertRaises(FileOperationError):
            install_gluetun_scripts(SOURCE, self.destination)

        self.assertEqual(list(external.iterdir()), [])
