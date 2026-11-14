---
icon: material/ship-wheel
---

# Privateerr documentation 🏴‍☠️

The Privateerr container creates a PIA WireGuard configuration file and can refresh the configuration after a sustained outage. The Gluetun VPN container runs the VPN connection; qBittorrent uses that connection.

## Get a working stack

[Follow the quickstart](https://github.com/scottgigawatt/privateerr/blob/main/README.md#quickstart) to clone the project, edit `.env`, and start the three published images. Finish by checking VPN health and signing in to qBittorrent.

Only need a PIA WireGuard configuration file? [Run the published Privateerr image once](advanced-usage.md#generate-without-make), then use the output with your VPN client.

## Run and maintain

- [Automatic recovery](automatic-recovery.md): check monitoring, choose a region, and diagnose failures.
- [Maintenance and images](advanced-usage.md): update, back up, stop, or use Make.
- [Support](SUPPORT.md) and [private vulnerability reporting](SECURITY.md).
- [Plundarr](https://scottgigawatt.github.io/plundarr/): generate a larger media stack using Privateerr.
- [Plundarrpedia](https://scottgigawatt.github.io/plundarrpedia/): follow the wider platform walkthrough.

## Build or contribute

Start with the [developer overview](development/privateerr/index.md), then use [architecture](development/privateerr/architecture.md), [testing](development/privateerr/testing.md), or the [Python reference](development/privateerr/reference/index.md) as needed. [Contributing](CONTRIBUTING.md) and [writing standards](documentation-style.md) explain project conventions.
