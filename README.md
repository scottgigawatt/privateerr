<!-- markdownlint-disable-next-line MD033 MD041 -->
<p align="center">
  <em>🏴‍☠️ Generate PIA WireGuard configuration, hand it to a real VPN client, and get out of the way.</em>
</p>

<!-- markdownlint-disable MD033 -->
<p align="center">
  <a href="https://github.com/scottgigawatt/privateerr/actions/workflows/build-and-push.yml"><img src="https://github.com/scottgigawatt/privateerr/actions/workflows/build-and-push.yml/badge.svg" alt="Privateerr build status" /></a>
  <img src="https://img.shields.io/github/v/release/scottgigawatt/privateerr?label=Release" alt="Latest Privateerr release" />
  <a href="https://www.bestpractices.dev/projects/13442"><img src="https://www.bestpractices.dev/projects/13442/badge" alt="OpenSSF Best Practices" /></a>
  <img src="https://img.shields.io/github/license/scottgigawatt/privateerr?label=License" alt="Apache 2.0 license" />
  <img src="https://img.shields.io/badge/Platforms-amd64%20%7C%20arm64%20%7C%20arm%2Fv7-blue?logo=docker" alt="Published for amd64, arm64, and arm/v7" />
  <img src="https://img.shields.io/badge/Scanned-Trivy-teal?logo=aqua" alt="Container image scanned with Trivy" />
</p>

<p align="center">
  <a href="https://discord.gg/BpEGzWwGYf"><img src="https://img.shields.io/discord/1403601106315116626?label=%F0%9F%94%A5HADES%F0%9F%94%A5&logo=discord&logoColor=white&color=5865F2" alt="HADES Discord community" /></a>
</p>
<!-- markdownlint-enable MD033 -->

# Privateerr 🏴‍☠️

