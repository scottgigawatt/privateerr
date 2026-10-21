# Buccaneerr configuration 🔎

Buccaneerr is the test-only deckhand that validates the tunnel and application handoff, then writes its log here:

```text
config/buccaneerr/logs/buccaneerr.log
```

The log is ignored by Git because it may contain fresh connection details.

Buccaneerr checks the matching configuration pair, VPN egress, Gluetun port forwarding, and qBittorrent's actual port and interface settings. With recovery testing enabled, it deliberately interrupts the active endpoint and verifies recovery while containers retain their identity. See the [canonical test coverage and limits](../../test/README.md#test-automatic-recovery) before running the live example.

If the voyage sinks, inspect this log first; it usually points to the failed handoff.
