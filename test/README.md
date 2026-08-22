# Buccaneerr Test Hold 🧪🏴‍☠️

Welcome to the test hold, where Buccaneerr climbs aboard after Privateerr and Gluetun to make sure the whole WireGuard voyage did not spring a leak. ☠️

The test tree keeps responsibilities separate:

- `policy/` verifies repository-wide dependency and image-tag rules.
- `helpers/` exercises Make and workflow helpers without external writes.
- `runtime/` performs opt-in acceptance checks against isolated Docker resources.
- `stubs/` supplies deterministic Docker and Skopeo stand-ins for those tests.
- `examples/` stores the checked-in WireGuard and metadata examples restored after a live voyage.
- the test-root `Dockerfile` and `buccaneerr-entrypoint.sh` remain the Buccaneerr build context.

## Test Script Chart 🗺️

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

The subfolders separate static repository policy, reusable helper tests,
deterministic command stubs, and checked-in reset examples. Make targets remain
the public interface; invoke individual scripts only while diagnosing a focused
failure.

## Offline Policy and Helper Checks 🧭

> [!TIP]
>
> ```sh
> make test
> make test-make-helpers
> make test-workflows
> ```

The complete local target checks reusable AWK and Compose helpers, config
backups, release tags, every structured Discord profile, registry mirroring,
synchronized SHA-256 build pins, and canonical image-tag channels. Disposable
negative fixtures prove that mismatched pins and unsafe tag rules are rejected.

Run the opt-in live cleanup acceptance after changing Compose lifecycle or
nuke behavior:

> [!CAUTION]
>
> ```sh
> test/runtime/test-compose-cleanup-live.sh
> ```

It creates uniquely named disposable projects and unrelated sentinels on the
real Docker daemon. The test proves `down` preserves volumes and images, then
proves `nuke` removes only its project resources and named builder. It never
uses the repository `.env`, config, backups, or PIA credentials.

## What Buccaneerr Be 🦜

Buccaneerr is the test-only image for this repo. It does not ship with the production Privateerr image, and it does not generate WireGuard config. Instead, it joins the running test stack after Privateerr has written its files and Gluetun has raised the VPN sails.

Buccaneerr checks the important loot:

- Gluetun is reachable.
- WireGuard traffic is alive.
- PIA port forwarding produced a usable forwarded port.
- The stack behaves like the downstream Synology-friendly Compose setup.

> [!IMPORTANT]
>
> ⚓ Buccaneerr exists so the main Privateerr image can stay wee, clean, and focused. Test tools like `curl` stay in this image instead of clutterin' the production brig.

## How It Gets Built 🛠️

The image is built from [Dockerfile](Dockerfile), using the same pinned Alpine base digest as Privateerr. The build copies [buccaneerr-entrypoint.sh](buccaneerr-entrypoint.sh) into the image and runs that script when the container starts.

Build it directly with:

```sh
make build-buccaneerr
```

Run the full end-to-end voyage with:

```sh
make test-e2e
```

> [!WARNING]
>
> 🧨 The e2e voyage uses real PIA credentials from `.env`. Do not commit live credentials, generated VPN configs, or logs from yer secret treasure chest.

## What It Does During E2E 🧭

The Compose stack starts Privateerr first. Privateerr writes:

- `config/gluetun/wireguard/wg0.conf`
- `config/gluetun/wireguard/privateerr.env`

Then Gluetun uses those files to start WireGuard and request PIA port forwarding. Buccaneerr runs after that and validates the finished voyage from inside Gluetun's network namespace.

If Buccaneerr exits cleanly, the ship be seaworthy. If it fails, check the service logs before blaming the sea monster in yer YAML.

## Example Files 📜

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

`clean-test` uses the volume-preserving `down` path and restores the examples.
`nuke` additionally removes project containers, networks, volumes, images, and
the `privateerr-local` Buildx cache, but it leaves `.env`, `backups/`, and the
persistent config directory intact. Shared or in-use base images are retained.

> [!TIP]
>
> 🏴‍☠️ Run cleanup before committing after any real e2e voyage. Future ye will thank past ye for not smuggling secrets into the cargo hold.
