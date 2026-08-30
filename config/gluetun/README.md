# Gluetun configuration 🧭

Privateerr and Gluetun both mount this directory. Privateerr generates the WireGuard configuration first, and Gluetun uses it to start the tunnel.

The shared files live here:

```text
config/gluetun/wireguard/wg0.conf
config/gluetun/wireguard/privateerr.env
```

`privateerr.env` carries `PIA_WG_SERVER_NAME`. The wrapper turns that into Gluetun's `SERVER_NAMES` value so PIA port forwarding requests the matching server.

The wrapper script also lives here:

```text
config/gluetun/scripts/gluetun-entrypoint-wrapper.sh
```

The wrapper waits for `privateerr.env`, exports `PIA_WG_SERVER_NAME` as `SERVER_NAMES`, and then hands control to Gluetun's original entrypoint.

> [!IMPORTANT]
> Runtime files such as `forwarded_port`, `ip`, `piaportforward.json`, and Gluetun's server cache are ignored by Git. Treat the whole directory as sensitive state.
