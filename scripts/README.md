# Privateerr Host Helpers 🧰🏴‍☠️

The `scripts/` hold contains small host-side helpers used by Make. They stay
outside the production Privateerr image and the upstream PIA submodule.

## Compose helpers

| Helper | Purpose |
| --- | --- |
| `compose/check-pia-credentials.sh` | Reject missing or documented example PIA credentials before Privateerr starts. |
| `compose/ps.sh` | Ask Docker Compose for the selected project and render a compact status table. |

The credential helper reads Docker Compose's resolved environment from standard
input. It retains only `PIA_USER` and `PIA_PASS` in memory, never sources `.env`,
and never prints their values.

Use the Make interface instead of calling the helpers directly:

```sh
make run-privateerr
make ps
make test-make-helpers
```

> [!IMPORTANT]
> Keep credentials in the ignored `.env` file. Do not pass them as command-line
> arguments, paste them into issues, or commit generated WireGuard state.
