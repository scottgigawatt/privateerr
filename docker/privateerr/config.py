#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# config.py: Read deployment settings without requiring new environment variables.
#

"""Validate environment settings before generation or recovery starts.

Existing image-only deployments retain generation and keepalive defaults.
Recovery settings are checked only when recovery is enabled, so unused API
options do not prevent a legacy deployment from starting.
"""

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import TypedDict
from urllib.parse import urlsplit


class RecoveryOptions(TypedDict, total=False):
    """Validated overrides supplied only when automatic recovery is enabled."""

    api_key: str
    api_url: str
    health_url: str
    interval: int
    failure_seconds: int
    cooldown: int


class ConfigurationError(ValueError):
    """Report an actionable configuration problem without including secret values."""


@dataclass(frozen=True)
class Config:
    """Keep validated deployment settings separate from changing recovery state."""

    # Keep inherited credentials available to the adapter without exposing them in object output.
    environment: dict[str, str] = field(repr=False)
    config_path: Path
    metadata_path: Path
    marker: Path
    log_path: Path
    bin_home: Path
    recover: bool
    keepalive: bool
    generation_timeout: int

    # Recovery timing is measured in seconds; these defaults also support direct construction.
    interval: int = 30
    failure_seconds: int = 120
    cooldown: int = 300
    api_url: str = "http://gluetun:8000"
    health_url: str = "http://gluetun:9999"
    api_key: str = field(default="", repr=False)
    catalog_url: str = "https://serverlist.piaservers.net/vpninfo/servers/v6"

    @classmethod
    def from_environment(cls, environment: dict[str, str]) -> "Config":
        """Preserve existing defaults and validate recovery-only settings when enabled."""

        # Normalize a private copy so adapter defaults do not modify the caller's environment.
        env = environment.copy()

        def value(name: str, default: str) -> str:
            """Treat an empty Compose value the same as an omitted setting."""
            return env.get(name) or default

        def seconds(name: str, default: str) -> int:
            """Reject zero, fractional, or excessive waits before entering the monitor loop."""
            text = value(name, default)

            if not re.fullmatch(r"[1-9][0-9]{0,3}", text):
                raise ConfigurationError(f"{name} must be between 1 and 9999 seconds.")

            return int(text)

        # An absent recovery flag preserves the behavior of existing image-only deployments.
        recovery = value("PRIVATEERR_AUTO_RECOVER", "false")

        if recovery not in ("true", "false"):
            raise ConfigurationError("PRIVATEERR_AUTO_RECOVER must be true or false.")

        # The adapter receives upstream variable names; Compose maps deployment names to them.
        env["PIA_BIN_HOME"] = value("PIA_BIN_HOME", "/pia")
        env["PREFERRED_REGION"] = value("PREFERRED_REGION", "ca")
        config_path = Path(value("PIA_CONF_PATH", "/gluetun/wireguard/wg0.conf"))
        metadata_path = Path(value("PRIVATEERR_METADATA_PATH", "/gluetun/wireguard/privateerr.env"))
        keepalive = value("PRIVATEERR_KEEPALIVE", "true") == "true"
        options: RecoveryOptions = {}

        # Gluetun must own the tunnel while Privateerr remains available to monitor it.
        if recovery == "true":
            if (
                not keepalive
                or value("PIA_CONNECT", "false") != "false"
                or value("VPN_PROTOCOL", "wireguard") != "wireguard"
            ):
                raise ConfigurationError(
                    "Recovery requires PRIVATEERR_KEEPALIVE=true, PIA_CONNECT=false "
                    "and VPN_PROTOCOL=wireguard."
                )

            # Validate the shared key without including its value in any error message.
            key = value("PRIVATEERR_GLUETUN_API_KEY", "")

            if not re.fullmatch(r"[A-Za-z0-9]{20,128}", key):
                raise ConfigurationError(
                    "Set PRIVATEERR_GLUETUN_API_KEY to a shared 20-128 character alphanumeric API key."
                )

            # Both outputs must share a directory for staged replacements and interrupted saves.
            if config_path.parent.resolve() != metadata_path.parent.resolve():
                raise ConfigurationError(
                    "Recovery requires the configuration and metadata in the same mounted directory."
                )

            options["api_key"] = key

            # Only explicit server origins are accepted; credentials and route paths stay separate.
            for option, variable, default in (
                ("api_url", "PRIVATEERR_GLUETUN_URL", "http://gluetun:8000"),
                ("health_url", "PRIVATEERR_GLUETUN_HEALTH_URL", "http://gluetun:9999"),
            ):
                url = value(variable, default)

                if not re.fullmatch(r"https?://[A-Za-z0-9.-]+:[0-9]+/?", url):
                    raise ConfigurationError(
                        f"{variable} must be an HTTP(S) host and port without credentials or a path."
                    )

                # Parsing the port also rejects values above the valid TCP range.
                try:
                    port = urlsplit(url).port

                    if port is None or port < 1:
                        raise ValueError
                except ValueError:
                    raise ConfigurationError(f"{variable} must specify a valid TCP port.") from None

                options[option] = url.rstrip("/")

            # Apply recovery timing only after the API settings pass validation.
            options["interval"] = seconds("PRIVATEERR_RECOVERY_INTERVAL_SECONDS", "30")
            options["failure_seconds"] = seconds("PRIVATEERR_RECOVERY_FAILURE_SECONDS", "120")
            options["cooldown"] = seconds("PRIVATEERR_RECOVERY_COOLDOWN_SECONDS", "300")

        # Bound generation in every mode, including one-shot runs with recovery disabled.
        return cls(
            environment=env,
            config_path=config_path,
            metadata_path=metadata_path,
            marker=Path(value("PRIVATEERR_HEALTHCHECK_MARKER", "/healthcheck/privateerr.ready")),
            log_path=Path(value("PRIVATEERR_LOG_PATH", "/privateerr-config/logs/privateerr.log")),
            bin_home=Path(value("PRIVATEERR_BIN_HOME", str(Path(__file__).resolve().parents[1]))),
            recover=recovery == "true",
            keepalive=keepalive,
            generation_timeout=seconds("PRIVATEERR_GENERATION_TIMEOUT_SECONDS", "180"),
            catalog_url=value("PRIVATEERR_SERVERLIST_URL", cls.catalog_url),
            **options,
        )
