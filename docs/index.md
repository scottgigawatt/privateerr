---
icon: material/ship-wheel
---

# Privateerr documentation 🏴‍☠️

Privateerr creates PIA WireGuard settings and can refresh them after a sustained outage. Gluetun runs the VPN connection; qBittorrent uses it.

## Get a working stack

[Follow the quickstart](https://github.com/scottgigawatt/privateerr#quickstart) to clone the project, edit `.env`, and start the three published images. Finish by checking VPN health and signing in to qBittorrent.

Only need a VPN configuration file? [Run Privateerr once](advanced-usage.md#generate-without-make), then use the output with your VPN client.

## Run and maintain

- [Automatic recovery](automatic-recovery.md): check monitoring, choose a region, and diagnose failures.
- [Maintenance and images](advanced-usage.md): update, back up, stop, or use Make.
- [Support](SUPPORT.md) and [private vulnerability reporting](SECURITY.md).
- [Plundarr](https://github.com/scottgigawatt/plundarr): generate a larger media stack using Privateerr.
- [Plundarrpedia](https://scottgigawatt.github.io/plundarrpedia/): follow the wider platform walkthrough.

## Build or contribute

Start with the [developer overview](development/privateerr/index.md), then use [architecture](development/privateerr/architecture.md), [testing](development/privateerr/testing.md), or the [Python reference](development/privateerr/reference/index.md) as needed. [Contributing](CONTRIBUTING.md) and [writing standards](documentation-style.md) explain project conventions.
