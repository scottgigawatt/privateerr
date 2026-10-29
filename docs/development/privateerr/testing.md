# Test Privateerr 🧪

Choose the smallest check that proves the changed behavior. The host needs Docker and Make; Buccaneerr provides the pinned tools. Image and hook preparation can download dependencies. No live VPN is needed for prose or Markdown changes.

## Run offline checks

```sh
make test
make spellcheck
```

`make test` runs Ruff lint/format checks, strict Pyright, ShellCheck, helper/workflow policies, and Python units without PIA credentials or application startup. `make test-types`, `make test-recovery`, `make test-make-helpers`, and `make test-workflows` select narrower suites.

After building the tool image, these suites use networking-disabled containers and read-only source. Fixtures test generation deadlines and output, script installation, safe diagnostics/redaction, endpoint selection, timing, uncertain API updates, interrupted publication, and shutdown. Compose fixtures check the service graph and synchronized qBittorrent ports. They do not prove a live tunnel works.

For Python changes, use `make lint`; `make format` intentionally applies Ruff import/format fixes. The root Ruff and strict Pyright configurations also drive editors and CI.

## Run repository hooks

Pre-commit can download hook environments, modify files, and use the local Docker socket for nested checks. Inspect its resulting diff:

```sh
make test-precommit
```

## Check the integration

The credential-free runtime suite needs a local Unix Docker socket and a built Privateerr image. Initialize the pinned PIA submodule using the [contributor setup](../../CONTRIBUTING.md#development-checkout), then build and select the same image:

```sh
docker build --tag privateerr:recovery-review --file docker/Dockerfile docker
PRIVATEERR_TEST_IMAGE=privateerr:recovery-review make test-recovery-api
```

The suite runs Buccaneerr with Docker socket access and starts real Gluetun v3.41.3 and qBittorrent in uniquely named, labeled containers. Synthetic VPN files and an empty scripts directory verify image-owned script installation before readiness, authentication, connection-field updates, unrelated-setting preservation, invalid-update rejection, application port/interface synchronization, and unchanged network/container identity. It cleans up only its verified resources and does not establish a PIA tunnel.

Ordinary offline suites have no Docker socket. Runtime suites require a shared temporary directory visible to their driver and Docker daemon.

## Run live recovery checks

> [!CAUTION]
> Live checks use real PIA credentials and deliberately interrupt a test endpoint. Use a disposable checkout, protect needed configuration first, and keep generated files and logs private.

```sh
make test-recovery-live
```

This isolated suite reads the required credentials from Compose's resolved `.env`, retains the supplied environment file, and cleans up its labeled resources on exit. It verifies VPN egress, endpoint-failure recovery, matching saved settings, qBittorrent preferences, dependent-client connectivity, traffic blocking outside the VPN, and incoming TCP through the PIA lease. It does not measure UDP reachability or torrent throughput.

Normal recovery runs with capabilities dropped, Docker-applied IPv6 settings, and `no-new-privileges`. The separate `scripts/compose/test.sh smoke` suite checks recovery-disabled generation using a disposable privileged compatibility fixture; that fixture is not a deployment recommendation.

Use `PRIVATEERR_TEST_IMAGE` to select another built image or `PRIVATEERR_TEST_ENV_FILE` for another credential file.

## Validate the complete example

The same live-test warning applies: this starts the selected Compose project, replaces VPN files, and deliberately interrupts its endpoint. Preserve needed state and use a disposable checkout:

```sh
make test-e2e
```

It enables the `test` profile and starts Privateerr, Gluetun, qBittorrent, and Buccaneerr. The validator removes its temporary firewall rule on completion or failure. `BUCCANEERR_TEST_RECOVERY=false` selects connectivity-only validation; the default recovery deadline is 600 seconds.

Afterward, [stop the test stack and restore examples](../../advanced-usage.md#restore-vpn-examples). `make clean-test` waits for successful shutdown before replacing files. Never restore examples against an active deployment.

## Check lifecycle ownership

After changing cleanup behavior, run `test/runtime/test-compose-cleanup-live.sh` only with authorization to create disposable Docker resources. It creates unique projects and unrelated sentinels, proving that `down` retains volumes/images and `nuke` removes only its owned resources and builder. It does not use repository credentials, config, or backups.

## Build the images

```sh
make build
make build-buccaneerr
make build-platforms
```

These build images without starting the application stack. Privateerr and Buccaneerr support amd64, arm64, and arm/v7; qBittorrent supports amd64 and arm64. The [test tree](https://github.com/scottgigawatt/privateerr/blob/main/test/README.md) maps source locations.

## Validate documentation

```sh
scripts/compose/test.sh markdown
make spellcheck
make test-precommit
make docs
git diff --check
```

The docs target installs exact, SHA-256-verified dependencies in Buccaneerr's optional `docs` target. It mounts source read-only, builds without network access using `mkdocs build --strict`, and writes ignored `site/` output as the host user. It does not start the VPN stack or receive a Docker socket.

Use `make docs-serve` for preview at `http://127.0.0.1:8000`; override `DOCS_SERVE_ADDRESS=127.0.0.1:8001` for a port conflict. Stop with Ctrl+C. Inspect changed GitHub and Material rendering, links, anchors, tables, alerts, diagrams, and narrow layouts. Lint and strict compilation do not establish external-link validity or reader usability.

PR documentation builds are read-only. Pages deploys separately from `main` or an eligible release tag; this validation does not authorize deployment.
