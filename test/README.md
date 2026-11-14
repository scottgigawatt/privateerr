# Privateerr tests 🧪

Buccaneerr contains Privateerr's test tooling. Normal `make up` uses the published-image base Compose file; `make up-build` adds the Privateerr build overlay. Both start only Privateerr, Gluetun, and qBittorrent.

The complete live validator belongs to `docker-compose.test.yml`, which builds `buccaneerr:local` with `pull_policy: build`. Including that file selects the validator without a profile. Base plus test validates published Privateerr; `make test-e2e` includes all three Compose files to validate `privateerr:local`. Keep the same `.env` and project name. Follow [Compose file selection](../docs/advanced-usage.md#choose-compose-files-for-development) before selecting a live test.

## Find the right check

Use the [developer testing guide](../docs/development/privateerr/testing.md) for commands, prerequisites, coverage, and limits. It is the canonical test procedure.

| Path | Purpose |
| --- | --- |
| `policy/` | Dependency, image-tag, executable-mode, and spelling checks |
| `helpers/` | Isolated Make, Compose, and workflow fixtures |
| `unit/` | Python generation, recovery, publication, and diagnostics tests |
| `runtime/` | Opt-in Docker API, live VPN, and cleanup acceptance tests |
| `stubs/` | Deterministic Docker and registry stand-ins |
| `examples/` | Checked-in WireGuard and metadata files for disposable-test restoration |
| `Dockerfile` | Buccaneerr tools and the optional documentation target |
| `checks.sh` | Shared suite selection for Make and workflows |

The production image does not include these test dependencies. The restricted repository-root build context admits only test sources and the documentation lockfile.

## Test automatic recovery

Credential-free checks and live checks prove different things. Start with the [test selection guide](../docs/development/privateerr/testing.md#run-offline-checks); use real Docker or PIA tests only when the changed behavior needs them.

> [!CAUTION]
> Live tests use PIA credentials, replace VPN files, and deliberately interrupt a test endpoint. Use a disposable checkout and save any VPN configuration files you need before testing. Never run test-example restoration against an active deployment.

After the complete example test, follow [safe shutdown and example restoration](../docs/advanced-usage.md#restore-vpn-examples). Keep real credentials, generated VPN state, and private logs out of commits.
