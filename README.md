<hr />

<p align="center">
  <em>🦜 Parrot says: Smash that ⭐️ or walk the plank, ye landlubber!</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Dockerized-Brig-blue?logo=docker" alt="Dockerized Brig" />
  <img src="https://github.com/scottgigawatt/privateerr/actions/workflows/build-and-push.yml/badge.svg" alt="🏴‍☠️ Build: Shipshape" />
  <img src="https://img.shields.io/badge/Cloaked-by%20PIA%20%26%20WireGuard-green?logo=protonvpn" alt="Cloaked" />
  <img src="https://img.shields.io/github/license/scottgigawatt/privateerr?label=Code%20o'%20Conduct&color=blue" alt="Code o' Conduct" />
  <img src="https://img.shields.io/github/last-commit/scottgigawatt/privateerr?label=Last%20Raid&logo=git" alt="Last Raid" />
  <img src="https://img.shields.io/github/repo-size/scottgigawatt/privateerr?label=Hold%20Capacity" alt="Hold Capacity" />
  <img src="https://img.shields.io/badge/Battle--Tested-Synology%20%7C%20macOS-blue" alt="Battle-Tested" />
  <img src="https://img.shields.io/badge/Rum%20Rations-Plentiful-orange" alt="Rum Rations" />
</p>

<p align="center">─── ⛧ ───</p>

<p align="center">
    <em>💀 Need help or wanna trade cursed tech tips over lava? Step forward… <strong>Enter 🔥HADES🔥</strong>.</em>
</p>

<p align="center">
  <a href="https://discord.gg/BpEGzWwGYf">
    <img src="https://img.shields.io/discord/1403601106315116626?label=%F0%9F%94%A5HADES%F0%9F%94%A5&logo=discord&logoColor=white&color=5865F2" alt="🔥HADES🔥 Discord" />
  </a>
</p>

<hr />

# ⚓️ Privateerr ☠️🏴‍☠️

Ahoy there! Welcome to Privateerr, where we sail the digital seas with Private Internet Access and WireGuard!

## 🦜 Captain's Log ⚓️

Privateerr be a tool fer generatin' a native WireGuard config file fer Private Internet Access (PIA). She takes the official PIA manual connection scripts, bundles 'em into a Docker image, and adds all the tools needed to craft a proper WireGuard chart to guide yer VPN voyage.

> [!NOTE]
> ☠️ Privateerr don't set sail on the VPN seas herself—she just scribbles the map. The config file she leaves behind can be handed off to a proper first mate like [Gluetun](https://github.com/qdm12/gluetun) to hoist the sails and make the actual connection.

The main configuration lives in the [docker-compose.yml](./docker-compose.yml) manifest. This handles buildin' the image from an Ubuntu Focal base, usin' the [Dockerfile](./docker/Dockerfile) found in the `docker` directory. Customize yer voyage by copyin' [example.env](./example.env) to `.env` and adjustin' the knobs to yer likin'.

A copy of the [Manual PIA VPN Connections](https://github.com/pia-foss/manual-connections) repo be included as a submodule in `docker/pia`, so it's baked into the build. When she's done, ye'll find yer precious WireGuard config at [`config/wg0.conf`](config/wg0.conf), ready to be hoisted aboard a client like [Gluetun](https://github.com/qdm12/gluetun).

> [!TIP]
> ⚓ If ye be wonderin' how to use Privateerr alongside a proper VPN client like Gluetun, take a gander at the [Plundarr README](https://github.com/scottgigawatt/plundarr#readme) and the [docker-compose file](https://github.com/scottgigawatt/plundarr/blob/main/docker-compose.yml#L82-L171). There ye'll find a battle-tested setup where Privateerr scrawls the WireGuard map, and Gluetun sets sail with it.
>
> 🧭 This setup be mighty handy, as PIA server latency can shift like the tides. With this rig, ye can simply restart the stack and let Privateerr chart a new course to the lowest-latency port before Gluetun embarks. Smooth sailin' guaranteed!

Chart yer course with Privateerr and roam the open seas with stealth and style! 🏴‍☠️

## 🗺️ Chartin' Yer Course 🔧

To set sail and embark on yer VPN journey, follow these steps:

> [!IMPORTANT]
> 🦜 Adjust yer `.env` like a savvy navigator before hoisting anchor.

```bash
# Hoist the Jolly Roger and clone the repository with submodules
git clone --recurse-submodules git@github.com:scottgigawatt/privateerr.git
cd privateerr

# Copy the example environment file
cp example.env .env

# Open .env file and adjust the values to yer requirements

# Weigh anchor and start the container
make

# Spy yer WireGuard treasure map at config/wg0.conf
```

The treasure map to yer WireGuard configuration file will be buried in the [`config`](./config/) directory. This directory contains a default configuration file, [`wg0.conf`](./config/wg0.conf).

When ye run Privateerr, this file will be updated with the PIA WireGuard configuration. Ye can then use this configuration file to configure a VPN client like [Gluetun](https://github.com/qdm12/gluetun) for secure connections.

> [!WARNING]
> ⚓️ Yer precious `wg0.conf` be the map to yer VPN treasure—keep it safe or risk scurvy.

## ☠️ Navigatin' Troubled Waters 🌊

The included `Makefile` be yer trusty map to help ye navigate these treacherous waters. Use these commands to steer yer ship with ease and gain a clearer view of the environment and configuration details. Set sail with confidence, ye scurvy dogs! 🏴‍☠️

```console
❯ make help
Usage: make [TARGET]

Targets:
  all             - Builds and starts the service stack.
  build-depends   - Ensures build dependencies are installed.
  down            - Stops and removes containers, networks, volumes, and images.
  clean           - Alias for down.
  build           - Builds the service stack.
  up              - Builds, (re)creates, and starts containers for services.
  run             - Alias for up.
  logs            - Shows logs for the service.
  help            - Displays this help message.
```

## 🏝️ Know Yer Waters 🔍

> [!CAUTION]
> 🏴‍☠️⚠️ While tested on Synology an' macOS, other waters may be stormier than expected.

Privateerr has been tested on Synology DS1522+ and DS916+ running DSM 7.2 as well as macOS Sequoia. But fear not, me hearties! It should work on other lands as well.

## ⚖️ Keep to the Code 📜

This project be licensed under the Apache 2 License—see the [LICENSE](LICENSE) scroll for details.

The PIA manual connection scripts used in this repository be licensed under the [MIT license](https://choosealicense.com/licenses/mit/), 🪏❌ buried [here](https://github.com/pia-foss/manual-connections/blob/master/LICENSE).

---

```
               ______
            .-'      `-.
           /            \
          |              |
          |,  .-.  .-.  ,|
          | )(_o/  \o_)( |
          |/     /\     \|
          (_     ^^     _)
           \__|IIIIII|__/
            | \IIIIII/ |
            \          /
             `--------`
          ☠️ Privateerr ☠️
  Adventure Awaits, Treasure Beckons!
```

🏝️ Cast yer pull requests ashore, or send a message in a bottle.

_The sea calls, the code answers. Fair winds and full containers, matey! 🌊🏴‍☠️_
