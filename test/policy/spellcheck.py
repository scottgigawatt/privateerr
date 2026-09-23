#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# spellcheck.py: Share VS Code's project vocabulary with the CSpell command-line check.
#

"""Share VS Code's project vocabulary with the CSpell command-line check."""

import json
import re
import subprocess
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory() as temporary:
    # The workspace stores its word list as a JSON array inside a commented settings file.
    settings = Path(".vscode/settings.json").read_text()
    match = re.search(r'"cSpell.words"\s*:\s*(\[[\s\S]*?\])', settings)

    if match is None:
        raise SystemExit("Add cSpell.words to .vscode/settings.json before checking spelling.")

    words = json.loads(match.group(1))
    config = Path(temporary) / "cspell.json"
    config.write_text(json.dumps({"version": "0.2", "words": words}))
    paths = (
        subprocess.check_output(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"]
        )
        .decode()
        .split("\0")
    )
    files = [
        name
        for name in paths
        if Path(name).is_file() and not name.startswith("docker/pia-manual-connections/")
    ]
    raise SystemExit(
        subprocess.run(
            [
                "cspell",
                "lint",
                "--config",
                str(config),
                "--no-progress",
                "--no-must-find-files",
                "--exclude",
                ".secrets.baseline",
                *files,
            ],
            check=False,
        ).returncode
    )
