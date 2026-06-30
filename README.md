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
  <img src="https://img.shields.io/docker/pulls/scottgigawatt/privateerr?label=Docker%20Hub%20Privateerr&logo=docker" alt="Docker Hub Privateerr Pulls" />
  <img src="https://img.shields.io/badge/Dockerized-Brig-blue?logo=docker" alt="Dockerized Brig" />
  <img src="https://img.shields.io/badge/Cloaked-by%20PIA%20%26%20WireGuard-green?logo=protonvpn" alt="Cloaked" />
  <img src="https://img.shields.io/badge/Base-Alpine%20Pinned-0D597F?logo=alpinelinux" alt="Alpine Pinned" />
  <img src="https://img.shields.io/badge/Multi--Arch-amd64%20%7C%20arm64%20%7C%20arm%2Fv7-blue?logo=docker" alt="Multi-Arch amd64, arm64, and arm/v7" />
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

# ⚓️ Privateerr ☠️🏴‍☠️

Ahoy! Privateerr is a lightweight Docker image that packages the official, unmodified,   Private Internet Access (PIA) ✨ [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections) ✨ scripts.

Those PIA scripts live in this repo as a submodule at `docker/pia-manual-connections`; Privateerr packages them into a small Alpine image, runs them, and makes the output easy to use and consume with automation.

And that's it! That's the whole trick: PIA's original scripts do the WireGuard work. Privateerr just gives them a clean container, friendly defaults, repeatable commands, and a small metadata file for Docker Compose setups.

> [!IMPORTANT]
> **Privateerr is NOT a VPN client.** It does not create or run a VPN tunnel. It generates a PIA WireGuard configuration file (`wg0.conf`) that you can hand to an actual VPN client.

