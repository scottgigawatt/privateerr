# Shared Gluetun configuration 🧭

Privateerr and Gluetun mount this complete directory. Privateerr creates/reuses the matching `wireguard/wg0.conf` and `wireguard/privateerr.env`; recovery replaces them only after API and tunnel-health confirmation.

The wrapper exports metadata's `PIA_WG_SERVER_NAME` as Gluetun's `SERVER_NAMES`. Privateerr installs `scripts/gluetun-entrypoint-wrapper.sh` and `scripts/qbittorrent-port-forwarding.sh` before readiness, replacing those managed filenames at startup. Keep custom scripts under other names.

Mount the directory rather than individual files. Container UID 0 needs write/traverse access for installation, staging, and replacement; a read/write mount cannot override host permissions. Valid saved files can permit startup despite a recovery-storage warning. See [storage diagnostics](../../docs/automatic-recovery.md#read-diagnostics-and-check-storage).

> [!IMPORTANT]
> Treat this directory as sensitive state. Preserve `.privateerr-pending` and `.privateerr-commit` during recovery; they retain candidates and interrupted saves. Runtime caches, leases, and generated scripts stay ignored by Git.
