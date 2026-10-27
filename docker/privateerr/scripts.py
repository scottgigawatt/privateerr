#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# scripts.py: Install image-owned Gluetun integration scripts before startup readiness.
#

"""Copy packaged scripts into the shared configuration without exposing partial files."""

import errno
import tempfile
from pathlib import Path

from .diagnostics import filesystem_operation

SCRIPT_NAMES = ("gluetun-entrypoint-wrapper.sh", "qbittorrent-port-forwarding.sh")


def install_gluetun_scripts(source: Path, destination: Path) -> None:
    """Replace the two managed scripts, preserving all other configuration.

    Args:
        source: Directory containing the scripts packaged in the image.
        destination: Shared scripts directory beside the WireGuard directory.

    Raises:
        FileOperationError: If creation, copying, permissions, or replacement fails.
    """

    with filesystem_operation("install Gluetun scripts", destination):
        # A directory link could redirect managed writes into operator-owned storage.
        if destination.is_symlink():
            raise OSError(errno.ELOOP, "Scripts directory must not be a symbolic link")

        if not destination.exists():
            destination.mkdir(parents=True)
            destination.chmod(0o755)

        # Stage both scripts before replacing either; each replacement is atomic.
        with tempfile.TemporaryDirectory(
            prefix=".privateerr-scripts.", dir=destination
        ) as temporary:
            stage = Path(temporary)

            for name in SCRIPT_NAMES:
                script = stage / name
                script.write_bytes((source / name).read_bytes())
                script.chmod(0o755)

            for name in SCRIPT_NAMES:
                (stage / name).replace(destination / name)
