# ⚓ Privateerr

Privateerr is a lightweight Docker image that packages the unmodified Private Internet Access (PIA) manual connection scripts from [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections).

> [!IMPORTANT]
> **Privateerr is not a VPN client.** It generates a PIA WireGuard config file and a small Gluetun metadata file, then gets out of the way.

## 📦 Images

```bash
docker pull scottgigawatt/privateerr:latest
```

Published tags are multi-architecture manifests for:

| 🧱 Platform | 🖥️ Typical use |
| --- | --- |
| `linux/amd64` | Intel and AMD x86_64 systems. |
| `linux/arm64` | Modern ARM64 systems. |
| `linux/arm/v7` | 32-bit ARMv7 systems. |

Docker should pull the right image for your host automatically.

## ⚡ Fastest Path

Most users should use the GitHub repo because it includes the Docker Compose file, Makefile, example env file, and mounted config directories:

```bash
git clone --recurse-submodules https://github.com/scottgigawatt/privateerr.git
cd privateerr
cp example.env .env
PIA_USER="p1234567" PIA_PASS="p0rtRoya1" PIA_PF="false" make run-privateerr
```

That writes:

| 📄 File | 🎯 Purpose |
| --- | --- |
| `config/gluetun/wireguard/wg0.conf` | The PIA WireGuard config. |
| `config/gluetun/wireguard/privateerr.env` | Selected PIA endpoint and Gluetun handoff metadata. |

> [!WARNING]
> Keep `wg0.conf` private. It contains VPN connection material.

## 🧭 Why Pair It With Gluetun?

Gluetun is a real VPN client. Privateerr is a config generator.

The simple use case is: generate `wg0.conf`, copy it into the VPN client you already use, and leave.

The powerful use case is: run Privateerr and Gluetun together in Docker Compose. Privateerr writes the WireGuard config plus `PIA_WG_SERVER_NAME`; the included Gluetun wrapper reads that server name, exports it as `SERVER_NAMES`, and Gluetun starts with the right PIA WireGuard server for port forwarding.

## 🔗 Links

| 📚 Resource | 🔎 Link |
| --- | --- |
| GitHub repo | [scottgigawatt/privateerr](https://github.com/scottgigawatt/privateerr) |
| PIA scripts | [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections) |
| Gluetun | [qdm12/gluetun](https://github.com/qdm12/gluetun) |
