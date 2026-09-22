# Buccaneerr test hold 🧪🏴‍☠️

Welcome to the test hold, where Buccaneerr climbs aboard after Privateerr and Gluetun to make sure the whole WireGuard voyage did not spring a leak. ☠️

The test tree keeps responsibilities separate:

- `policy/` verifies repository-wide dependency and image-tag rules.
- `helpers/` exercises Make and workflow helpers without external writes.
- `unit/` tests Python recovery decisions, HTTP behavior, persistence, and generation lifecycle.
- `runtime/` performs opt-in acceptance checks against isolated Docker resources.
- `stubs/` supplies deterministic Docker and Skopeo stand-ins for those tests.
- `examples/` stores the checked-in WireGuard and metadata examples restored after a live voyage.
- the test-root `Dockerfile` and `buccaneerr-entrypoint.sh` remain the Buccaneerr build context.

## Find a test script 🗺️

| Hold       | Script                                                                   | Purpose                                                            |
| ---------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| 🛡️ Policy | [`policy/check-build-pin-policy.sh`](policy/check-build-pin-policy.sh)   | Keep digest-pinned build dependency tags synchronized               |
| 🛡️ Policy | [`policy/check-image-tag-policy.sh`](policy/check-image-tag-policy.sh)   | Enforce canonical image tags in every metadata-action block         |
| 🧮 Policy | [`policy/awk/check-image-tags.awk`](policy/awk/check-image-tags.awk)     | Parse and validate workflow image-tag metadata blocks               |
| 🧮 Policy | [`policy/awk/collect-build-pins.awk`](policy/awk/collect-build-pins.awk) | Extract and validate digest-pinned build dependency values          |
| 🧰 Helpers | [`helpers/test-make-helpers.sh`](helpers/test-make-helpers.sh)           | Test AWK, backup, credential, and Compose helpers offline           |
| 🧰 Helpers | [`helpers/test-policy-checks.sh`](helpers/test-policy-checks.sh)         | Test valid and invalid publishing-policy fixtures offline           |
| 🧰 Helpers | [`helpers/test-workflow-helpers.sh`](helpers/test-workflow-helpers.sh)   | Test release, Discord, and registry helper behavior offline         |
| 🌊 Runtime | [`runtime/test-compose-cleanup-live.sh`](runtime/test-compose-cleanup-live.sh) | Verify isolated `down` and `nuke` ownership on a real Docker daemon |
| 🎭 Stubs   | [`stubs/compose-docker-stub.sh`](stubs/compose-docker-stub.sh)           | Supply deterministic Docker output to Compose helper tests          |
| 🎭 Stubs   | [`stubs/workflow-skopeo-stub.sh`](stubs/workflow-skopeo-stub.sh)         | Simulate registry inspection without network access                 |

The subfolders separate static repository policy, reusable helper tests, deterministic command stubs, and checked-in reset examples. Make targets remain the public interface; invoke individual scripts only while diagnosing a focused failure.

## Run offline policy and helper checks 🧭

```sh
make test
make test-make-helpers
make test-workflows
```

These targets build the cached Buccaneerr image and run inside it, with source mounted read-only and networking disabled. No host Python, jq, Ruff, or ShellCheck installation is needed. `make test` also checks Python imports and formatting, ShellCheck, and the Python unit suite.

The complete local target checks reusable AWK and Compose helpers, config backups, release tags, every structured Discord profile, registry mirroring, synchronized SHA-256 build pins, and canonical image-tag channels. Disposable negative fixtures prove that mismatched pins and unsafe tag rules are rejected.

Run the opt-in live cleanup acceptance after changing Compose lifecycle or `nuke` behavior:

```sh
test/runtime/test-compose-cleanup-live.sh
```

It creates uniquely named disposable projects and unrelated sentinels on the real Docker daemon. The test proves `down` preserves volumes and images, then proves `nuke` removes only its project resources and named builder. It never uses the repository `.env`, config, backups, or PIA credentials.

## Understand Buccaneerr 🦜

Buccaneerr is the test-only image for this repo. It does not ship with the production Privateerr image, and it does not generate WireGuard config. Instead, it joins the running test stack after Privateerr has written its files and Gluetun has raised the VPN sails.

Buccaneerr checks the important loot:

- Gluetun is reachable.
- WireGuard traffic is alive.
- PIA port forwarding produced a usable forwarded port.
- The stack behaves like the downstream Synology-friendly Compose setup.

Buccaneerr keeps its verification scripts and additional test tools in a separate image. Privateerr retains the tools required by upstream PIA scripts and recovery, including `curl`.

## Build and run Buccaneerr 🛠️

The image is built from [Dockerfile](Dockerfile), using the same pinned Alpine base digest as Privateerr. Its default command runs [buccaneerr-entrypoint.sh](buccaneerr-entrypoint.sh) for stack validation. Make uses [checks.sh](checks.sh) for Python, shell, workflow, formatting, and spelling checks in the same image.

