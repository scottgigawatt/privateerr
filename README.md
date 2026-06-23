<!-- markdownlint-disable MD033 MD041 -->

<hr />

<p align="center">
  <em>🦜 Parrot says: Smash that ⭐️ or walk the plank, ye landlubber!</em>
</p>

<p align="center">
  <img src="https://img.shields.io/github/stars/scottgigawatt/privateerr?label=Treasure%20Hunters&logo=github" alt="Treasure Hunters" />
  <img src="https://img.shields.io/github/forks/scottgigawatt/privateerr?label=Mutinous%20Forks&logo=github" alt="Mutinous Forks" />
  <img src="https://img.shields.io/github/watchers/scottgigawatt/privateerr?label=Crow's%20Nest%20Lookouts&logo=github" alt="Crow's Nest Lookouts" />
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/scottgigawatt/privateerr?label=Latest%20Treasure%20Map&logo=github" alt="Latest Treasure Map" />
  <img src="https://github.com/scottgigawatt/privateerr/actions/workflows/build-and-push.yml/badge.svg" alt="🏴‍☠️ Build: Shipshape" />
  <img src="https://img.shields.io/badge/Scanned-Trivy%20Bilge%20Check-teal?logo=aqua" alt="Trivy Bilge Check" />
  <img src="https://img.shields.io/github/license/scottgigawatt/privateerr?label=Legal%20Scroll&color=blue" alt="Legal Scroll" />
  <img src="https://img.shields.io/badge/GHCR-Privateerr%20Captain-blue?logo=github" alt="GHCR Privateerr Captain" />
  <img src="https://img.shields.io/badge/GHCR-Buccaneerr%20Scout-purple?logo=github" alt="GHCR Buccaneerr Scout" />
  <img src="https://img.shields.io/badge/Dockerized-Brig-blue?logo=docker" alt="Dockerized Brig" />
  <img src="https://img.shields.io/badge/Cloaked-by%20PIA%20%26%20WireGuard-green?logo=protonvpn" alt="Cloaked" />
  <img src="https://img.shields.io/badge/Base-Alpine%20Latest-0D597F?logo=alpinelinux" alt="Alpine Latest" />
  <img src="https://img.shields.io/badge/Multi--Arch-amd64%20%7C%20arm64-blue?logo=docker" alt="Multi-Arch amd64 and arm64" />
  <img src="https://img.shields.io/badge/Battle--Tested-Synology%20%7C%20macOS-blue" alt="Battle-Tested" />
  <img src="https://img.shields.io/github/last-commit/scottgigawatt/privateerr?label=Last%20Raid&logo=git" alt="Last Raid" />
  <img src="https://img.shields.io/github/repo-size/scottgigawatt/privateerr?label=Hold%20Capacity" alt="Hold Capacity" />
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

<!-- markdownlint-enable MD033 -->

# ⚓️ Privateerr ☠️🏴‍☠️

Ahoy there! Welcome to Privateerr, where we sail the digital seas with Private Internet Access and WireGuard!

WireGuard be the leaner cannon on this ship. Compared with OpenVPN, it uses a smaller, simpler protocol design, usually needs less CPU to move the same booty, and keeps memory overhead low enough for wee vessels like Synology NAS boxes, home servers, and other resource-pinched decks. That means smoother seas, faster handshakes, and fewer fans screamin' like cursed sirens while yer torrents and containers do their work. Privateerr charts WireGuard on purpose: lighter load, cleaner config, happier NAS. 🧭

## 🦜 Captain's Log ⚓️

Privateerr be a tool fer generatin' a native WireGuard config file fer Private Internet Access (PIA). She takes the official PIA manual connection scripts, bundles 'em into a wee Alpine Docker image, and adds all the tools needed to craft a proper WireGuard chart to guide yer VPN voyage.

> [!NOTE]
> ☠️ Privateerr don't set sail on the VPN seas herself—she just scribbles the map. The config file she leaves behind can be handed off to a proper first mate like [Gluetun](https://github.com/qdm12/gluetun) to hoist the sails and make the actual connection.

The main configuration lives in the [docker-compose.yml](./docker-compose.yml) manifest. This handles buildin' the image from an Alpine base, usin' the [Dockerfile](./docker/Dockerfile) found in the `docker` directory. Customize yer voyage by copyin' [example.env](./example.env) to `.env` and adjustin' the knobs to yer likin'.

