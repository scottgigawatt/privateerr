# Privateerr ⚓

Privateerr is a tiny Docker wrapper that packages the original, unmodified [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections) scripts from Private Internet Access (PIA).

> [!IMPORTANT]
>
> Privateerr is not a VPN client. It generates a PIA WireGuard configuration file and server metadata. Its Python supervisor can also monitor Gluetun and recover sustained tunnel failures through the authenticated API. Gluetun owns the VPN tunnel.

## Pull an image 📦

```sh
docker pull scottgigawatt/privateerr:latest
```

`latest` is the newest stable release. To test the newest successful build from `main` before it becomes a release, opt in to `edge`:

```sh
docker pull scottgigawatt/privateerr:edge
```

| 🏷️ Tag        | 🧭 Purpose                                                          |
| ------------- | ------------------------------------------------------------------- |
| `latest`      | Newest stable semantic-version release; recommended for most users. |
| `1.0.0`       | A specific stable release.                                          |
| `1.0`         | Newest stable release in one minor-version line.                    |
| `1`           | Newest stable release in one major-version line.                    |
| `edge`        | Newest successful `main` build; may change before the next release. |
| `sha-cfa2fb5` | Image built from a specific source commit.                          |

Major version zero omits the broad `0` alias. Prerelease versions keep only their own version and commit tags, never replacing movable stable aliases.
Release publication accepts only `v`-prefixed annotated SemVer tags whose commits already belong to `main`.

Published tags are multi-architecture manifests for:

| 🧱 Platform    | 🖥️ Typical use                |
| -------------- | ----------------------------- |
| `linux/amd64`  | Intel and AMD x86_64 systems. |
| `linux/arm64`  | Modern ARM64 systems.         |
| `linux/arm/v7` | 32-bit ARMv7 systems.         |

Docker should pull the right image for your host automatically.

Images are built from pinned Alpine digests and scanned before publishing. Dependency updates land through Renovate PRs first, so a rebuild of the same source commit does not silently drift to a new base image.

## Generate configuration ⚡

Most users should use the GitHub repository because it includes the Compose file, Makefile, example environment file, and mounted config directories:

```sh
git clone --recurse-submodules https://github.com/scottgigawatt/privateerr.git
cd privateerr
cp example.env .env
```

Set `PIA_USER`, `PIA_PASS`, and `PIA_PF` in the ignored `.env` file, then generate the files:

```sh
make run-privateerr
```

That writes:

| 📄 File                                   | 🎯 Purpose                                                  |
| ----------------------------------------- | ----------------------------------------------------------- |
| `config/gluetun/wireguard/wg0.conf`       | The PIA WireGuard configuration file.                       |
| `config/gluetun/wireguard/privateerr.env` | Selected PIA endpoint and Gluetun port forwarding metadata. |

> [!WARNING]
>
> Keep live `wg0.conf` and `privateerr.env` files private. They can contain VPN connection material and deployment-specific metadata.

## Pair Privateerr with Gluetun 🧭

Gluetun is a real VPN client. Privateerr generates PIA WireGuard configuration and server metadata for that client.

For one-shot generation, `make run-privateerr` disables recovery and keepalive for that disposable run, then exits. Stop a running supervisor before generating into the same directory.

The powerful use case is: run Privateerr and Gluetun together in Docker Compose. Privateerr writes the WireGuard config plus `PIA_WG_SERVER_NAME`; the included Gluetun wrapper reads that server name, exports it as `SERVER_NAMES`, and Gluetun starts with the right PIA WireGuard server for port forwarding.

With recovery enabled, Privateerr reuses valid saved files at startup, checks recovery write access, and monitors Gluetun's status and health. After a sustained outage it generates and applies replacement settings, then saves them after confirmation. Containers keep running. The supplied Compose example enables recovery after you configure a shared API key; custom image-only deployments retain recovery-disabled defaults.

Logs identify storage failures and the selected VPN region without adding credentials or keys to the supervisor's summaries. Privateerr remains UID 0 because upstream scripts require it; the supplied Compose drops all Linux capabilities and enables `no-new-privileges`. See the [recovery and diagnostics guide](https://github.com/scottgigawatt/privateerr/blob/main/docs/automatic-recovery.md).

## Continue with the full documentation 🔗

| 📚 Resource | 🔎 Link                                                                       |
| ----------- | ----------------------------------------------------------------------------- |
| GitHub repository | [scottgigawatt/privateerr](https://github.com/scottgigawatt/privateerr)       |
| PIA scripts | [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections) |
| Gluetun     | [qdm12/gluetun](https://github.com/qdm12/gluetun)                             |
