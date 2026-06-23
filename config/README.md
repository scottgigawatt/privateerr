# Config Directory

Ahoy, matey! This be the config hold for the full Privateerr stack.

## Purpose

> [!NOTE]
> 🏴‍☠️ Each service gets its own berth under this directory. Gluetun's berth carries the WireGuard map because both Privateerr and Gluetun need to touch it.

The important live files sit here:

```text
config/gluetun/wireguard/wg0.conf
config/gluetun/wireguard/privateerr.env
```

Privateerr overwrites both files when it runs. The checked-in versions are example maps only, safe for the ship's log. If ye run a live test, `make test-down` or `make reset-config` restores the example copies from `test/examples/example-wg0.conf` and `test/examples/example-privateerr.env`.

`privateerr.env` carries the Gluetun metadata scroll. The shiniest coin in that scroll be `PIA_WG_SERVER_NAME`; the Gluetun wrapper reads it, exports `SERVER_NAMES`, and then starts Gluetun proper.

## Instructions

> [!TIP]
> 🦜 Before hoistin' anchor, make sure yer `.env` and Docker Compose file are ready to chart the right course.

To use this directory:

1. Run `make test-e2e` for the full validation voyage.
2. Run `make run-privateerr` if ye only want fresh `wg0.conf` and `privateerr.env`.
3. Run `make reset-config` before committing, lest live secrets sneak aboard.

> [!IMPORTANT]
> ⚓️ The example files are boring on purpose. Real VPN treasure belongs in yer runtime hold, not in git.

Fair winds and following seas, me mateys! 🌊🏴‍☠️
