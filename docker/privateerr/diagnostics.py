#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# diagnostics.py: Report filesystem failures without exposing configuration contents.
#

"""Describe failed operations and probe recovery storage with disposable files."""

import errno
import os
import tempfile
from collections.abc import Generator
from contextlib import contextmanager
from pathlib import Path


class FileOperationError(OSError):
    """Attach a known operation and configured path to a filesystem error.

    Raw exception messages and filenames are intentionally not retained in the
    diagnostic: they can contain configuration data or untrusted subprocess text.
    """

    def __init__(self, operation: str, path: Path, error: OSError):
        super().__init__(error.errno, "Filesystem operation failed")
        self.operation = operation
        self.path = path

    def diagnostic(self) -> str:
        """Return bounded path, identity, mode, and an actionable error category."""
        reasons = {
            errno.EACCES: "permission denied; check host directory ownership and ACL access",
            errno.EPERM: "operation not permitted; check host permissions and filesystem policy",
            errno.EROFS: "read-only filesystem; check the mount's write access",
            errno.ENOSPC: "no space left; check free space and available inodes",
            errno.EDQUOT: "quota exceeded; check the filesystem quota",
            errno.ENOENT: "path missing; check the configured directory mount",
            errno.EISDIR: "expected a file; check the configured output path",
            errno.ENOTDIR: "expected a directory; check the configured mount path",
            errno.EEXIST: "path already exists; check retained recovery state",
            errno.EBUSY: "path busy; mount the configuration directory, not individual files",
        }
        code = errno.errorcode.get(self.errno or 0, "UNKNOWN")
        reason = reasons.get(self.errno or 0, "filesystem operation failed")
        identity = f"process UID:GID={os.geteuid()}:{os.getegid()}"

        # Ownership is a clue, not proof that a particular ACL or mount caused the failure.
        try:
            info = self.path.stat()
            identity += (
                f"; path UID:GID={info.st_uid}:{info.st_gid}; mode={info.st_mode & 0o7777:04o}"
            )
        except OSError:
            identity += "; path ownership unavailable"

        return (
            f"Cannot {self.operation} at {ascii(str(self.path)[:256])}: "
            f"{reason} ({code}); {identity}."
        )


@contextmanager
def filesystem_operation(operation: str, path: Path) -> Generator[None]:
    """Label an operation without replacing a more specific nested diagnostic.

    Args:
        operation: Fixed description of the attempted filesystem operation.
        path: Known configured file or directory involved in the operation.

    Raises:
        FileOperationError: If the operation raises an operating-system error.
    """
    try:
        yield
    except FileOperationError:
        raise
    except OSError as error:
        raise FileOperationError(operation, path, error) from None


def check_recovery_directory(directory: Path) -> None:
    """Exercise creation, writing, replacement, and cleanup using disposable files.

    Args:
        directory: Existing directory containing the saved configuration pair.

    Raises:
        FileOperationError: If any probe operation fails. Existing configuration,
            ownership, modes, and ACLs are never modified.
    """
    with filesystem_operation("check recovery write access", directory):
        with tempfile.TemporaryDirectory(prefix=".privateerr-check.", dir=directory) as temporary:
            probe = Path(temporary)
            source = probe / "source"
            target = probe / "target"

            # Real operations respect ACLs and read-only mounts that mode inspection cannot detect.
            source.write_bytes(b"privateerr filesystem check\n")
            target.write_bytes(b"")
            source.replace(target)
            target.unlink()
