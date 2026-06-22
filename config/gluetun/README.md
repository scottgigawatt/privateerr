# Gluetun Config Hold 🧭

Avast! This be Gluetun's berth, where the VPN tunnel keeps its charts, dock papers, and assorted salty scribbles.

> [!IMPORTANT]
> 🏴‍☠️ Privateerr and Gluetun both mount this directory. Privateerr draws the WireGuard map first, then Gluetun follows that map into the tunnel.

The two prized scrolls live here:

```text
config/gluetun/wireguard/wg0.conf
config/gluetun/wireguard/privateerr.env
```

> [!TIP]
> 🦜 `privateerr.env` carries `PIA_WG_SERVER_NAME`. The wrapper turns that into Gluetun's `SERVER_NAMES` value so PIA port forwarding knows which dock to hail.

The wrapper script lives here too:

```text
config/gluetun/scripts/gluetun-entrypoint-wrapper.sh
```

That wrapper waits for `privateerr.env`, grabs `PIA_WG_SERVER_NAME`, exports it as `SERVER_NAMES`, and then hands the wheel back to Gluetun's original entrypoint like a proper first mate.

> [!NOTE]
> ⚓ Runtime barnacles such as `forwarded_port`, `ip`, `piaportforward.json`, and Gluetun's server cache are ignored by git.
