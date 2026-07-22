# ⚓ Privateerr

Privateerr is a tiny Docker wrapper that packages the original, unmodified [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections) scripts from Private Internet Access (PIA).

> [!IMPORTANT]
> ⚠️ Privateerr is not a VPN client!️️ ⚠️  It generates a PIA WireGuard config file and a small Gluetun port forwarding metadata file, then gets out of the way.

## 📦 Images

```console
docker pull scottgigawatt/privateerr:latest
```

`latest` is the newest stable release. To test the newest successful build from `main` before it becomes a release, opt in to `edge`:

```console
docker pull scottgigawatt/privateerr:edge
```

| 🏷️ Tag | 🧭 Purpose |
| --- | --- |
| `latest` | Newest stable semantic-version release; recommended for most users. |
| `1.0.0` | A specific stable release. |
| `edge` | Newest successful `main` build; may change before the next release. |
| `sha-cfa2fb5` | Image built from a specific source commit. |

Prerelease versions keep their own tags and never replace `latest`.

Published tags are multi-architecture manifests for:

| 🧱 Platform | 🖥️ Typical use |
| --- | --- |
| `linux/amd64` | Intel and AMD x86_64 systems. |
| `linux/arm64` | Modern ARM64 systems. |
| `linux/arm/v7` | 32-bit ARMv7 systems. |

Docker should pull the right image for your host automatically.

Images are built from pinned Alpine digests and scanned before publishing. Dependency updates land through Renovate PRs first, so a rebuild of the same source commit does not silently drift to a new base image.

## ⚡ Fastest Path

Most users should use the GitHub repo because it includes the Compose file, Makefile, example env file, and mounted config directories:

```console
git clone --recurse-submodules https://github.com/scottgigawatt/privateerr.git
cd privateerr
cp example.env .env
PIA_USER="p1234567" PIA_PASS="p0rtRoya1" PIA_PF="false" make run-privateerr
```

That writes:

| 📄 File | 🎯 Purpose |
| --- | --- |
| `config/gluetun/wireguard/wg0.conf` | The PIA WireGuard configuration file. |
| `config/gluetun/wireguard/privateerr.env` | Selected PIA endpoint and Gluetun port forwarding metadata. |

> [!WARNING]
> 🚨 Keep wg0.conf private! 🚨  It contains VPN connection material.

## 🧭 Why Pair It With Gluetun?

Gluetun is a real VPN client. Privateerr is a VPN config generator.

The simple use case is: generate `wg0.conf`, copy it into the VPN client you already use, and leave.

The powerful use case is: run Privateerr and Gluetun together in Docker Compose. Privateerr writes the WireGuard config plus `PIA_WG_SERVER_NAME`; the included Gluetun wrapper reads that server name, exports it as `SERVER_NAMES`, and Gluetun starts with the right PIA WireGuard server for port forwarding.

## 🔗 Links

| 📚 Resource | 🔎 Link |
| --- | --- |
| GitHub repo | [scottgigawatt/privateerr](https://github.com/scottgigawatt/privateerr) |
| PIA scripts | [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections) |
| Gluetun | [qdm12/gluetun](https://github.com/qdm12/gluetun) |
