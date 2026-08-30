# Privateerr configuration ⚓

This directory holds persistent and generated state for the local Privateerr, Gluetun, and Buccaneerr Compose services. Each subdirectory documents its owner and retention rules.

Privateerr replaces these shared files whenever it generates a connection:

```text
config/gluetun/wireguard/wg0.conf
config/gluetun/wireguard/privateerr.env
```

The checked-in files contain example data. `privateerr.env` supplies `PIA_WG_SERVER_NAME`; the Gluetun wrapper exports that value as `SERVER_NAMES` before it starts Gluetun.

Use `make run-privateerr` to generate fresh files, `make test-e2e` to validate the complete voyage, and `make restore-test-config` before committing.

> [!WARNING]
> Live WireGuard configuration, port-forwarding metadata, and logs can expose VPN details. Keep them out of Git and redact them from issues or chat.
