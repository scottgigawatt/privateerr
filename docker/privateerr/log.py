#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# log.py: Format application and upstream output consistently without recording credentials.
#

"""Use one UTC format for Privateerr and explicitly identified PIA invocations."""

import logging
import re
import sys
import time
from collections.abc import Mapping
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
CREDENTIAL = re.compile(
    r"((?:PIA_USER|PIA_PASS|PIA_TOKEN|DIP_TOKEN|WG_PRIVKEY|PrivateKey)\s*=\s*)[^\s\\]+"
)


def formatter() -> logging.Formatter:
    """Give console and persistent records the same timestamp, severity, and source."""

    result = logging.Formatter(
        "%(asctime)s %(levelname)s [%(name)s] %(message)s", datefmt="%Y-%m-%dT%H:%M:%SZ"
    )
    result.converter = time.gmtime
    return result


def configure_logging() -> None:
    """Initialize console output before configuration or file access can fail."""

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter())
    logging.basicConfig(level=logging.INFO, handlers=[handler])


def add_file_log(path: Path) -> None:
    """Append application and upstream records through the same logging handlers."""

    handler = logging.FileHandler(path)
    handler.setFormatter(formatter())
    logging.getLogger().addHandler(handler)


def redact(line: str, environment: Mapping[str, str]) -> str:
    """Remove terminal controls and credentials before output reaches any handler."""

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
