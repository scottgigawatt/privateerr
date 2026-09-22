#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# config.py: Read deployment settings without requiring new environment variables.
#

"""Read deployment settings without requiring new environment variables."""

import re
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import urlsplit


class ConfigurationError(ValueError):
    """Report an actionable configuration problem without including secret values."""


@dataclass(frozen=True)
class Config:
    """Keep validated deployment settings separate from changing recovery state."""

    environment: dict[str, str] = field(repr=False)
    config_path: Path
    metadata_path: Path
    marker: Path
    log_path: Path
    bin_home: Path
    recover: bool
    keepalive: bool
    generation_timeout: int
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
        env = environment.copy()

        def value(name: str, default: str) -> str:
            return env.get(name) or default

        def seconds(name: str, default: str) -> int:
            text = value(name, default)
            if not re.fullmatch(r"[1-9][0-9]{0,3}", text):
                raise ConfigurationError(f"{name} must be between 1 and 9999 seconds.")
            return int(text)

        recovery = value("PRIVATEERR_AUTO_RECOVER", "false")
        if recovery not in ("true", "false"):
            raise ConfigurationError("PRIVATEERR_AUTO_RECOVER must be true or false.")

        env["PIA_BIN_HOME"] = value("PIA_BIN_HOME", "/pia")
        env["PREFERRED_REGION"] = value("PREFERRED_REGION", "ca")
        config_path = Path(value("PIA_CONF_PATH", "/gluetun/wireguard/wg0.conf"))
        metadata_path = Path(value("PRIVATEERR_METADATA_PATH", "/gluetun/wireguard/privateerr.env"))
        keepalive = value("PRIVATEERR_KEEPALIVE", "true") == "true"
        options = {}

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
            key = value("PRIVATEERR_GLUETUN_API_KEY", "")
            if not re.fullmatch(r"[A-Za-z0-9]{20,128}", key):
                raise ConfigurationError(
                    "Set PRIVATEERR_GLUETUN_API_KEY to a shared 20-128 character alphanumeric API key."
                )
            if config_path.parent.resolve() != metadata_path.parent.resolve():
                raise ConfigurationError(
                    "Recovery requires the configuration and metadata in the same mounted directory."
                )
            options["api_key"] = key
            for option, variable, default in (
                ("api_url", "PRIVATEERR_GLUETUN_URL", "http://gluetun:8000"),
                ("health_url", "PRIVATEERR_GLUETUN_HEALTH_URL", "http://gluetun:9999"),
            ):
                url = value(variable, default)
                if not re.fullmatch(r"https?://[A-Za-z0-9.-]+:[0-9]+/?", url):
                    raise ConfigurationError(
                        f"{variable} must be an HTTP(S) host and port without credentials or a path."
                    )
                try:
                    port = urlsplit(url).port
                    if port is None or port < 1:
                        raise ValueError
                except ValueError:
                    raise ConfigurationError(f"{variable} must specify a valid TCP port.") from None
                options[option] = url.rstrip("/")
            options["interval"] = seconds("PRIVATEERR_RECOVERY_INTERVAL_SECONDS", "30")
            options["failure_seconds"] = seconds("PRIVATEERR_RECOVERY_FAILURE_SECONDS", "120")
            options["cooldown"] = seconds("PRIVATEERR_RECOVERY_COOLDOWN_SECONDS", "300")

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
