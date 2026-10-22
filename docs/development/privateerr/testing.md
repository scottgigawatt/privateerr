# Test Privateerr 🧪

Choose the smallest check that proves the changed boundary, then broaden for generation, networking, image, workflow, or documentation changes. Test and documentation tools run inside Buccaneerr; the host needs Docker and Make.

## Run offline checks

```sh
make test
make test-types
make spellcheck
```

`make test` runs Ruff lint and formatting, strict Pyright, ShellCheck, helper and workflow tests, and Python unit tests. `make test-types` is also enforced by pre-commit and pull-request validation. Compose tests check the complete service graph and verify that Web UI port changes keep the host mapping, internal listener, healthcheck, and API clients synchronized.

Python tests exercise environment validation, endpoint selection, bounded HTTP behavior, candidate publication, recovery timing, uncertain updates, and shutdown. They use controlled clocks and temporary state rather than real credentials. Filesystem regressions cover readable saved files with blocked writes, first-generation failure, failed publication after API acceptance, probe cleanup, safe region summaries, and credential-free error diagnostics. A Linux root-only test drops all capabilities in a disposable child process and verifies that UID 0 cannot write another user's directory; the parent retains cleanup access.

## Run repository hooks

Pre-commit can download pinned hook environments, modify the checkout, and access the local Docker socket for nested checks; inspect its diff afterward. Run it separately from the offline, read-only suites:

```sh
make test-precommit
```

The offline suites above run with networking disabled and read-only source after their tool image is built; that initial image build can still download dependencies.

## Check the integration

The credential-free runtime suite requires a local Unix Docker socket and a built Privateerr test image. Initialize the pinned PIA submodule before building; the [contributor setup](../../CONTRIBUTING.md#development-checkout) uses a recursive clone. Build the image explicitly, then name that same image when running the suite:

```sh
docker build --tag privateerr:recovery-review --file docker/Dockerfile docker
PRIVATEERR_TEST_IMAGE=privateerr:recovery-review make test-recovery-api
```

This suite runs the real Gluetun API and qBittorrent in isolated, labeled containers with disposable state. It checks authentication, settings updates, application port synchronization, and shutdown without needing PIA credentials.

The live suite needs real PIA credentials in the ignored local `.env` and deliberately interrupts its test endpoint. Use a disposable checkout and protect any needed configuration before running it:

```sh
make test-recovery-live
```

The live suite verifies VPN egress, matching saved settings, recovery after a deliberate endpoint outage, qBittorrent preferences, and incoming TCP through the PIA lease. It does not measure torrent throughput or claim UDP reachability. Never publish credentials, generated WireGuard files, or application logs.

## Validate the complete example

This test needs real PIA credentials and deliberately interrupts the active endpoint. Use a disposable checkout and preserve any configuration you need before starting:

```sh
make test-e2e
```

The example starts Privateerr, Gluetun, qBittorrent, and Buccaneerr. After the voyage, [stop the test stack and restore example files sequentially](../../advanced-usage.md#restore-vpn-examples). Do not overwrite an active deployment's VPN files or run `make clean-test` with parallel Make execution.

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
