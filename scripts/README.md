# Privateerr scripts 🏴‍☠️

Use Make as the normal interface to these host helpers. Read a script's header before invoking it directly.

| Helper | Purpose |
| --- | --- |
| [`awk/collect-dockerfile-base-images.awk`](awk/collect-dockerfile-base-images.awk) | Resolve declared base images for scoped cleanup; skip unresolved references |
| [`awk/format-compose-status.awk`](awk/format-compose-status.awk) | Format status and collapse duplicate IPv4/IPv6 port bindings |
| [`awk/order-environment.awk`](awk/order-environment.awk) | Match resolved environment ordering to `example.env` |
| [`awk/strip-comments.awk`](awk/strip-comments.awk) | Produce uncommented configuration views |
| [`compose/backup.sh`](compose/backup.sh) | Archive config without replacing earlier backups |
| [`compose/check-pia-credentials.sh`](compose/check-pia-credentials.sh) | Reject missing/example credentials without sourcing `.env` or printing values |
| [`compose/nuke.sh`](compose/nuke.sh) | Validate and remove resources owned by one selected project |
| [`compose/ps.sh`](compose/ps.sh) | Show project status |
| [`docs/build.sh`](docs/build.sh) | Build/preview documentation with read-only source and locked tools |
| [`compose/test.sh`](compose/test.sh) | Run named suites in Buccaneerr |

## Respect operational boundaries

Backups can contain secrets and are not application-consistent while writers run. Preserve `.env` and Docker-managed volumes separately. See [maintenance and backup limits](../docs/advanced-usage.md#maintenance-reference).

The cleanup helper never deletes repository files. Make owns transient-state reset and example restoration after scoped Docker cleanup. Shared or in-use base images are retained. Read the [destructive-reset warning](../docs/advanced-usage.md#clean-developer-artifacts) before choosing a cleanup target.

Keep credentials in the ignored `.env` file. Do not pass their literal values on command lines or paste resolved configuration into support reports.

Use the [testing guide](../docs/development/privateerr/testing.md) for isolated helper checks; the [recovery guide](../docs/automatic-recovery.md) covers live diagnostics.
