# Privateerr Script Hold 🏴‍☠️

These documented host helpers support the Privateerr Compose project. Pick the
smallest tool for the job and review its header before running it against a live
deployment.

## Script Chart 🧭

| Hold       | Script                                                                                                                               | Purpose                                                            |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| 🐳 Compose | [`compose/check-pia-credentials.sh`](https://github.com/scottgigawatt/privateerr/blob/main/scripts/compose/check-pia-credentials.sh) | Report missing or example PIA credentials before Privateerr starts |
| 🐳 Compose | [`compose/ps.sh`](https://github.com/scottgigawatt/privateerr/blob/main/scripts/compose/ps.sh)                                       | Print a compact status table for the Privateerr Compose project    |

## Compose Helpers 🐳

### `compose/check-pia-credentials.sh`

Reads resolved Compose environment values from standard input and fails when a
Privateerr deployment would start without real `PIA_USER` and `PIA_PASS`
values. Invalid credentials produce a color-aware diagnostic with a corrective
action; redirected output remains plain text and `NO_COLOR` disables terminal
color. `make run-privateerr`, `make up`, and `make test-e2e` call it
automatically.

### `compose/ps.sh`

Resolves the Privateerr Compose project and prints only its containers in a
terminal-friendly status table. Equivalent IPv4 and IPv6 wildcard bindings are
collapsed, and each distinct published port receives an aligned continuation
line. `make ps` is the normal entry point.

> [!TIP]
>
> ```sh
> make run-privateerr
> make ps
> make test-make-helpers
> ```

> [!IMPORTANT]
> Keep credentials in the ignored `.env` file. Do not pass them as command-line
> arguments, paste them into issues, or commit generated WireGuard state.