Build it directly with:

```sh
make build-buccaneerr
```

Run the full end-to-end voyage with:

```sh
make test-e2e
```

> [!WARNING]
> The end-to-end voyage uses real PIA credentials from `.env`. Do not commit live credentials, generated VPN configuration, or logs.

## Follow the end-to-end voyage 🧭

The Compose stack starts Privateerr first. Privateerr writes:

- `config/gluetun/wireguard/wg0.conf`
- `config/gluetun/wireguard/privateerr.env`

Then Gluetun uses those files to start WireGuard and request PIA port forwarding. Buccaneerr runs after that and validates the finished voyage from inside Gluetun's network namespace.

If Buccaneerr exits cleanly, the ship be seaworthy. If it fails, check the service logs before blaming the sea monster in yer YAML.

## Restore example files 📜

The [examples](examples/) directory stores example files used to reset the repo after a test run:

- [examples/example-wg0.conf](examples/example-wg0.conf)
- [examples/example-privateerr.env](examples/example-privateerr.env)

These files contain fake pirate-flavored data. Cleanup targets copy them back into `config/gluetun/wireguard/` so live secrets do not accidentally sneak into Git.

Useful cleanup commands:

```sh
make clean-test
make restore-test-config
make nuke
```

`clean-test` uses the volume-preserving `down` path and restores the examples. `nuke` additionally removes project containers, networks, volumes, images, and the `privateerr-local` Buildx cache, but it leaves `.env`, `backups/`, and the persistent config directory intact. Shared or in-use base images are retained.

Run cleanup before committing after any real end-to-end voyage. Future ye will thank past ye for not smuggling secrets into the cargo hold. 🏴‍☠️

## Test automatic recovery

`make test-recovery` runs Python unit tests inside Buccaneerr without PIA credentials. It is also part of `make test`. The suite covers endpoint selection, backoff, manual stops, uncertain API responses, interrupted publication, generation failures, secret redaction, deadlines, and shutdown. Shell helper tests remain shell because they directly exercise Make, AWK, and shell commands.

Use the same Ruff configuration in your editor and CI:

```sh
make lint
make format
make test-precommit
make spellcheck
```

`make format` applies Python formatting and import fixes. Other lint commands only check. Pre-commit runs inside Buccaneerr and may normalize repository whitespace; it downloads pinned hook environments and uses Docker for the existing Hadolint hook. Python linting and formatting also run independently in `make test`, so new Python files are checked before they are staged.

Build the production image and verify authenticated settings replacement against Gluetun v3.41.3:

```sh
docker build -t privateerr:recovery-review docker
make test-recovery-api
```

The API test runs in Buccaneerr with Docker socket access. It creates uniquely named, labeled containers and a network, verifies their labels before cleanup, and uses temporary generated keys. It checks connection-field replacement, preservation of unrelated settings, invalid-update rejection, and unchanged container and network identity. Without credentials, it does not establish a real PIA tunnel. Ordinary offline suites have no Docker socket access.

To test a real tunnel, put your PIA credentials in `.env` and run:

```sh
make test-recovery-live
```

Run `scripts/compose/test.sh smoke` to validate an image-only upgrade using the legacy privileged container options, `PIA_DISABLE_IPV6=yes`, and no `PRIVATEERR_AUTO_RECOVER` variable. The new image must retain recovery-disabled behavior and produce clean IPv6 and permission diagnostics while Buccaneerr verifies real PIA forwarding. `make test-recovery-live` exercises the hardened configuration with all capabilities dropped, Docker-applied IPv6 settings, and `no-new-privileges`, including clean logs after recovery.

Override `PRIVATEERR_TEST_IMAGE` to select another locally built production image, or `PRIVATEERR_TEST_ENV_FILE` to use another credential file. The live test checks endpoint failure, automatic recovery, saved configuration, port forwarding, dependent-client connectivity, and traffic blocking outside the VPN.

Runtime checks require a local Unix Docker socket. A shared temporary directory lets the test driver and Docker daemon see the same isolated files. The live test reads only the required credentials from Compose's resolved environment, blocks the current endpoint only inside the test Gluetun container, and cleans up its labeled resources on exit. It does not modify existing deployments or the supplied environment file. The complete demo test is `make test-e2e`; it starts all four services and includes the controlled recovery fault by default. Run `make clean-test` afterward. Set `BUCCANEERR_TEST_RECOVERY=false` for a connectivity-only run.

The real API suite also starts qBittorrent and checks both forwarding hooks against its Web API without requiring PIA credentials. The live suite keeps that application running during endpoint failure, verifies its restored port and VPN binding, and connects to the forwarded TCP port from outside the VPN. UDP reachability and torrent throughput are not measured. All test containers have unique ownership labels and disposable configuration.