Privateerr packages the official, unmodified [Private Internet Access manual-connection scripts](https://github.com/pia-foss/manual-connections) in a small Alpine container. It runs those scripts to generate a PIA WireGuard configuration and writes a companion metadata file for Gluetun automation.

> [!IMPORTANT]
> Privateerr is not a virtual private network (VPN) client. It does not create or maintain a tunnel. It generates `wg0.conf` for a VPN client such as Gluetun or WireGuard.

The upstream PIA scripts remain visible as the `docker/pia-manual-connections` submodule. Privateerr adds repeatable container execution, safe defaults, health reporting, and a small metadata handoff without modifying the upstream scripts.

## Understand the data flow 🧭

Privateerr runs first and writes two files. Gluetun then uses `wg0.conf` to establish the VPN tunnel and reads `PIA_WG_SERVER_NAME` from `privateerr.env` when PIA port forwarding is enabled. The test-only Buccaneerr image can validate the completed path from inside Gluetun's network namespace.

```mermaid
flowchart TB
    PIA["PIA manual-connection scripts"]
    Privateerr["Privateerr generates configuration"]
    Files["wg0.conf + privateerr.env"]
    Gluetun["Gluetun starts the VPN tunnel"]
    Services["Compose services use Gluetun networking"]
    Buccaneerr["Buccaneerr validates the test voyage"]

    PIA -->|unmodified scripts| Privateerr
    Privateerr -->|writes| Files
    Files -->|WireGuard config and server metadata| Gluetun
    Gluetun -->|protected network namespace| Services
    Gluetun -.->|test-only validation| Buccaneerr
```

## Generate a WireGuard configuration ⚡

Clone the repository with its PIA submodule, create the private environment file, and edit the PIA values before running Privateerr:

```sh
git clone --recurse-submodules https://github.com/scottgigawatt/privateerr.git
cd privateerr
cp example.env .env
```

Set `PIA_USER`, `PIA_PASS`, and the desired `PIA_PF` value in `.env`. Keep that file private. Generate fresh configuration:

```sh
make run-privateerr
```

Privateerr writes:

| File | Purpose |
| --- | --- |
| `config/gluetun/wireguard/wg0.conf` | PIA WireGuard configuration for Gluetun, WireGuard, or another compatible client |
| `config/gluetun/wireguard/privateerr.env` | Selected PIA endpoint, region, and port-forwarding metadata for automation |

> [!WARNING]
> Keep live `wg0.conf` and `privateerr.env` files private. They can contain VPN connection material and deployment-specific metadata. Run `make restore-test-config` before committing after a live voyage.

<!-- markdownlint-disable MD033 -->
<details>
<summary>View abbreviated example output</summary>

The checked-in examples use fake pirate-flavored data. A real run overwrites them.

```text
[Interface]
Address = 10.10.10.10
PrivateKey = EXAMPLE-PRIVATE-KEY
DNS = 10.10.10.10

[Peer]
PersistentKeepalive = 25
PublicKey = EXAMPLE-PUBLIC-KEY
AllowedIPs = 0.0.0.0/0
Endpoint = 10.10.10.10:1234
```

```text
PIA_WG_SERVER_NAME=jolly-roger-401
PIA_WG_ENDPOINT_IP=10.10.10.10
PIA_WG_ENDPOINT_PORT=1234
PIA_REGION_ID=skull-island
PIA_REGION_NAME="Skull Island"
PIA_PORT_FORWARDING_SUPPORTED=true
PIA_GEOLOCATED_REGION=false
```

</details>
<!-- markdownlint-enable MD033 -->

## Enable PIA port forwarding 🚪

Set `PIA_PF=true` in `.env`, then regenerate the files:

```sh
make run-privateerr
```

Privateerr asks PIA for a port-forwarding-capable WireGuard endpoint and writes the matching server name to `privateerr.env`. The included Gluetun wrapper exports that value as `SERVER_NAMES` before starting Gluetun, allowing Gluetun to request the forwarded port from the correct PIA server.

If you only need a WireGuard file, take `wg0.conf` and use it with the compatible client of your choice. If you want the complete automated handoff, use the included Compose stack or the larger [Plundarr project](https://github.com/scottgigawatt/plundarr#readme).

## Start Privateerr with Gluetun 🐳

The repository includes one Synology-friendly `docker-compose.yml` that runs Privateerr before Gluetun:

```sh
make up
```

Inspect what Compose will run:

```sh
make print-config
make config
make ps
```

- `make print-config` prints the project Compose file without comments while leaving variables visible.
- `make config` prints the fully resolved Compose model using `.env`.
- `make ps` prints a compact status table for this Compose project.

## Inspect environment values 🔎

Print every resolved environment value:

```sh
make env
```

Filter the output when investigating one integration:

```sh
make env | grep '^PIA'
make env | grep '^GLUETUN'
```

The `PIA_*` variables map Privateerr defaults to values understood by the upstream scripts. Other variables configure images, mounts, healthchecks, Gluetun handoff, logs, and testing. See `example.env` for the complete documented set.

## Use common maintenance commands ⚙️

| Command | Use it when |
| --- | --- |
| `make run-privateerr` | You need fresh `wg0.conf` and `privateerr.env` only |
| `make up` | You want the Privateerr and Gluetun Compose stack |
| `make down` | You want to stop the stack while preserving volumes and images |
| `make ps` | You need compact service status |
| `make logs` | You need container output |
| `make backup` | You want a recoverable archive of `config/` |
| `make test` | You want the offline policy and helper suite |
| `make clean-test` | You want to stop tests and restore checked-in examples |
| `make restore-test-config` | You want to restore only checked-in examples |
| `make clean` | You want to remove disposable repository artifacts only |
| `make nuke` | You intend to remove project Docker resources and transient state |

`make nuke` removes this project's containers, networks, volumes, service and local images, and repository-owned Buildx cache. It preserves `.env`, `backups/`, and persistent `config/`, then restores the checked-in WireGuard examples. Shared or in-use base images remain.

## Choose an image channel 📦

Images are published to [GitHub Container Registry](https://github.com/scottgigawatt/privateerr/pkgs/container/privateerr) and [Docker Hub](https://hub.docker.com/r/scottgigawatt/privateerr) for `linux/amd64`, `linux/arm64`, and `linux/arm/v7`.

| Channel | Meaning |
| --- | --- |
| `latest` | Newest stable release; recommended for most users |
| `edge` | Newest successful `main` build; may change before release |
| Exact version | One immutable semantic-version release, such as `1.2.3` |
| `sha-...` | Image built from one source revision |

Stable releases also publish minor and stable-major aliases. Major version zero omits the broad `0` alias, and prereleases never replace movable stable aliases.

Read [advanced usage](docs/advanced-usage.md) for multi-architecture builds, end-to-end validation, release channels, registry mirroring, pinned inputs, and generated-file maintenance.

## Understand supply-chain controls 🛡️

Privateerr pins GitHub Actions to full commit hashes and Alpine build bases to image digests. Renovate proposes reviewed updates for actions, Docker images, and the upstream submodule. Pull request validation, CodeQL, OpenSSF Scorecard, Trivy, software bills of materials, and provenance attestations protect the build and publication path.

Successful `main` builds publish `edge`; only a reviewed stable version advances `latest`. Rebuilding the same source commit does not silently select a newer Alpine base.

## Read more and get help 📚

- [Advanced usage](docs/advanced-usage.md): Testing, builds, publishing, maintenance, and generated files.
- [Configuration directories](config/README.md): Runtime state and Gluetun handoff paths.
- [Host scripts](scripts/README.md): Backup, credential preflight, cleanup, and status helpers.
- [Buccaneerr testing](test/README.md): Offline checks and live end-to-end validation.
- [Support](docs/SUPPORT.md): Usage questions, bugs, documentation requests, and safe reporting routes.
- [Contributing](docs/CONTRIBUTING.md): Development setup and pull request expectations.
- [Security policy](docs/SECURITY.md): Supported versions and private vulnerability reporting.
- [Code of Conduct](docs/CODE_OF_CONDUCT.md): Community expectations and enforcement.

Privateerr is licensed under the [Apache License 2.0](LICENSE). The bundled PIA manual-connection scripts remain under PIA's [MIT license](https://github.com/pia-foss/manual-connections/blob/master/LICENSE).

Fair winds, private keys below deck, and no VPN-client identity crises. 🏴‍☠️
