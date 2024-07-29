# Privateerr ☠️🏴‍☠️

Ahoy there! Welcome to Privateerr, where we sail the digital seas with Private Internet Access and WireGuard!

## Overview 🦜⚓️

Privateerr be a Docker Compose configuration for buildin' Private Internet Access manual connection scripts into a Docker image with the required WireGuard tools. It also be generatin' a configuration file for native WireGuard connections. Hoist the sails and set yer course for secure VPN connections, me hearties!

This repo includes the [PIA manual-connections](https://github.com/pia-foss/manual-connections) repository as a submodule at [`docker/pia`](./docker/pia), so it be included in the image build.

Ye can use the output WireGuard configuration file to configure a VPN client like Gluetun for secure connections.

## Usage 🗺️🔧

To set sail and embark on yer VPN journey, follow these steps:

```bash
# Hoist the Jolly Roger and clone the repository with submodules
git clone --recurse-submodules git@github.com:scottgigawatt/privateerr.git
cd privateerr

# Weigh anchor and start the container
PIA_USER=<pia_username> PIA_PASS=<pia_password> make
```

The treasure map to yer WireGuard configuration file will be buried in the [`config`](./config/) directory. This directory contains a default configuration file, [`wg0.conf`](./config/wg0.conf). When ye run Privateerr, this file will be updated with the PIA WireGuard configuration. Ye can then use this configuration file to configure a VPN client like Gluetun for secure connections.

## Environment Details 🏝️🔍

Privateerr has been tested on Synology DS916+ running DSM 7.2.1-69057 Update 5, with Docker Compose version v2.9.0-6413-g38f6acd as well as macOS Sonoma 14.5. But fear not, me hearties! It should work on other lands as well.

## License ⚖️📜

This project be licensed under the Apache 2 License - see the [LICENSE](LICENSE) scroll for details.

---

Ye scurvy dogs be welcome to join the crew and improve Privateerr. Feel free to submit pull requests or share yer thoughts. Fair winds and following seas, me mateys! 🌊🏴‍☠️
