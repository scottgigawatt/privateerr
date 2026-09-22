#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# settings.py: Validate matching PIA files and retain recoverable configuration updates.
#

"""Validate matching PIA files and retain recoverable configuration updates."""

import base64
import ipaddress
import json
import re
import shutil
from pathlib import Path

from .config import Config, ConfigurationError


class InvalidSettings(ValueError):
    """Reject incomplete connection settings without exposing their contents."""


def assignments(path: Path) -> dict[str, str]:
    """Read literal assignments without evaluating shell syntax or accepting duplicates."""
    result = {}
    for line in path.read_text().splitlines():
        match = re.fullmatch(r"([A-Za-z_]+)\s*=\s*(.*?)\s*", line)
        if match is None:
            continue
        name, value = match.groups()
        if name in result:
            raise InvalidSettings("Duplicate configuration field.")
        result[name] = value
    return result


def connection_settings(config: Path, metadata: Path) -> dict:
    """Build only connection fields so Gluetun preserves unrelated settings."""
    try:
        wg = assignments(config)
        meta = assignments(metadata)
        for name in ("PrivateKey", "PublicKey"):
            if len(base64.b64decode(wg[name], validate=True)) != 32:
                raise ValueError
        endpoint, port_text = wg["Endpoint"].split(":")
        ipaddress.IPv4Address(endpoint)
        if not re.fullmatch(r"[0-9]{1,5}", port_text) or not 1 <= int(port_text) <= 65535:
            raise ValueError
        address = wg["Address"]
        if "/" not in address:
            address += "/32"
        ipaddress.IPv4Interface(address)
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]*", meta["PIA_WG_SERVER_NAME"]):
            raise ValueError
        if meta["PIA_WG_ENDPOINT_IP"] != endpoint or meta["PIA_WG_ENDPOINT_PORT"] != port_text:
            raise ValueError
    except (ValueError, KeyError, UnicodeError) as error:
        raise InvalidSettings(
            "Generated WireGuard configuration or metadata is invalid."
        ) from error

    return {
        "wireguard": {"private_key": wg["PrivateKey"], "addresses": [address]},
        "provider": {
            "server_selection": {
                "names": [meta["PIA_WG_SERVER_NAME"]],
                "wireguard": {
                    "endpoint_ip": endpoint,
                    "endpoint_port": int(port_text),
                    "public_key": wg["PublicKey"],
                },
            }
        },
    }


def contains_settings(active: object, candidate: object) -> bool:
    """Compare submitted fields while allowing unrelated fields in Gluetun's response."""
    if isinstance(candidate, dict):
        return isinstance(active, dict) and all(
            key in active and contains_settings(active[key], value)
            for key, value in candidate.items()
        )
    return active == candidate


class Store:
    """Retain complete candidates and finish interrupted two-file publication on startup."""

    def __init__(self, config: Config):
        self.config = config
        self.journal = config.config_path.parent / ".privateerr-commit"
        self.pending = config.config_path.parent / ".privateerr-pending"
        if config.config_path.resolve() == config.metadata_path.resolve():
            raise ConfigurationError("Configuration and metadata must use different file paths.")

    def saved_settings(self) -> dict:
        return connection_settings(self.config.config_path, self.config.metadata_path)

    def candidate_settings(self, directory: Path) -> dict:
        return connection_settings(directory / "wg0.conf", directory / "privateerr.env")

    def retain(self, source: Path, destination: Path) -> None:
        """Mark a candidate ready only after copying and validating both files."""
        shutil.rmtree(destination, ignore_errors=True)
        destination.mkdir(mode=0o700)
        for name in ("wg0.conf", "privateerr.env"):
            shutil.copyfile(source / name, destination / name)
        settings = self.candidate_settings(destination)
        (destination / "settings.json").write_text(json.dumps(settings))
        (destination / "ready").touch()

    def publish(self, source: Path) -> None:
        """Replace each complete file and retain source copies until both replacements finish."""
        self.candidate_settings(source)
        if source != self.journal:
            self.retain(source, self.journal)
        for name, destination in (
            ("wg0.conf", self.config.config_path),
            ("privateerr.env", self.config.metadata_path),
        ):
            replacement = destination.with_name(destination.name + ".new")
            shutil.copyfile(self.journal / name, replacement)
            replacement.replace(destination)
        shutil.rmtree(self.journal)

    def resume(self) -> None:
        """Replay a complete interrupted save; discard an unpublished partial copy."""
        if (self.journal / "ready").is_file():
            self.publish(self.journal)
        else:
            shutil.rmtree(self.journal, ignore_errors=True)
