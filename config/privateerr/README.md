# Privateerr configuration 🏴‍☠️

Privateerr writes runtime logs to this directory while the official PIA scripts generate a WireGuard connection.

```text
config/privateerr/logs/privateerr.log
```

The log is ignored by Git because it can contain live connection details. The generated WireGuard files land in Gluetun's shared directory:

```text
config/gluetun/wireguard/wg0.conf
config/gluetun/wireguard/privateerr.env
```

> [!CAUTION]
> Live `wg0.conf` and `privateerr.env` can contain sensitive connection details. Run `make restore-test-config` before committing.
