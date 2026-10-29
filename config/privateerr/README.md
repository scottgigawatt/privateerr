# Privateerr logs 🏴‍☠️

The supervisor writes `logs/privateerr.log` here. Container UID 0 needs write access; persistent-log open failures appear in container output.

Logs include failure categories, retry delays, and region preferences. Redaction is best effort: inspect and sanitize excerpts before sharing. Logs are ignored by Git. See [diagnostics](../../docs/automatic-recovery.md#read-diagnostics-and-check-storage).

Generated VPN files belong to the [shared Gluetun directory](../gluetun/README.md), not this log directory.
