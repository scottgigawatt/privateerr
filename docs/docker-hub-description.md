# Privateerr ⚓

Privateerr packages the original, unmodified [PIA manual-connection scripts](https://github.com/pia-foss/manual-connections) in a small Docker image.

> [!IMPORTANT]
> Privateerr is not a VPN client. It generates a PIA WireGuard configuration and server metadata. Its Python supervisor can monitor Gluetun and recover sustained tunnel failures through the authenticated API. Gluetun owns the VPN tunnel.

## Generate configuration ⚡

You need an active Private Internet Access (PIA) subscription, Git, Docker with Compose, and Make. The repository supplies the Compose file and configuration directories:

```sh
git clone --recurse-submodules https://github.com/scottgigawatt/privateerr.git
cd privateerr
cp example.env .env
```

Set `PIA_USER` and `PIA_PASS` in the private `.env` file. The example enables port forwarding with `PIA_PF=true`.

One-shot generation replaces saved VPN files. Preserve any files you need and stop a supervisor using the destination directory before running:

```sh
make run-privateerr
```

The command builds the checked-out source, disables recovery and keepalive for that disposable run, and exits after writing:

| File | Purpose |
| --- | --- |
| `config/gluetun/wireguard/wg0.conf` | WireGuard configuration for Gluetun or another compatible client |
| `config/gluetun/wireguard/privateerr.env` | Selected PIA endpoint and port-forwarding metadata |

> [!WARNING]
> Keep `.env` and generated VPN files private. They contain credentials, connection material, or deployment-specific metadata.

## Pair Privateerr with Gluetun 🧭

The supplied Gluetun wrapper reads `PIA_WG_SERVER_NAME` from the generated metadata and sets `SERVER_NAMES` for PIA port forwarding. With recovery enabled, Privateerr reuses valid saved files, checks recovery write access, and monitors Gluetun. After a sustained outage, it applies replacement settings and saves them only after confirmation. Startup readiness is separate from tunnel health and future recovery write access.

The Compose example enables recovery after you configure a shared API key. Custom deployments must explicitly set `PRIVATEERR_AUTO_RECOVER=true` to enable it. Privateerr runs as UID 0 because upstream scripts require it; the supplied Compose drops all Linux capabilities and enables `no-new-privileges`.

Follow the [normal startup instructions](https://github.com/scottgigawatt/privateerr#start-privateerr-with-gluetun-) to start only Privateerr, Gluetun, and qBittorrent. Buccaneerr is a separate test service that deliberately interrupts the VPN. The [recovery guide](https://github.com/scottgigawatt/privateerr/blob/main/docs/automatic-recovery.md) covers API authentication, storage diagnostics, region selection, and safe regeneration.

## Choose an image 📦

To pull the stable image directly:

```sh
docker pull scottgigawatt/privateerr:latest
```

Use `latest` for the newest stable release or `edge` for successful `main` builds. Exact semantic-version and `sha-*` tags select a release or commit build; pin an image digest when you need its exact content. See [image channels and publishing](https://github.com/scottgigawatt/privateerr/blob/main/docs/advanced-usage.md#registry-publishing) for the complete tag policy.

Privateerr supports `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. Docker selects the host architecture automatically. The qBittorrent application example supports amd64 and arm64.

Images use pinned Alpine bases and pass scan gates before publication. APK packages can change during an uncached rebuild; passing a scan gate is not a claim of zero findings. See the [security policy](https://github.com/scottgigawatt/privateerr/blob/main/docs/SECURITY.md) for the current process and dated scan evidence.

## Read more 🔗

- [Privateerr repository and quickstart](https://github.com/scottgigawatt/privateerr)
- [Official PIA scripts](https://github.com/pia-foss/manual-connections)
- [Gluetun documentation](https://github.com/qdm12/gluetun-wiki)
