# Supervisor developer overview 🧭

Privateerr's standard-library Python program coordinates PIA configuration generation and sustained-outage recovery. It runs in the existing Privateerr container, outside Gluetun's network namespace, so it can still reach PIA when the tunnel fails.

## Understand the responsibilities

| Component | Responsibility | Source |
| :--- | :--- | :--- |
| Configuration | Validate environment settings while retaining image-only compatibility defaults | `docker/privateerr/config.py` |
| HTTP client | Bound authenticated control requests, health probes, and catalog downloads | `docker/privateerr/client.py` |
| JSON validation | Narrow external values before inspecting their fields | `docker/privateerr/data.py` |
| Connection settings | Validate matching generated files and finish interrupted publication | `docker/privateerr/settings.py` |
| Supervisor | Select endpoints, manage generation, and reconcile recovery state | `docker/privateerr/supervisor.py` |
| Generation adapter | Invoke upstream PIA scripts and collect their generated metadata | `docker/privateerr-generate.sh` |
| Gluetun wrapper | Load saved metadata and configure the existing API and health listener | `config/gluetun/scripts/gluetun-entrypoint-wrapper.sh` |

The Python package starts through `python3 -m privateerr`. The shell entrypoint supplies that command; `supervisor.main()` validates configuration, protects new files, installs shutdown handlers, and starts the supervisor. The [Python reference](reference/index.md) documents the source contracts.

## Keep the integration small

Keep shell at the upstream and container-startup boundaries. Recovery state, deadlines, response validation, and candidate reconciliation belong in Python. Do not add a production web server, package dependency, Docker socket, or container lifecycle controller to solve a problem already handled through Gluetun's existing API.

The production image retains UID 0 for upstream scripts while the example drops all Linux capabilities and enables `no-new-privileges`. Read [container hardening](../../automatic-recovery.md#run-without-privileged-mode) before changing generation or namespace configuration.

## Preserve existing deployments

The supplied Compose example enables recovery. Image-only deployments that omit `PRIVATEERR_AUTO_RECOVER` retain generation and keepalive behavior. Recovery validates its additional settings only when enabled. One-shot generation still exits after producing matching files when keepalive and recovery are disabled.

Keep environment contracts, file paths, and port-forwarding ownership stable. Follow the [architecture](architecture.md) before changing startup or persistence, and run the [relevant validation](testing.md) before updating a pull request.