A copy of the [Manual PIA VPN Connections](https://github.com/pia-foss/manual-connections) repo be included as a submodule in `docker/pia-manual-connections`, so it's baked into the build. Those upstream scripts stay untouched and shiny as a freshly polished doubloon. Privateerr launches them with [`docker/privateerr-entrypoint.sh`](docker/privateerr-entrypoint.sh), then writes Gluetun metadata beside the generated config. When she's done, ye'll find yer precious WireGuard config at [`config/gluetun/wireguard/wg0.conf`](config/gluetun/wireguard/wg0.conf), and a Gluetun-friendly env scroll at [`config/gluetun/wireguard/privateerr.env`](config/gluetun/wireguard/privateerr.env).

> [!NOTE]
> 🧪 Alpine be a smaller test voyage, not a distro PIA lists as officially confirmed for these scripts. Privateerr builds from Alpine's `latest` tag by default so fresh security patches climb aboard each rebuild, and the e2e stack below inspects the plank before the image ships.

<!-- -->

> [!NOTE]
> 🏴‍☠️ Published Privateerr and Buccaneerr images ship as multi-arch treasure chests for `linux/amd64` and `linux/arm64`. Pull `latest` from Intel/AMD or ARM64 decks, and Docker should grab the right cargo without ye naming the architecture by hand.

<!-- -->

> [!TIP]
> ⚓ If ye be wonderin' how to use Privateerr alongside a proper VPN client like Gluetun, take a gander at the [Plundarr README](https://github.com/scottgigawatt/plundarr#readme) and the [docker-compose file](https://github.com/scottgigawatt/plundarr/blob/main/docker-compose.yml). There ye'll find a battle-tested setup where Privateerr scrawls the WireGuard map, and Gluetun sets sail with it.
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

# Spy yer WireGuard treasure map at config/gluetun/wireguard/wg0.conf
# Spy Gluetun metadata at config/gluetun/wireguard/privateerr.env
```

The treasure map to yer WireGuard configuration file will be buried in the [`config/gluetun/wireguard`](./config/gluetun/wireguard/) directory. This directory contains an example configuration file, [`wg0.conf`](./config/gluetun/wireguard/wg0.conf), so the repo stays shipshape before live credentials overwrite it.

When ye run Privateerr, this file will be updated with the PIA WireGuard configuration. Ye can then use this configuration file to configure a VPN client like [Gluetun](https://github.com/qdm12/gluetun) for secure connections.

Privateerr also writes `config/gluetun/wireguard/privateerr.env`, which includes Gluetun-ready booty such as:

```env
PIA_WG_SERVER_NAME=panama408
PIA_WG_ENDPOINT_IP=1.2.3.4
PIA_WG_ENDPOINT_PORT=1337
PIA_REGION_ID=panama
PIA_PORT_FORWARDING_SUPPORTED=true
```

That `PIA_WG_SERVER_NAME` value matters when Gluetun uses `VPN_SERVICE_PROVIDER=custom` and `VPN_TYPE=wireguard` with PIA port forwarding. In this stack, a tiny wrapper script waits for Privateerr's metadata scroll, exports `SERVER_NAMES`, and then hands the wheel back to Gluetun's original entrypoint. One `docker compose up`, no second voyage required.

> [!WARNING]
> ⚓️ Yer precious `wg0.conf` be the map to yer VPN treasure—keep it safe or risk scurvy.

## 🧪 Trial by Cannon Fire

Privateerr can run a full e2e voyage before ye publish the image. The single Compose stack:

1. Builds Privateerr.
2. Generates `wg0.conf` and `privateerr.env`.
3. Starts Gluetun after Privateerr reports healthy.
4. Enables PIA port forwarding through Gluetun.
5. Runs a one-shot Buccaneerr inside Gluetun's network namespace.

```bash
make test-e2e
```

If ye only want Privateerr to generate config and metadata:

```bash
make run-privateerr
```

If the test voyage gets rowdy and ye need to clear the deck, this also restores the example `wg0.conf` and `privateerr.env` files:

```bash
make test-down
```

> [!IMPORTANT]
> 🏴‍☠️ The e2e test uses real PIA credentials from `.env`. Fake credentials will sink the ship exactly as designed.

## ☠️ Navigatin' Troubled Waters 🌊

The included `Makefile` be yer trusty map to help ye navigate these treacherous waters. Use these commands to steer yer ship with ease and gain a clearer view of the environment and configuration details. Set sail with confidence, ye scurvy dogs! 🏴‍☠️

```console
❯ make help
Usage: make [TARGET]

Targets:
  all                Builds and starts the full service stack.
  build-depends      Ensures build dependencies are installed.
  check-env          Ensures .env exists before Compose commands run.
  down               Stops and removes the full service stack.
  clean              Stops the stack and restores example config files.
  nuke               Removes containers, images, generated files, and restores example config.
  build              Builds only the Privateerr image.
  build-buccaneerr   Builds only the Buccaneerr image.
  build-multiarch    Verifies Privateerr and Buccaneerr build for amd64 and arm64.
  run-privateerr     Runs only Privateerr to generate config and metadata.
  reset-config       Restores example wg0.conf and privateerr.env files.
  test-e2e           Runs the full one-shot Privateerr + Gluetun validation voyage.
  test-down          Stops the stack and restores example config files.
  test-logs          Shows logs for the service stack.
  up                 Builds, (re)creates, and starts every service.
  config             Renders the Docker Compose model.
  env                Prints the evaluated docker compose default env configuration.
  print-config       Prints the raw uncommented docker compose yaml configuration.
  print-env          Prints the raw uncommented docker compose env configuration.
  start              Alias for up.
  stop               Alias for down.
  logs               Shows logs for the service stack.
  help               Displays this help message.
```

## 🏝️ Know Yer Waters 🔍

> [!CAUTION]
> 🏴‍☠️⚠️ While tested on Synology an' macOS, other waters may be stormier than expected.

Privateerr has been tested on Synology DS1522+ and DS916+ running DSM 7.2 as well as macOS Tahoe. But fear not, me hearties! It should work on other lands as well.

## ⚖️ Keep to the Code 📜

This project be licensed under the Apache 2 License—see the [LICENSE](LICENSE) scroll for details.

The PIA manual connection scripts used in this repository be licensed under the [MIT license](https://choosealicense.com/licenses/mit/), 🪏❌ buried [in the PIA manual-connections repository](https://github.com/pia-foss/manual-connections/blob/master/LICENSE).

Community scrolls fer brave souls who wander aboard:

- [Contributing](docs/CONTRIBUTING.md) — how to offer treasure without sinkin' the dinghy.
- [Keep to the Code](docs/CODE_OF_CONDUCT.md) — pirate manners, but make 'em useful.
- [Security Policy](docs/SECURITY.md) — where to report leaky hulls without shoutin' secrets across the harbor.

---

```text
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

<!-- markdownlint-disable-next-line MD036 -->
_The sea calls, the code answers. Fair winds and full containers, matey! 🌊🏴‍☠️_
