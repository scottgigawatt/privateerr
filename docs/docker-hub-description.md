# Privateerr ⚓

Privateerr packages PIA's official, unmodified [manual-connection scripts](https://github.com/pia-foss/manual-connections) to create a PIA WireGuard configuration file. Its built-in Python supervisor can refresh stale configuration after a sustained outage. The Gluetun VPN container runs the VPN tunnel; the Privateerr container prepares and updates its configuration.

## Start with Gluetun and qBittorrent

You need an active PIA subscription and Docker with Compose. The [quickstart](https://github.com/scottgigawatt/privateerr/blob/main/README.md#quickstart) starts the three published images, checks VPN health, and opens qBittorrent. No local image build is needed.

[Create a PIA WireGuard configuration file](https://scottgigawatt.github.io/privateerr/advanced-usage/#generate-without-make) if you want to use your own VPN client. The published Privateerr image writes the files to a mounted directory on your host, then exits. Save existing configuration files first, and do not run multiple Privateerr containers against the same directory.

## Pull the image

```sh
docker pull scottgigawatt/privateerr:latest
```

Privateerr supports `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. Docker selects your host architecture. The supplied qBittorrent stack supports amd64 and arm64. Use `latest` for the current stable release; [image channels](https://scottgigawatt.github.io/privateerr/advanced-usage/#registry-publishing) explain other selections.

## Understand recovery

The supplied Compose example enables the supervisor with a shared private API key. Privateerr installs the Gluetun startup wrapper and forwarding hook into the shared configuration directory; no manual script download is needed. When using the image in your own deployment, enable `PRIVATEERR_AUTO_RECOVER` explicitly to use monitoring.

> [!WARNING]
> Keep credentials and generated VPN files private. Generation can replace saved files; stop other writers and preserve needed state first.

Privateerr retains UID 0 for PIA's scripts; the supplied Compose drops all Linux capabilities and enables `no-new-privileges`. Privateerr's healthy status means configuration is ready, so check Gluetun's tunnel health too.

See [automatic recovery](https://scottgigawatt.github.io/privateerr/automatic-recovery/) and the [security policy](https://scottgigawatt.github.io/privateerr/SECURITY/). A passing vulnerability gate does not mean zero findings.

Privateerr is Apache-2.0 licensed; the bundled PIA scripts retain their MIT license.
