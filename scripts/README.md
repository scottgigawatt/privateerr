# Privateerr Script Hold 🏴‍☠️

These documented AWK programs and host helpers support the Privateerr Compose
project. Pick the smallest tool for the job and review its header before running
it against a live deployment.

## Script Chart 🧭

| Hold       | Script                                                                                                                               | Purpose                                                            |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| 🧮 AWK     | [`awk/collect-dockerfile-base-images.awk`](https://github.com/scottgigawatt/privateerr/blob/main/scripts/awk/collect-dockerfile-base-images.awk) | Resolve Dockerfile build arguments into base image references      |
| 🧮 AWK     | [`awk/format-compose-status.awk`](https://github.com/scottgigawatt/privateerr/blob/main/scripts/awk/format-compose-status.awk)       | Align Compose status rows and stack distinct published ports       |
| 🧮 AWK     | [`awk/order-environment.awk`](https://github.com/scottgigawatt/privateerr/blob/main/scripts/awk/order-environment.awk)               | Order resolved values like the checked-in environment file         |
| 🧮 AWK     | [`awk/strip-comments.awk`](https://github.com/scottgigawatt/privateerr/blob/main/scripts/awk/strip-comments.awk)                     | Remove comments and blank lines from raw configuration output      |
| 🐳 Compose | [`compose/backup.sh`](https://github.com/scottgigawatt/privateerr/blob/main/scripts/compose/backup.sh)                               | Archive Privateerr config without replacing an existing backup     |
| 🐳 Compose | [`compose/check-pia-credentials.sh`](https://github.com/scottgigawatt/privateerr/blob/main/scripts/compose/check-pia-credentials.sh) | Report missing or example PIA credentials before Privateerr starts |
| 🐳 Compose | [`compose/nuke.sh`](https://github.com/scottgigawatt/privateerr/blob/main/scripts/compose/nuke.sh)                               | Remove resources owned by one explicit Compose project             |
| 🐳 Compose | [`compose/ps.sh`](https://github.com/scottgigawatt/privateerr/blob/main/scripts/compose/ps.sh)                                       | Print a compact status table for the Privateerr Compose project    |

## AWK Programs 🧮

### `awk/collect-dockerfile-base-images.awk`

Records global Dockerfile `ARG` defaults, resolves `${NAME}` and `$NAME` in
`FROM`, ignores internal stages and `scratch`, and resets state between input
files. Unresolved references are skipped instead of being passed to Docker.
The nuke helper uses its unique output for best-effort declared-base cleanup.

### `awk/format-compose-status.awk`

Formats tab-separated `docker compose ps` data into aligned terminal columns,
collapses equivalent IPv4 and IPv6 wildcard bindings, and places each distinct
published port on its own continuation row. `compose/ps.sh` invokes it.

### `awk/order-environment.awk`

Prints resolved Docker Compose environment assignments in the same order as
`example.env`. `make env` invokes it through the centralized AWK variables.

### `awk/strip-comments.awk`

Removes comments, trailing whitespace, and empty lines. `make print-config` and
`make print-env` share it so both raw views follow one filtering contract.

## Compose Helpers 🐳

### `compose/backup.sh`

Archives the complete `config/` directory with a timestamped filename. An
incrementing suffix prevents a same-second backup from replacing an existing
archive. `make backup` is the normal entry point, and `backups/` stays ignored.

### `compose/check-pia-credentials.sh`

Reads resolved Compose environment values from standard input and fails when a
Privateerr deployment would start without real `PIA_USER` and `PIA_PASS`
values. Invalid credentials produce a color-aware diagnostic with a corrective
action; redirected output remains plain text and `NO_COLOR` disables terminal
color. `make run-privateerr`, `make up`, and `make test-e2e` call it
automatically.

### `compose/nuke.sh`

Validates the selected Compose model before deleting anything, captures service
images, runs project-scoped teardown with volumes, orphans, and service images,
then removes explicitly supplied local image references and one named Buildx
builder. Repeated `--dockerfile` and `--additional-image` arguments avoid shell
command evaluation. Declared base images are removed without force, so shared or
in-use references are retained with a warning. Missing resources are harmless;
unexpected Compose, Docker, or builder failures stop the helper.

The helper never deletes repository files, `.env`, config, or backups. Make
owns the later repository cleanup, transient-state reset, and example restore.

### `compose/ps.sh`

Resolves the Privateerr Compose project and prints only its containers in a
terminal-friendly status table. Equivalent IPv4 and IPv6 wildcard bindings are
collapsed, and each distinct published port receives an aligned continuation
line. `make ps` is the normal entry point.

```sh
make backup
make run-privateerr
make ps
make test-make-helpers
```

> [!IMPORTANT]
>
> Keep credentials in the ignored `.env` file. Do not pass them as command-line
> arguments, paste them into issues, or commit generated WireGuard state.
