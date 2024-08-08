# Privateerr ☠️🏴‍☠️

Ahoy there! Welcome to Privateerr, where we sail the digital seas with Private Internet Access and WireGuard!

## Overview 🦜⚓️

Privateerr be a Docker Compose setup designed to build PIA manual connection scripts into a Docker image with the necessary WireGuard tools, generating a configuration file for native WireGuard connections. This setup ensures ye have a secure VPN connection as ye navigate the digital seas.

The main configuration lives in the [docker-compose.yml](./docker-compose.yml) file. This file handles building the image based on Ubuntu Focal, using the [Dockerfile](./docker/Dockerfile) found in the `docker` directory. The Docker Compose setup can be customized by copyin' the [example.env](./example.env) file to `.env` and adjustin' it to suit yer needs.

Included in this repo is the [PIA manual-connections](https://github.com/pia-foss/manual-connections) repository as a submodule at `docker/pia`, so it's part of the image build. Once the build is complete, ye can use the generated WireGuard configuration file at [`config/wg0.conf`](config/wg0.conf) to set up a VPN client like Gluetun.

Set sail with Privateerr, and enjoy secure connections across the seven seas! 🌊🏴‍☠️

## Usage 🗺️🔧

To set sail and embark on yer VPN journey, follow these steps:

```bash
# Hoist the Jolly Roger and clone the repository with submodules
git clone --recurse-submodules git@github.com:scottgigawatt/privateerr.git
cd privateerr

# Copy the example environment file
cp example.env .env

# Open .env file and adjust the values to yer requirements

# Weigh anchor and start the container
make
```

The treasure map to yer WireGuard configuration file will be buried in the [`config`](./config/) directory. This directory contains a default configuration file, [`wg0.conf`](./config/wg0.conf). When ye run Privateerr, this file will be updated with the PIA WireGuard configuration. Ye can then use this configuration file to configure a VPN client like Gluetun for secure connections.

## Navigatin' Troubled Waters ‍️☠️🌊

The included `Makefile` contains targets t' help ye navigate these treacherous waters. Usin' these commands will provide ye with a clearer view o' the environment an' configuration details without the additional comments. Set sail with confidence, ye scurvy dogs! 🏴‍☠️

```sh
❯ make help
Usage: make [TARGET]

Targets:
  all             - Builds and starts the service stack.
  build-depends   - Ensures build dependencies are installed.
  pia-creds       - Ensures Private Internet Access credentials are set.
  down            - Stops and removes containers, networks, volumes, and images.
  clean           - Alias for down.
  build           - Builds the service stack.
  up              - Builds, (re)creates, and starts containers for services.
  run             - Alias for up.
  logs            - Shows logs for the service.
  help            - Displays this help message.
```

## Environment Details 🏝️🔍

Privateerr has been tested on Synology DS916+ running DSM 7.2.1-69057 Update 5, with Docker Compose version v2.9.0-6413-g38f6acd as well as macOS Sonoma 14.6. But fear not, me hearties! It should work on other lands as well.

## License ⚖️📜

This project be licensed under the Apache 2 License - see the [LICENSE](LICENSE) scroll for details.

The PIA manual connection scripts used in this repository be licensed under the [MIT license](https://choosealicense.com/licenses/mit/), buried [here](https://github.com/pia-foss/manual-connections/blob/master/LICENSE).

---

Ye scurvy dogs be welcome to join the crew and improve Privateerr. Feel free to submit pull requests or share yer thoughts. Fair winds and following seas, me mateys! 🌊🏴‍☠️
