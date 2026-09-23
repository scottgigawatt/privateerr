# Test Privateerr 🧪

Choose the smallest check that proves the changed boundary, then broaden for generation, networking, image, workflow, or documentation changes. Test and documentation tools run inside Buccaneerr; the host needs Docker and Make.

## Run offline checks

```sh
make test
make test-types
make test-precommit
make spellcheck
```

`make test` runs Ruff lint and formatting, strict Pyright, ShellCheck, helper and workflow tests, and Python unit tests. `make test-types` is also enforced by pre-commit and pull-request validation. Compose tests check the complete service graph and verify that Web UI port changes keep the host mapping, internal listener, healthcheck, and API clients synchronized.

Python tests exercise environment validation, endpoint selection, bounded HTTP behavior, candidate publication, recovery timing, uncertain updates, and shutdown. They use controlled clocks and temporary state rather than real credentials.

## Check the integration

```sh
make test-recovery-api
```

This suite runs the real Gluetun API and qBittorrent in isolated, labeled containers with disposable state. It checks authentication, settings updates, application port synchronization, and shutdown without needing PIA credentials.

For a real account and incoming-port validation, configure the ignored local `.env`, then run:

```sh
make test-recovery-live
```

The live suite verifies VPN egress, matching saved settings, recovery after a deliberate endpoint outage, qBittorrent preferences, and incoming TCP through the PIA lease. It does not measure torrent throughput or claim UDP reachability. Never publish credentials, generated WireGuard files, or application logs.

## Validate the complete example

```sh
make test-e2e
make clean-test
```

The example starts Privateerr, Gluetun, qBittorrent, and Buccaneerr. Its default test deliberately interrupts the active endpoint to exercise automatic recovery. `make clean-test` stops the example and restores checked-in VPN examples; preserve any configuration you need before running a live test.

## Build the images

```sh
make build
make build-buccaneerr
make build-platforms
```

Published Privateerr and Buccaneerr images support amd64, arm64, and arm/v7. The LinuxServer qBittorrent example supports amd64 and arm64. Documentation tooling is an optional Buccaneerr build target used on development hosts and GitHub's amd64 runner, not part of the published runtime images.

## Validate documentation

```sh
make docs
make docs-serve
```

Both targets build the cached `docs` target in `test/Dockerfile`, installing exact, SHA-256-verified dependencies from `requirements-docs.txt` into its isolated Python environment. No host Python installation is required. Source is mounted read-only; `make docs` writes the ignored `site/` directory with the host user's ownership and builds without network access.

The preview listens at `http://127.0.0.1:8000`. Set `DOCS_SERVE_ADDRESS=127.0.0.1:8001` if that host port is occupied. Stop the preview with Ctrl+C. Neither command starts the VPN stack or receives a Docker socket inside the documentation container.

PR validation performs the same strict documentation build without write permissions. The Pages workflow builds a fresh artifact from `main` or a release tag whose commit belongs to `main`, then deploys it in a separate job. Generated HTML stays out of Git.
