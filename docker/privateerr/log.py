#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# log.py: Format application and upstream output consistently without recording credentials.
#

"""Configure UTC logs and sanitize output at the upstream subprocess boundary.

Formatting does not redact arbitrary application messages. The generator calls
`redact` before forwarding upstream text to the root logger's console and file
handlers; application-authored diagnostics must avoid including secrets themselves.
"""

import logging
import re
import sys
import time
from collections.abc import Mapping
from pathlib import Path

# Recognize ANSI CSI sequences; redact also removes remaining C0 controls except tabs.
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
CREDENTIAL = re.compile(
    r"((?:PIA_USER|PIA_PASS|PIA_TOKEN|DIP_TOKEN|WG_PRIVKEY|PrivateKey)\s*=\s*)[^\s\\]+"
)


def formatter() -> logging.Formatter:
    """Create the UTC timestamp, severity, and logger-name layout used by both handlers.

    Returns:
        Independent formatter using second-resolution ISO-style UTC timestamps.
            Source labels come from each record's logger name.
    """

    result = logging.Formatter(
        "%(asctime)s %(levelname)s [%(name)s] %(message)s", datefmt="%Y-%m-%dT%H:%M:%SZ"
    )
    result.converter = time.gmtime
    return result


def configure_logging() -> None:
    """Configure the root logger for INFO output to stdout during application startup.

    Call once before reading configuration or opening persistent logs, so startup
    failures remain visible. Existing root handlers are preserved by basicConfig;
    this function does not force reconfiguration or perform credential redaction.
    """

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter())
    logging.basicConfig(level=logging.INFO, handlers=[handler])


def add_file_log(path: Path) -> None:
    """Attach a persistent append handler to the root logger.

    Args:
        path: Log file whose parent directory the caller has already prepared.

    Raises:
        OSError: If the file cannot be opened for appending.

    Note:
        Call once after console setup. This adds a handler without deduplicating
        existing file handlers, changing the root level, or rotating old logs.
    """

    handler = logging.FileHandler(path)
    handler.setFormatter(formatter())
    logging.getLogger().addHandler(handler)


def redact(line: str, environment: Mapping[str, str]) -> str:
    """Sanitize one upstream output line before logging it.

    Args:
        line: Decoded text from an upstream script's combined stdout and stderr.
        environment: Invocation environment supplying known PIA_USER, PIA_PASS,
            PIA_TOKEN, and DIP_TOKEN values for literal replacement.

    Returns:
        Stripped text with ANSI CSI sequences and C0 controls except tabs removed,
            known credential values replaced longest first, and recognized credential
            assignments and existing-token messages masked. Blank input returns empty.

    Note:
        Empty values and the placeholders no, none, and false are excluded from
        literal replacement. This is a best-effort filter for upstream conventions,
        not a general secret detector; paths, regions, and unrecognized secret
        formats can remain. It does not mutate the supplied environment.
    """

    result = ANSI.sub("", line)
    result = "".join(character for character in result if character >= " " or character == "\t")

    # Longer overlapping values must be removed before a username can split a password.
    secrets = {
        environment.get(name, "") for name in ("PIA_USER", "PIA_PASS", "PIA_TOKEN", "DIP_TOKEN")
    } - {"", "no", "none", "false"}

    for value in sorted(secrets, key=len, reverse=True):
        result = result.replace(value, "[redacted]")

    result = CREDENTIAL.sub(r"\1[redacted]", result)
    result = re.sub(r"(Using existing token )\S+", r"\1[redacted]", result)
    return result.strip()
