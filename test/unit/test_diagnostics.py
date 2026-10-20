#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test_diagnostics.py: Verify storage diagnostics, safe region labels, and restricted root access.
#

"""Exercise filesystem operations and keep secret-bearing errors out of diagnostics."""

import errno
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from privateerr.diagnostics import (
    FileOperationError,
    check_recovery_directory,
    filesystem_operation,
)
from privateerr.settings import region_description


class DiagnosticsTests(unittest.TestCase):
    """Check real disposable operations and deterministic error categories."""

    def setUp(self):
        """Keep every probe and metadata fixture in disposable test storage."""
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def test_probe_preserves_existing_files_and_permissions(self):
        """A successful probe must not alter the saved pair or directory permissions."""
        saved = self.root / "wg0.conf"
        saved.write_bytes(b"private configuration")
        saved.chmod(0o600)
        before = self.root.stat()
        check_recovery_directory(self.root)
        after = self.root.stat()

        self.assertEqual(saved.read_bytes(), b"private configuration")
        self.assertEqual(saved.stat().st_mode & 0o777, 0o600)
        self.assertEqual(
            (before.st_uid, before.st_gid, before.st_mode),
            (after.st_uid, after.st_gid, after.st_mode),
        )
        self.assertEqual(list(self.root.iterdir()), [saved])

    def test_errors_have_safe_context_and_actionable_categories(self):
        """Report known paths and numeric identity without exposing the original exception."""
        for code, expected in (
            (errno.EACCES, "permission denied"),
            (errno.EROFS, "read-only filesystem"),
            (errno.ENOSPC, "no space left"),
            (errno.EDQUOT, "quota exceeded"),
            (errno.ENOENT, "path missing"),
        ):
            with self.subTest(code=code), self.assertRaises(FileOperationError) as caught:
                with filesystem_operation("create staging directory", self.root):
                    raise OSError(code, "secret-error-value", "secret-filename")

            message = caught.exception.diagnostic()
            self.assertIn(expected, message)
            self.assertIn(str(self.root), message)
            self.assertIn("process UID:GID=", message)
            self.assertIn("path UID:GID=", message)
            self.assertNotIn("secret", message)

    def test_probe_reports_replacement_failure_and_cleans_up(self):
        """Creation alone is insufficient when the filesystem refuses replacement."""
        with patch.object(Path, "replace", side_effect=OSError(errno.EROFS, "secret")):
            with self.assertRaises(FileOperationError) as caught:
                check_recovery_directory(self.root)

        self.assertIn("read-only filesystem", caught.exception.diagnostic())
        self.assertEqual(list(self.root.iterdir()), [])

    def test_region_is_optional_bounded_and_has_no_other_metadata(self):
        """Old files and unsafe labels must not break startup or reveal unrelated fields."""
        path = self.root / "privateerr.env"
        self.assertEqual(region_description(path), "unknown")

        for region, name, expected in (
            ("ca_toronto", '"CA Toronto"', "CA Toronto (ca_toronto)"),
            ("ca", "unknown", "ca"),
            ("unknown", "unknown", "unknown"),
            ("unsafe\x1b[31m", '"unsafe\\nmessage"', "unknown"),
            ("a" * 100, '"' + "x" * 100 + '"', "unknown"),
        ):
            with self.subTest(region=region):
                path.write_text(
                    f"PIA_REGION_ID={region}\nPIA_REGION_NAME={name}\n"
                    "PrivateKey=secret-key\nPIA_WG_ENDPOINT_IP=198.51.100.10\n"
                )
                self.assertEqual(region_description(path), expected)

        path.write_text("PIA_WG_SERVER_NAME=old-example\n")
        self.assertEqual(region_description(path), "unknown")

    @unittest.skipUnless(
        sys.platform == "linux" and os.geteuid() == 0, "requires Linux container root"
    )
    def test_root_without_capabilities_cannot_write_another_users_directory(self):
        """Reproduce the NAS failure with real kernel permissions, retaining root UID."""
        directory = self.root / "wireguard"
        directory.mkdir(mode=0o755)
        os.chown(directory, 65534, 65534)

        # Drop all capability sets only in the disposable child; the parent retains cleanup access.
        child = """
import ctypes
import os
import sys
from pathlib import Path
from privateerr.diagnostics import FileOperationError, check_recovery_directory
header = (ctypes.c_uint32 * 2)(0x20080522, 0)
data = (ctypes.c_uint32 * 6)()
if ctypes.CDLL(None, use_errno=True).capset(header, data) != 0:
    raise OSError(ctypes.get_errno(), "capability drop failed")
assert os.geteuid() == 0
status = Path("/proc/self/status").read_text()
assert "CapEff:\\t0000000000000000" in status
try:
    check_recovery_directory(Path(sys.argv[1]))
except FileOperationError as error:
    print(error.diagnostic())
    sys.exit(0 if error.errno == 13 else 2)
sys.exit(3)
"""
        result = subprocess.run(
            [sys.executable, "-c", child, str(directory)],
            capture_output=True,
            text=True,
            timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("permission denied", result.stdout)
        self.assertIn("(EACCES)", result.stdout)
        self.assertIn("process UID:GID=0:", result.stdout)
        self.assertIn("path UID:GID=65534:65534", result.stdout)
        self.assertEqual(list(directory.iterdir()), [])
