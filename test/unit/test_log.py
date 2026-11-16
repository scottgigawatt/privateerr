#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# test_log.py: Verify bounded persistent history without losing console output or privacy.
#

"""Exercise real file rotation with isolated handlers and synthetic upstream credentials."""

import errno
import io
import logging
import os
import stat
import struct
import sys
import tempfile
import unittest
from logging.handlers import RotatingFileHandler
from pathlib import Path
from unittest.mock import patch

from privateerr.log import add_file_log, redact


class FileLogTests(unittest.TestCase):
    """Keep file-handler state and process-wide logging configuration local to each test."""

    def setUp(self) -> None:
        """Replace root handlers temporarily so tests cannot write to operator logs."""

        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.path = Path(temporary.name) / "privateerr.log"
        self.root = logging.getLogger()
        handlers, level = self.root.handlers[:], self.root.level
        self.root.handlers = []
        self.root.setLevel(logging.INFO)

        def restore() -> None:
            """Close only test handlers before restoring the runner's logging state."""

            for handler in self.root.handlers:
                handler.close()

            self.root.handlers = handlers
            self.root.setLevel(level)

        self.addCleanup(restore)
        self.console = io.StringIO()
        self.root.addHandler(logging.StreamHandler(self.console))

    def handler(self, size: int = 220) -> RotatingFileHandler:
        """Use small thresholds to exercise production rotation without large fixtures."""

        with patch("privateerr.log._LOG_MAX_BYTES", size):
            add_file_log(self.path)

        handler = self.root.handlers[-1]
        self.assertIsInstance(handler, RotatingFileHandler)
        assert isinstance(handler, RotatingFileHandler)
        return handler

    def test_rotation_discards_oldest_history_and_keeps_logging(self) -> None:
        """Bound retained backups while preserving the newest record and console stream."""

        self.handler()

        for number in range(20):
            self.root.info("record-%02d %s", number, "x" * 80)

        self.assertEqual(
            {path.name for path in self.path.parent.iterdir()},
            {"privateerr.log", "privateerr.log.1", "privateerr.log.2", "privateerr.log.3"},
        )
        retained = "".join(path.read_text() for path in self.path.parent.iterdir())
        self.assertNotIn("record-00", retained)
        self.assertIn("record-19", self.path.read_text())
        self.assertIn("record-00", self.console.getvalue())
        self.assertIn("record-19", self.console.getvalue())

        for path in self.path.parent.iterdir():
            self.assertLessEqual(path.stat().st_size, 220)

    def test_restart_appends_and_continues_rotation(self) -> None:
        """Reopening an existing log must preserve history and still enforce retention."""

        handler = self.handler()
        self.root.info("before restart")
        handler.close()
        self.root.removeHandler(handler)
        self.handler()
        self.root.info("after restart")
        self.assertIn("before restart", self.path.read_text())
        self.assertIn("after restart", self.path.read_text())

        for number in range(10):
            self.root.info("reopened-%02d %s", number, "x" * 80)

        self.assertIn("reopened-09", self.path.read_text())
        self.assertEqual(len(list(self.path.parent.iterdir())), 4)

    def test_new_active_and_backup_files_remain_private(self) -> None:
        """Rotation must preserve the startup umask for every newly created log file."""

        previous = os.umask(0o077)

        try:
            self.handler()

            for number in range(8):
                self.root.info("private-%02d %s", number, "x" * 80)
        finally:
            os.umask(previous)

        self.assertEqual(len(list(self.path.parent.iterdir())), 4)

        for path in self.path.parent.iterdir():
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)

    @unittest.skipUnless(sys.platform == "linux", "Default ACL fixtures require Linux.")
    def test_default_acl_cannot_broaden_private_logs_after_rotation(self) -> None:
        """An inherited readable ACL must not broaden a protected file during rollover."""

        # Linux's POSIX ACL extended attribute stores a version and user/group/other entries.
        default_acl = struct.pack("<I", 2) + b"".join(
            struct.pack("<HHI", tag, permissions, 0xFFFFFFFF)
            for tag, permissions in ((0x01, 0o7), (0x04, 0o5), (0x20, 0o5))
        )

        try:
            os.setxattr(self.path.parent, "system.posix_acl_default", default_acl)
        except OSError as error:
            if error.errno in (errno.ENOTSUP, errno.EOPNOTSUPP):
                self.skipTest("The fixture filesystem does not support POSIX default ACLs.")

            raise

        previous = os.umask(0o077)

        try:
            # Prove this filesystem inherits read access despite the restrictive umask.
            control = self.path.parent / "ordinary.log"
            control.write_text("ordinary creation")
            self.assertEqual(stat.S_IMODE(control.stat().st_mode), 0o644)
            control.unlink()
            self.path.write_text("existing private history")
            self.path.chmod(0o600)
            self.handler()

            for number in range(10):
                self.root.info("acl-private-%02d %s", number, "x" * 80)
        finally:
            os.umask(previous)

        self.assertEqual(len(list(self.path.parent.iterdir())), 4)

        for path in self.path.parent.iterdir():
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)

    def test_existing_permissions_are_preserved_and_new_files_are_private(self) -> None:
        """Keep operator metadata on existing files while restricting each new active file."""

        self.path.write_text("operator-managed history")
        self.path.chmod(0o640)
        previous = os.umask(0)

        try:
            self.handler()
            self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o640)
            self.root.info("force rollover %s", "x" * 220)
        finally:
            os.umask(previous)

        self.assertEqual(stat.S_IMODE(self.path.with_suffix(".log.1").stat().st_mode), 0o640)
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o600)

    def test_redacted_records_stay_redacted_across_rotation(self) -> None:
        """Handler rotation must not bypass sanitization at the upstream boundary."""

        self.handler()
        environment = {"PIA_USER": "example-user", "PIA_PASS": "example-password"}

        for number in range(12):
            self.root.info(
                "%02d %s",
                number,
                redact("PIA_PASS=example-password PIA_USER=example-user", environment),
            )

        self.assertTrue(self.path.with_suffix(".log.1").exists())
        retained = self.console.getvalue() + "".join(
            path.read_text() for path in self.path.parent.iterdir()
        )
        self.assertNotIn("example-password", retained)
        self.assertNotIn("example-user", retained)
        self.assertIn("[redacted]", retained)

    def test_legacy_oversized_file_ages_out_without_truncation(self) -> None:
        """Keep a pre-existing large log as history until later rotations retire it."""

        self.path.write_text("legacy history\n" * 100)
        self.handler()
        self.root.info("first new record")
        self.assertIn("legacy history", self.path.with_suffix(".log.1").read_text())

        for number in range(12):
            self.root.info("new-%02d %s", number, "x" * 80)

        retained = "".join(path.read_text() for path in self.path.parent.iterdir())
        self.assertNotIn("legacy history", retained)
        self.assertIn("new-11", retained)

    def test_rollover_failure_does_not_stop_console_or_later_file_output(self) -> None:
        """An unavailable backup path must not terminate monitoring or its console logs."""

        handler = self.handler()
        self.root.info("initial record")

        with (
            patch.object(handler, "doRollover", side_effect=OSError("injected rotation failure")),
            patch("sys.stderr", new_callable=io.StringIO),
        ):
            self.root.info("during failure %s", "x" * 220)

        self.assertIn("during failure", self.console.getvalue())
        self.root.info("after failure %s", "x" * 100)
        self.assertIn("after failure", self.path.read_text())
