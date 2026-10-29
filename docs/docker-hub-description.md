# Privateerr ⚓

Privateerr packages PIA's official, unmodified [manual-connection scripts](https://github.com/pia-foss/manual-connections) to generate WireGuard configuration and server metadata. Its optional Python supervisor refreshes stale settings through Gluetun's authenticated API. Gluetun owns the VPN tunnel.

## Pull the image

```sh
docker pull scottgigawatt/privateerr:latest
```

Privateerr supports `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. Docker selects your host architecture. The supplied qBittorrent application example supports amd64 and arm64.

Use `latest` for stable releases, `edge` for successful `main` builds, or an exact version for a selected release. Pin a digest for exact contents.

## Generate configuration or run the example

You need an active Private Internet Access (PIA) subscription. Follow the [repository setup](https://github.com/scottgigawatt/privateerr#readme) to generate files only or start the supplied Privateerr, Gluetun, and qBittorrent stack.

Privateerr installs the Gluetun startup wrapper and forwarding hook from its image into the shared configuration directory before reporting ready. No script download is needed. The recovery-enabled Compose example requires a shared API key. Image-only deployments leave recovery disabled unless explicitly enabled.

> [!WARNING]
> Keep credentials and generated VPN files private. Generation can replace saved files; stop other writers and preserve needed state first.

Privateerr retains UID 0 for upstream scripts; the supplied Compose drops all Linux capabilities and enables `no-new-privileges`. Startup readiness does not certify tunnel health or future recovery write access.

See [automatic recovery](https://github.com/scottgigawatt/privateerr/blob/main/docs/automatic-recovery.md), [image channels](https://github.com/scottgigawatt/privateerr/blob/main/docs/advanced-usage.md#registry-publishing), and the [security policy](https://github.com/scottgigawatt/privateerr/blob/main/docs/SECURITY.md). Published scan gates do not establish zero vulnerabilities.

Privateerr is Apache-2.0 licensed; the bundled PIA scripts retain their MIT license.
