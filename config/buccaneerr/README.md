# Buccaneerr configuration 🔎

Buccaneerr is the test-only deckhand that validates the running tunnel and writes its log here:

Buccaneerr writes validation logs here:

```text
config/buccaneerr/logs/buccaneerr.log
```

The log is ignored by Git because it may contain fresh connection details.

Buccaneerr checks:

- Privateerr wrote `wg0.conf`.
- Privateerr wrote `privateerr.env`.
- Gluetun reports healthy.
- PIA port forwarding returns a proper port.

If the voyage sinks, inspect this log first; it usually points to the failed handoff.
