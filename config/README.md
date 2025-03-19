# Config Directory

Ahoy, matey! This be the config directory for Privateerr, yer trusty Docker Compose setup for Private Internet Access VPN connections with WireGuard.

## Purpose

> [!NOTE]
> 🏴‍☠️ This be where yer default `wg0.conf` lives, ready to be updated with fresh coordinates once Privateerr sets sail!

This directory contains a default configuration file, [`wg0.conf`](./wg0.conf). When ye run Privateerr and weigh anchor, this file will be updated with the PIA WireGuard configuration.

## Instructions

> [!TIP]
> 🦜 Before hoistin’ anchor, make sure yer `.env` and Docker Compose file are ready to chart the right course.

To use this directory:

1. Run Privateerr and start the container.
2. Wait for the setup to complete and the [`wg0.conf`](./wg0.conf) file to be updated with the new configuration.
3. Find yer treasure map in this directory.

> [!IMPORTANT]
> ⚓️ Don’t forget to grab yer freshly minted `wg0.conf`—it be the key to unlockin’ safe VPN waters ahead!

Ye can then use this file to configure a VPN client like Gluetun for secure connections.

> [!CAUTION]
> ☠️ If ye skip these steps or lose yer config, ye may find yerself marooned without a secure VPN!

Fair winds and following seas, me mateys! 🌊🏴‍☠️
