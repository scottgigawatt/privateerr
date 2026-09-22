#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# check-executable-modes.py: Validate shebangs against portable Unix executable mode bits.
#

"""Validate shebangs against portable Unix executable mode bits."""

import stat
import sys
from pathlib import Path


def check(path: Path) -> bool:
    """Avoid access(X_OK), which can misreport executable files on Docker Desktop mounts."""
    executable = bool(path.stat().st_mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH))
    with path.open("rb") as source:
        shebang = source.read(2) == b"#!"
    if executable != shebang:
        print(
            f"{path}: {'add a shebang or remove execute bits' if executable else 'make this shebang script executable'}"
        )
        return False
    return True


if __name__ == "__main__":
    results = [check(Path(name)) for name in sys.argv[1:]]
    raise SystemExit(0 if all(results) else 1)
