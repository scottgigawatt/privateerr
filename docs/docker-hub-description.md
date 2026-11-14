# Privateerr ⚓

Privateerr packages PIA's official, unmodified [manual-connection scripts](https://github.com/pia-foss/manual-connections) to create WireGuard configuration. Its built-in Python supervisor can refresh stale settings after a sustained outage. Gluetun runs the VPN tunnel; Privateerr prepares and updates its settings.

## Start with Gluetun and qBittorrent

You need an active PIA subscription and Docker with Compose. The [quickstart](https://github.com/scottgigawatt/privateerr#quickstart) starts the three published images, checks VPN health, and opens qBittorrent. No local image build is needed.

[Create a one-time VPN configuration](https://github.com/scottgigawatt/privateerr/blob/main/docs/advanced-usage.md#generate-without-make) if you want to use your own VPN client.

## Pull the image

```sh
docker pull scottgigawatt/privateerr:latest
```

Privateerr supports `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. Docker selects your host architecture. The supplied qBittorrent stack supports amd64 and arm64. Use `latest` for the current stable release; [image channels](https://github.com/scottgigawatt/privateerr/blob/main/docs/advanced-usage.md#registry-publishing) explain other selections.

## Understand recovery

The supplied Compose example enables the supervisor with a shared private API key. Privateerr installs the Gluetun startup wrapper and forwarding hook into the shared configuration directory; no manual script download is needed. When using the image in your own deployment, enable `PRIVATEERR_AUTO_RECOVER` explicitly to use monitoring.

> [!WARNING]
> Keep credentials and generated VPN files private. Generation can replace saved files; stop other writers and preserve needed state first.

Privateerr retains UID 0 for PIA's scripts; the supplied Compose drops all Linux capabilities and enables `no-new-privileges`. Privateerr's healthy status means configuration is ready, so check Gluetun's tunnel health too.

See [automatic recovery](https://github.com/scottgigawatt/privateerr/blob/main/docs/automatic-recovery.md) and the [security policy](https://github.com/scottgigawatt/privateerr/blob/main/docs/SECURITY.md). A passing vulnerability gate does not mean zero findings.

Privateerr is Apache-2.0 licensed; the bundled PIA scripts retain their MIT license.
