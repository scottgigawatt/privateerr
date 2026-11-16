#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# log.py: Format application and upstream output consistently without recording credentials.
#

"""Configure UTC logs and sanitize output at the upstream subprocess boundary.

Formatting does not redact arbitrary application messages. The generator calls
`redact` before forwarding upstream text to the root logger's console and file
handlers; application-authored diagnostics must avoid including secrets themselves.
"""

import logging
import os
import re
import sys
import time
from collections.abc import Mapping
from io import TextIOWrapper
from logging.handlers import RotatingFileHandler
from pathlib import Path

# Bound persistent history independently of Docker stdout retention.
_LOG_MAX_BYTES = 10 * 1024 * 1024
_LOG_BACKUP_COUNT = 3

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


def _private_log_opener(path: str, flags: int) -> int:
    """Limit inherited default ACLs when creating a new log without changing existing files."""

    return os.open(path, flags, 0o600)


class _PrivateRotatingFileHandler(RotatingFileHandler):
    """Use owner-only creation permissions for both initial files and rollover replacements."""

    def _open(self) -> TextIOWrapper:
        """Request mode 0600 because inherited Linux ACLs can take precedence over umask."""

        return open(
            self.baseFilename,
            "a",
            encoding=self.encoding,
            errors=self.errors,
            opener=_private_log_opener,
        )


def add_file_log(path: Path) -> None:
    """Attach a size-rotating persistent handler with three retained backups.

    Args:
        path: Log file whose parent directory the caller has already prepared.

    Raises:
        OSError: If the file cannot be opened for appending.

    Note:
        Call once after console setup. This adds a handler without deduplicating
        existing file handlers or changing the root level. Files rotate at 10 MiB;
        complete records and existing oversized files can exceed that threshold.
        New files request owner-only permissions, including on directories with
        inherited default ACLs. Existing ownership and permissions are preserved.
    """

    handler = _PrivateRotatingFileHandler(
        path, maxBytes=_LOG_MAX_BYTES, backupCount=_LOG_BACKUP_COUNT, encoding="utf-8"
    )
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
