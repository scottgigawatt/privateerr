# Privateerr configuration 🏴‍☠️

Privateerr writes supervisor and redacted upstream-generation logs to this directory. With recovery enabled, logs continue while the supervisor monitors Gluetun. This directory must be writable by the container's UID 0; a failure to open the persistent log is reported in container output.

```text
config/privateerr/logs/privateerr.log
```

The log is ignored by Git because it can contain live connection details. Supervisor messages include severity, filesystem/API failure categories, retry delays, and selected VPN region labels. Region labels describe configured destinations, not the operator's location; review logs before sharing. See [diagnostics and storage checks](../../docs/automatic-recovery.md#read-diagnostics-and-check-storage). The generated WireGuard files land in Gluetun's shared directory:

```text
config/gluetun/wireguard/wg0.conf
config/gluetun/wireguard/privateerr.env
```

> [!CAUTION]
> Live `wg0.conf` and `privateerr.env` can contain sensitive connection details. Run `make restore-test-config` before committing.
