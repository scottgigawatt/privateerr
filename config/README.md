# Privateerr configuration ⚓

This directory holds persistent and generated state for the local Privateerr, Gluetun, and Buccaneerr Compose services. Each subdirectory documents its owner and retention rules.

Privateerr generates or reuses these matching shared files at startup. During automatic recovery it publishes a replacement only after Gluetun confirms the applied settings and tunnel health:

```text
config/gluetun/wireguard/wg0.conf
config/gluetun/wireguard/privateerr.env
```

The checked-in files contain example data. `privateerr.env` supplies `PIA_WG_SERVER_NAME`; the Gluetun wrapper exports that value as `SERVER_NAMES` before it starts Gluetun.

Use `make run-privateerr` to generate fresh files only after stopping any supervisor that owns this directory. `make test-e2e` validates the complete voyage with live PIA credentials in a disposable checkout. Before committing from that test checkout, stop its services and follow [safe example restoration](../docs/advanced-usage.md#restore-vpn-examples); never replace an active deployment's files with examples.

> [!WARNING]
> Live WireGuard configuration, port-forwarding metadata, and logs can expose VPN details. Keep them out of Git and redact them from issues or chat.
