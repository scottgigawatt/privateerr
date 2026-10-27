---
icon: material/compass-outline
---

# Supervisor developer overview 🧭

Privateerr's standard-library Python program coordinates PIA configuration generation and sustained-outage recovery. It runs in the existing Privateerr container, outside Gluetun's network namespace, so it can still reach PIA when the tunnel fails.

## Understand the responsibilities

| Component | Responsibility | Source |
| :--- | :--- | :--- |
| Configuration | Validate environment settings and generation/recovery modes | `docker/privateerr/config.py` |
| HTTP client | Bound authenticated control requests, health probes, and catalog downloads | `docker/privateerr/client.py` |
| JSON validation | Narrow external values before inspecting their fields | `docker/privateerr/data.py` |
| Connection settings | Validate matching generated files and finish interrupted publication | `docker/privateerr/settings.py` |
| Filesystem diagnostics | Probe storage and explain failures without exposing configuration contents | `docker/privateerr/diagnostics.py` |
| Supervisor | Select endpoints, manage generation, and reconcile recovery state | `docker/privateerr/supervisor.py` |
| Generator | Invoke upstream PIA scripts, bound their output, and prepare matching metadata | `docker/privateerr/generation.py` |
| Logging | Format UTC records and redact upstream credentials before output | `docker/privateerr/log.py` |
| Script installer | Install image-owned Gluetun scripts before startup readiness | `docker/privateerr/scripts.py` |
| Gluetun wrapper | Load saved metadata and configure the existing API and health listener | `docker/gluetun/gluetun-entrypoint-wrapper.sh` |
| Forwarding hook | Synchronize qBittorrent with Gluetun's port lease | `docker/gluetun/qbittorrent-port-forwarding.sh` |

The Python package starts through `python3 -m privateerr`. The image starts that command directly; `supervisor.main()` validates configuration, protects new files, installs shutdown handlers, and starts the supervisor. The [Python reference](reference/index.md) documents the source contracts.

## Keep the integration small

Keep upstream PIA scripts and Gluetun-local hooks in shell. Privateerr and Buccaneerr start their Python programs directly. Recovery state, deadlines, response validation, and candidate reconciliation belong in Python. Do not add a production web server, package dependency, Docker socket, or container lifecycle controller to solve a problem already handled through Gluetun's existing API.

The production image retains UID 0 for upstream scripts while the example drops all Linux capabilities and enables `no-new-privileges`. Read [container hardening](../../automatic-recovery.md#run-without-privileged-mode) before changing generation or namespace configuration.

## Understand startup modes

The supplied Compose example enables recovery. Image-only deployments that omit `PRIVATEERR_AUTO_RECOVER` retain generation and keepalive behavior. Recovery validates its additional settings only when enabled. One-shot generation still exits after producing matching files when keepalive and recovery are disabled.

Keep environment contracts, file paths, and port-forwarding ownership stable. Follow the [architecture](architecture.md) before changing startup or persistence, and run the [relevant validation](testing.md) before updating a pull request.
