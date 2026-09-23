#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# settings.py: Validate matching PIA files and retain recoverable configuration updates.
#

"""Translate PIA output into Gluetun settings and keep matching files recoverable.

Generated files are parsed as data, validated together, and submitted as a small
settings update. Publication replaces one complete file at a time while retaining
both source files so startup can finish a save interrupted between replacements.
"""

import base64
import ipaddress
import json
import re
import shutil
from pathlib import Path
from typing import TypedDict

from .config import Config, ConfigurationError
from .data import is_object, object_fields


class WireGuardSettings(TypedDict):
    """Fields Gluetun needs for the local WireGuard interface."""

    private_key: str
    addresses: list[str]


class EndpointSettings(TypedDict):
    """Validated remote endpoint fields submitted to Gluetun."""

    endpoint_ip: str
    endpoint_port: int
    public_key: str


class ServerSelection(TypedDict):
    """PIA server identity and its WireGuard endpoint."""

    names: list[str]
    wireguard: EndpointSettings


class ProviderSettings(TypedDict):
    """Only provider fields owned by Privateerr's connection update."""

    server_selection: ServerSelection


class ConnectionSettings(TypedDict):
    """The minimal settings update, without unrelated Gluetun options."""

    wireguard: WireGuardSettings
    provider: ProviderSettings


class InvalidSettings(ValueError):
    """Reject incomplete connection settings without exposing their contents."""


def assignments(path: Path) -> dict[str, str]:
    """Read literal assignments without evaluating shell syntax or accepting duplicates."""
    result: dict[str, str] = {}

    # Ignore headers and comments; never source generated metadata as executable shell code.
    for line in path.read_text().splitlines():
        match = re.fullmatch(r"([A-Za-z_]+)\s*=\s*(.*?)\s*", line)

        if match is None:
            continue

        name, value = match.groups()

        # Duplicate keys make the connection ambiguous even when a later value looks valid.
        if name in result:
            raise InvalidSettings("Duplicate configuration field.")

        result[name] = value

    return result


def connection_settings(config: Path, metadata: Path) -> ConnectionSettings:
    """Build only connection fields so Gluetun preserves unrelated settings.

    Args:
        config: Generated WireGuard configuration to validate.
        metadata: PIA metadata naming the same endpoint and port.

    Returns:
        The minimal connection update accepted by Gluetun's control API.

    Raises:
        InvalidSettings: If required fields are missing, malformed, or inconsistent.
        OSError: If either source file cannot be read.
    """
    try:
        wg = assignments(config)
        meta = assignments(metadata)

        # WireGuard keys must decode to exactly 32 bytes before they reach the control API.
        for name in ("PrivateKey", "PublicKey"):
            if len(base64.b64decode(wg[name], validate=True)) != 32:
                raise ValueError

        # Recovery accepts a concrete IPv4 endpoint and a valid UDP port from PIA output.
        endpoint, port_text = wg["Endpoint"].split(":")
        ipaddress.IPv4Address(endpoint)

        if not re.fullmatch(r"[0-9]{1,5}", port_text) or not 1 <= int(port_text) <= 65535:
            raise ValueError

        # Gluetun expects a prefix; upstream may emit only the assigned address.
        address = wg["Address"]

        if "/" not in address:
            address += "/32"

        ipaddress.IPv4Interface(address)

        # The PIA server name is needed for forwarding, and both files must name the same endpoint.
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]*", meta["PIA_WG_SERVER_NAME"]):
            raise ValueError

        if meta["PIA_WG_ENDPOINT_IP"] != endpoint or meta["PIA_WG_ENDPOINT_PORT"] != port_text:
            raise ValueError
    except (ValueError, KeyError, UnicodeError) as error:
        raise InvalidSettings(
            "Generated WireGuard configuration or metadata is invalid."
        ) from error

    # Send only connection fields so Gluetun retains its DNS, firewall, and other settings.
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

    # Allow extra dictionary keys, but require lists and individual values to match exactly.
    if is_object(candidate):
        if not is_object(active):
            return False

        active_fields = object_fields(active)
        return all(
            key in active_fields and contains_settings(active_fields[key], value)
            for key, value in object_fields(candidate).items()
        )

    return active == candidate


class Store:
    """Retain complete candidates and finish interrupted two-file publication on startup."""

    def __init__(self, config: Config):
        self.config = config

        # The commit directory holds both source files until publication finishes.
        self.journal = config.config_path.parent / ".privateerr-commit"

        # A pending candidate still needs Gluetun settings and health confirmation.
        self.pending = config.config_path.parent / ".privateerr-pending"

        if config.config_path.resolve() == config.metadata_path.resolve():
            raise ConfigurationError("Configuration and metadata must use different file paths.")

    def saved_settings(self) -> ConnectionSettings:
        """Validate the published pair used when Gluetun starts."""
        return connection_settings(self.config.config_path, self.config.metadata_path)

    def candidate_settings(self, directory: Path) -> ConnectionSettings:
        """Validate a pair in a staging, pending, or interrupted-save directory."""
        return connection_settings(directory / "wg0.conf", directory / "privateerr.env")

    def retain(self, source: Path, destination: Path) -> None:
        """Mark a candidate ready only after copying and validating both files."""

        # Remove any old ready marker before replacing the candidate it described.
        shutil.rmtree(destination, ignore_errors=True)
        destination.mkdir(mode=0o700)

        for name in ("wg0.conf", "privateerr.env"):
            shutil.copyfile(source / name, destination / name)

        # Mark completion last so startup can distinguish a usable pair from a partial copy.
        settings = self.candidate_settings(destination)
        (destination / "settings.json").write_text(json.dumps(settings))
        (destination / "ready").touch()

    def publish(self, source: Path) -> None:
        """Replace each complete file and retain source copies until both replacements finish.

        Args:
            source: Directory containing a validated configuration and metadata pair.

        Raises:
            InvalidSettings: If the source files do not describe one usable connection.
            OSError: If copying or replacement fails. A complete commit directory is
                retained so startup can finish an interrupted publication.
        """

        # Keep complete source copies before replacing either published file.
        self.candidate_settings(source)

        if source != self.journal:
            self.retain(source, self.journal)

        # Each rename is atomic; startup can finish a save interrupted between the two replacements.
        for name, destination in (
            ("wg0.conf", self.config.config_path),
            ("privateerr.env", self.config.metadata_path),
        ):
            replacement = destination.with_name(destination.name + ".new")
            shutil.copyfile(self.journal / name, replacement)
            replacement.replace(destination)

        # Both published files now match, so the recovery copies are no longer needed.
        shutil.rmtree(self.journal)

    def resume(self) -> None:
        """Finish an interrupted save when both source files were copied and validated."""

        # A ready marker identifies a complete pair; discard incomplete copies when it is absent.
        if (self.journal / "ready").is_file():
            self.publish(self.journal)
        else:
            shutil.rmtree(self.journal, ignore_errors=True)
