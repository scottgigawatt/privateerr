# Maintenance and image reference 🧭

Use these commands from the repository root after completing the [setup](https://github.com/scottgigawatt/privateerr#readme). For test selection and image builds, use the [developer testing guide](development/privateerr/testing.md).

## Manage installed Gluetun scripts

Privateerr installs its startup wrapper and qBittorrent forwarding hook into the shared `/gluetun/scripts/` directory before reporting ready. Both containers must mount the complete `/gluetun` directory. Installation failure prevents readiness.

The two installed filenames belong to Privateerr and are replaced at startup. Keep custom scripts under different names and select their paths explicitly. Recreate Privateerr, Gluetun, and qBittorrent together after updating images. API-based tunnel recovery preserves their running containers.

## Read container logs

Use your container manager's log view, or run:

```sh
docker compose logs --tail 100 privateerr
```

Records include a UTC timestamp, severity, and source. `[privateerr]` identifies the supervisor; `[PIA/run_setup.sh]` includes output from that upstream invocation and its children. Privateerr redacts recognized credentials before forwarding upstream output, but paths, region preferences, and unrecognized secret formats can remain. Inspect and redact excerpts before sharing them.

The [recovery diagnostics](automatic-recovery.md#read-diagnostics-and-check-storage) explain failure categories and storage checks. Source-level logging behavior belongs in the [architecture guide](development/privateerr/architecture.md#read-consistent-generation-logs).

<a id="maintenance-reference"></a>

## Maintain the project

Use `make help` for the full command menu. Routine inspection uses `make ps` and `make logs`. `make down` stops the selected application and test-profile services while retaining volumes and images.

> [!CAUTION]
> Resolved configuration and environment output can contain credentials. Keep `make config`, `make env`, `make print-config`, and `make print-env` output private. Report whether a check passed instead of pasting its full output.

### Back up configuration

`make backup` archives `config/` without stopping writers or replacing earlier archives. Stop the relevant services first when you need a consistent backup. Protect the archive as secret-bearing data and verify that it contains the files you need.

The archive excludes `.env` and Docker-managed volumes. Preserve those separately when required by your recovery plan. This repository does not provide an application-aware restore command; restore only after checking ownership, destination paths, and the saved files' compatibility.

### Clean developer artifacts

`make clean` removes disposable developer artifacts. It preserves deployments, `.env`, configuration, backups, containers, volumes, and images.

`make nuke` is a destructive reset for an explicitly disposable project. It removes that project's Docker containers, networks, volumes, eligible images, and scoped Buildx cache, then resets transient state and restores the checked-in VPN examples. It preserves `.env`, `backups/`, and persistent bind-mounted config, but example restoration replaces the VPN pair. Back up needed state first. Shared or in-use base images are retained. Never use it to repair an active deployment.

<a id="restore-vpn-examples"></a>

## Restore test examples

Example restoration replaces `config/gluetun/wireguard/wg0.conf` and `privateerr.env`. It is not a backup restore. Use it only in a disposable test checkout after preserving any needed state:

```sh
make clean-test
```

The target stops the selected stack, including the `test` profile, and restores examples only after shutdown succeeds. For separate control, run `make down`, wait for success, then run `make restore-test-config`. Never restore examples while a supervisor is writing those files or against an active deployment. Confirm that only checked-in example data remains before committing.

<a id="registry-publishing"></a>

## Choose an image channel

Privateerr is available from `ghcr.io/scottgigawatt/privateerr` and `docker.io/scottgigawatt/privateerr`. Buccaneerr is published to GHCR for testing.

| Channel | Use |
| --- | --- |
| `latest` | Newest stable release |
| `edge` | Successful `main` build for previewing changes |
| Exact version, such as `1.2.3` | A selected release |
| `sha-<commit>` | A selected commit build |
| Image digest | Exact image contents |

Stable releases also advance minor and major aliases; major zero has no `0` alias. Prereleases publish exact and SHA tags only. Tags can move where policy allows; use a digest when reproducibility requires immutable contents.

Privateerr and Buccaneerr support `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. The qBittorrent example supports amd64 and arm64.

The workflow builds GHCR images, mirrors Privateerr to Docker Hub with digest verification, and updates the [Docker Hub description](docker-hub-description.md). It publishes SBOMs and provenance and applies vulnerability gates. A passing gate does not mean zero findings; see the [security policy](SECURITY.md). Maintainers should follow [release requirements](CONTRIBUTING.md#release-tags) before publishing.

## Generate without Make

After the [checkout and environment setup](https://github.com/scottgigawatt/privateerr#prepare-a-checkout), use the published image. This replaces saved VPN files; stop other writers and preserve needed state first:

```sh
docker compose --env-file .env run --rm --no-deps --pull always \
  --env PRIVATEERR_AUTO_RECOVER=false \
  --env PRIVATEERR_KEEPALIVE=false \
  --env PIA_CONNECT=false \
  --env VPN_PROTOCOL=wireguard \
  privateerr
```

For a source build, initialize the pinned PIA submodule and replace `--pull always` with `--build --pull never`.

## Start without Make

Complete the [recovery key and application settings](https://github.com/scottgigawatt/privateerr#start-privateerr-with-gluetun-) first. Startup/recreation can interrupt application traffic:

```sh
docker compose --env-file .env pull privateerr gluetun qbittorrent
docker compose --env-file .env up --detach --no-build --pull never privateerr gluetun qbittorrent
```

For a source build, pull only Gluetun/qBittorrent, run `docker compose --env-file .env build privateerr`, then use the same `up` command. Keep the pinned PIA submodule initialized.