There are already excellent VPN clients. One of the best container-friendly options is [Gluetun](https://github.com/qdm12/gluetun). If what you really want is "get Gluetun working with PIA WireGuard," Privateerr may have you covered: generate the files, point Gluetun at them, and move on.

## ⚡ Fastest Path

Clone the repo with submodules, copy the example environment file, then pass your PIA credentials inline:

```console
❯ git clone --recurse-submodules git@github.com:scottgigawatt/privateerr.git
❯ cd privateerr
❯ cp example.env .env
❯ PIA_USER="p1234567" PIA_PASS="p0rtRoya1" PIA_PF="false" make run-privateerr
```

You don't even need to look at or update the `.env` file to get a fully functioning WireGuard configuration file _in seconds!_ Now, the `.env` file is intentionally roomy, but the defaults are ready to go; just use inline variables to override anything in the `.env` file for that run.

When the command finishes, the main file you came for is here:

```console
❯ cat config/gluetun/wireguard/wg0.conf
[Interface]
Address = 10.10.10.10
PrivateKey = shiverMeTimbers123
DNS = 10.10.10.10

[Peer]
PersistentKeepalive = 25
PublicKey = yoHoHoPublicKey123
AllowedIPs = 0.0.0.0/0
Endpoint = 10.10.10.10:1234
```

Privateerr also writes a tiny metadata file beside the WireGuard config:

```console
❯ cat config/gluetun/wireguard/privateerr.env
PIA_WG_SERVER_NAME=jolly-roger-401
PIA_WG_ENDPOINT_IP=10.10.10.10
PIA_WG_ENDPOINT_PORT=1234
PIA_REGION_ID=skull-island
PIA_REGION_NAME="Skull Island"
PIA_PORT_FORWARDING_SUPPORTED=true
PIA_GEOLOCATED_REGION=false
```

| 📄 File | 🎯 What it is for |
| --- | --- |
| `config/gluetun/wireguard/wg0.conf` | The WireGuard config generated by PIA's scripts. Use this with Gluetun, WireGuard, or another VPN client that accepts WireGuard configs. |
| `config/gluetun/wireguard/privateerr.env` | A small helper file with the selected PIA server name, endpoint, region, and port-forwarding support metadata. |

> [!WARNING]
> Keep `wg0.conf` private. It contains VPN connection material.

## 🚪 Port Forwarding

Want a port-forwarding-capable PIA server? Change one variable:

```console
❯ PIA_USER="p1234567" PIA_PASS="p0rtRoya1" PIA_PF="true" make run-privateerr
```

PIA port forwarding is usually awkward because the server choice matters after WireGuard is involved. Privateerr makes the handoff simple: with `PIA_PF=true`, it asks PIA for a port-forwarding-capable WireGuard endpoint, generates `wg0.conf`, figures out the matching PIA WireGuard server name, and writes that name into `privateerr.env`.

The metadata in `privateerr.env` is what lets a Docker Compose stack establish a fully functioning port forwarded VPN connection in _one single step_, in _less than 1 minute_. Privateerr writes the map, reads `PIA_WG_SERVER_NAME`, exports it as `SERVER_NAMES`, then Gluetun can start immediately with the right server information instead of making you run a second manual step _after_ the VPN connection is established.

> [!TIP]
> For the simplest use case, take `wg0.conf` and leave. For the powerful use case, pair Privateerr with Gluetun in Compose so config generation, server-name handoff, and VPN startup happen together.

For the wired-together version, see the included [Compose file](./docker-compose.yml). For a larger real-world stack, see [Plundarr](https://github.com/scottgigawatt/plundarr#readme).

## 🔎 Inspect The Knobs

Curious about every variable available in this project? Run:

```console
❯ make env
```

If you only care about the PIA settings, anchor the grep at the start of the line:

```console
❯ make env | grep ^PIA
PIA_BIN_HOME=/pia
PIA_VPN_PROTOCOL=wireguard
PIA_DISABLE_IPV6=yes
...
```

If you want to see the Gluetun side:

```console
❯ make env | grep ^GLUETUN
GLUETUN_TAG=latest
GLUETUN_CONFIG_PATH=./config/gluetun
GLUETUN_WRAPPER_SCRIPT_PATH=./config/gluetun/scripts/gluetun-entrypoint-wrapper.sh
...
```

## 🧩 PIA Script Variables

These are the environment variables understood by PIA's own manual connection scripts. Privateerr did not invent them; it passes these values through to the scripts from [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections). Everything else in `.env` is scaffolding around that core: Docker image paths, Compose mounts, healthchecks, Gluetun handoff, logs, and test automation.

| 🧩 PIA script variable | 🛠️ Privateerr `.env` variable | What it configures |
| --- | --- | --- |
| `PIA_USER` | `PIA_USER` | Your PIA username. |
| `PIA_PASS` | `PIA_PASS` | Your PIA password. |
| `DIP_TOKEN` | `PIA_DIP_TOKEN` | Optional PIA dedicated IP token. |
| `PIA_DNS` | `PIA_DNS` | Whether PIA should write DNS settings into the generated config. |
| `PIA_PF` | `PIA_PF` | Whether to request a port-forwarding-capable PIA region. |
| `PIA_CONNECT` | `PIA_CONNECT` | Whether the PIA script should connect after generating config. Privateerr sets this to `false` so it only writes files. |
| `PIA_CONF_PATH` | `PIA_CONF_PATH` | Where the WireGuard config file is written inside the container. |
| `MAX_LATENCY` | Not set by default | Optional latency threshold used by PIA's region selection. |
| `AUTOCONNECT` | `PIA_AUTOCONNECT` | Whether PIA should pick the lowest-latency region automatically. |
| `PREFERRED_REGION` | Not set by default | Optional PIA region ID when you want to choose a specific region. |
| `VPN_PROTOCOL` | `PIA_VPN_PROTOCOL` | Which PIA protocol to use. Privateerr uses `wireguard`. |
| `DISABLE_IPV6` | `PIA_DISABLE_IPV6` | Whether PIA's scripts should disable IPv6 behavior. |

## 🧭 Compose Automation

The included [docker-compose.yml](./docker-compose.yml) is intentionally variable-heavy. That keeps the file reusable, but it can make it hard to read raw.

Use these commands when you want Docker Compose to show you what it sees:

| 🧭 Command | 📄 What it prints |
| --- | --- |
| `make print-config` | The project Compose file with comments removed, but variables still visible. |
| `make config` | The fully rendered Docker Compose model with variables resolved from `.env`. |

So if you want to inspect the template, run:

```console
❯ make print-config
```

If you want to see the actual Compose configuration Docker will run:

```console
❯ make config
```

## ⚙️ Useful Commands

| ⚙️ Command | ✅ Use it when |
| --- | --- |
| `make run-privateerr` | You only want fresh `wg0.conf` and `privateerr.env`. |
| `make up` | You want the full Privateerr + Gluetun Compose stack. |
| `make down` | You want to stop and remove the stack. |
| `make logs` | You want to inspect container output. |
| `make print-config` | You want the Compose template without comments. |
| `make config` | You want the fully rendered Compose model. |
| `make reset-config` | You want to restore the checked-in example config files. |
| `make clean` | You want to stop the stack and restore example config files. |

> [!TIP]
> More build, test, and release details live in [Advanced Usage](./docs/ADVANCED_USAGE.md).

## 📦 Platform Notes

The image builds from Alpine for a small footprint. Alpine is not a distro PIA lists as officially confirmed for the manual scripts, so this project validates the container path separately before publishing images.

Published Privateerr images support `linux/amd64`, `linux/arm64`, and `linux/arm/v7`.

Images are published to both GHCR and Docker Hub:

| 📦 Registry | 🏷️ Image |
| --- | --- |
| GHCR | `ghcr.io/scottgigawatt/privateerr:latest` |
| Docker Hub | `scottgigawatt/privateerr:latest` |

The Docker Hub overview is generated from [docs/DOCKERHUB_README.md](./docs/DOCKERHUB_README.md), which keeps Docker Hub focused on pulling the image and understanding the basic use case. The full project docs stay here in the GitHub README.

## 🛡️ Supply Chain Notes

Privateerr keeps the build deck intentionally locked down:

- GitHub Actions are pinned to full commit SHAs.
- Alpine build bases are pinned to versioned image digests.
- Renovate opens update PRs for pinned actions, Docker digests, Compose images, and submodules.
- Pre-commit, CodeQL, OpenSSF Scorecard, and Trivy guard the repo and image workflow.
- Release images are built on `main`, scanned with Trivy before publish, attested, and mirrored from GHCR to Docker Hub with digest preservation.

This means a new `main` build does **not** silently float to a newer Alpine base just because Alpine published one. Renovate has to raise the flag, CI has to pass, and the update has to merge before the next published image uses that new base.

## ⚖️ License And Community

Privateerr is licensed under Apache 2.0; see [LICENSE](LICENSE). The bundled PIA manual connection scripts are licensed under MIT by PIA; see their [license](https://github.com/pia-foss/manual-connections/blob/master/LICENSE).

### 📖 Community Guides

| 📚 Guide | 🧭 Purpose |
| --- | --- |
| 🤝 [Contributing](docs/CONTRIBUTING.md) | How to offer changes without sinking the dinghy. |
| ⚖️ [Code of Conduct](docs/CODE_OF_CONDUCT.md) | Pirate manners, but useful. |
| 🔐 [Security Policy](docs/SECURITY.md) | How to report leaky hulls without shouting secrets across the harbor. |

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
