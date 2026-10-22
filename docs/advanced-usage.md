# Advanced usage 🧭

The main README stays focused on the shortest path: generate `wg0.conf`, inspect `privateerr.env`, and move on with your day. This page keeps the deeper project details.

## Run full-stack validation 🧪

`make test` runs credential-free repository checks without starting the VPN stack. The separate end-to-end target enables the `test` profile and starts Privateerr, Gluetun, qBittorrent, and Buccaneerr. It generates live VPN files and deliberately blocks the active endpoint to test recovery. Use real PIA credentials in a disposable checkout, and preserve any needed configuration before running it:

```sh
make test-e2e
```

Before Privateerr starts, Make asks Docker Compose for the resolved environment and checks only `PIA_USER` and `PIA_PASS`. The preflight never sources `.env` or prints either value, and it rejects the documented examples before a live run.

After the live test, stop the disposable stack and restore checked-in examples. This overwrites generated VPN files, so preserve any configuration you need first and follow [the sequential shutdown and restoration procedure](#restore-vpn-examples). Never use example restoration on an active deployment.

## Build multiple architectures 🏗️

Published images target:

| 🧱 Platform    | 🖥️ Typical use                                                            |
| -------------- | ------------------------------------------------------------------------- |
| `linux/amd64`  | Intel and AMD x86_64 systems.                                             |
| `linux/arm64`  | Modern ARM64 systems, including many NAS and Apple Silicon Linux targets. |
| `linux/arm/v7` | 32-bit ARMv7 systems, including older ARM boards.                         |

To verify both Privateerr and Buccaneerr image builds locally:

```sh
make build-platforms
```

The default Buildx platform list is defined in the Makefile:

```make
BUILDX_PLATFORM_OPTIONS ?= --platform linux/amd64,linux/arm64,linux/arm/v7
```

Override it for one-off checks:

```sh
make build-platforms BUILDX_PLATFORM_OPTIONS="--platform linux/amd64,linux/arm64"
```

<a id="registry-publishing"></a>

## Understand registry publishing 📦

The `build-and-push` GitHub Actions workflow builds and publishes Privateerr to GHCR first, then mirrors the same multi-architecture image to Docker Hub with Skopeo.

| 🚢 Registry | 🏷️ Privateerr image                                   | 📝 Notes                                                                             |
| ----------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------ |
| GHCR        | `ghcr.io/${{ github.repository_owner }}/privateerr`   | The test-only Buccaneerr image is also published here for CI and release validation. |
| Docker Hub  | `docker.io/${{ github.repository_owner }}/privateerr` | Docker Hub is focused on the user-facing Privateerr image.                           |

Both registries use the same release channels:

| 🏷️ Source                            | 📦 Published tags                             | 🧭 Purpose                                                            |
| ------------------------------------ | --------------------------------------------- | --------------------------------------------------------------------- |
| Successful `main` build              | `edge`, `sha-<commit>`                        | Preview the newest reviewed code without changing the stable channel. |
| Stable tag such as `v1.2.3`          | `1.2.3`, `1.2`, `1`, `latest`, `sha-<commit>` | Publish one stable release and advance its movable aliases.           |
| Prerelease tag such as `v1.2.3-rc.1` | `1.2.3-rc.1`, `sha-<commit>`                  | Publish a testable prerelease without changing stable aliases.        |

Release tags must use semantic versioning, be annotated, and point to a commit on `main`. A manual workflow run may publish only from `main`. The workflow validates those rules before it logs in to the registries or publishes an image.

For a major-zero release such as `v0.5.2`, the stable aliases are `0.5.2`, `0.5`, and `latest`; the broad `0` alias stays unpublished because pre-1.0 minor releases may contain breaking changes.

The workflow uses Docker Buildx to create the canonical GHCR image:

```yaml
platforms: linux/amd64,linux/arm64,linux/arm/v7
push: true
```

The workflow mirrors each generated Privateerr tag to Docker Hub. For an equivalent manual command, replace `YOUR-GITHUB-OWNER`, `YOUR-DOCKER-HUB-OWNER`, and `YOUR-VERSION` with the registry owners and image version:

```sh
skopeo copy --all --preserve-digests \
  docker://ghcr.io/YOUR-GITHUB-OWNER/privateerr:YOUR-VERSION \
  docker://docker.io/YOUR-DOCKER-HUB-OWNER/privateerr:YOUR-VERSION
```

> [!NOTE]
> `--all` copies the full multi-architecture image instead of only the runner architecture. `--preserve-digests` keeps the source content intact, and the workflow then inspects every published tag in both registries. A digest mismatch fails the publication instead of becoming a notification-only warning.

Configure these GitHub Actions values before enabling Docker Hub publishing:

| 🔐 Type | 🧾 Name              | 🎯 Purpose                                      |
| ------- | -------------------- | ----------------------------------------------- |
| Secret  | `DOCKERHUB_USERNAME` | Docker Hub username used to log in.             |
| Secret  | `DOCKERHUB_TOKEN`    | Docker Hub access token used by GitHub Actions. |

The Docker Hub repository overview is updated by the same workflow from [`docker-hub-description.md`](docker-hub-description.md). Keep that file shorter than the GitHub README: Docker Hub readers usually need to know what the image does, how to pull it, what platforms it supports, and where the full project documentation lives.

## Maintain pinned build inputs 🧷

The release workflow uses pinned GitHub Action SHAs and a pinned Alpine image digest. That makes release builds boring in the best way: the same source commit should use the same action code and base image bits every time.

Renovate keeps those pins from going stale. It tracks:

- GitHub Actions pinned by SHA.
- Docker image tags and digests.
- Compose image references.
- Git submodules.
- Pre-commit hook releases.
- Exact, hash-verified Python documentation dependencies.
- Pinned npm tools in Buccaneerr, including Pyright and CSpell.

When Renovate opens a dependency pull request, the validation workflow checks that every digest-pinned build dependency matches across Dockerfiles, workflow build arguments, and the example environment file. If one build argument drifts away from the fleet, [`check-build-pin-policy.sh`](https://github.com/scottgigawatt/privateerr/blob/main/test/policy/check-build-pin-policy.sh) fails before the pull request can merge.

`latest` remains the recommended stable image tag for users, while `edge` follows successful `main` builds. Neither tag is used as the Alpine base. The base image is intentionally pinned and moved by reviewed Renovate PRs.

Pull requests also run CodeQL and container vulnerability checks. Published images include software bills of materials and provenance attestations; OpenSSF Scorecard checks repository security practices.

## Inspect configuration and environment values 🔎

Use `make print-config` to inspect the Compose source without comments, or `make config` to resolve its variables. Resolved configuration and environment output can include credentials; inspect it locally and never paste full output into a support report. A broad `PIA` filter also matches the account credentials. To inspect only these named non-secret selection settings:

```sh
make env | grep -E '^(PIA_AUTOCONNECT|PIA_PREFERRED_REGION|PIA_PF)='
```

Region preferences are still operational information; review even filtered output before sharing diagnostics. `example.env` supplies defaults and operator editing prompts; aligned Compose comments explain behavior, accepted values, and units.

<a id="maintenance-reference"></a>

## Use maintenance commands 🛠️

| ⚙️ Command              | ✅ Purpose                                                             |
| ----------------------- | ---------------------------------------------------------------------- |
| `make config`           | Render the Docker Compose model.                                       |
| `make env`              | Print evaluated Compose environment values.                            |
| `make print-config`     | Print uncommented Compose YAML.                                        |
| `make print-env`        | Print uncommented Compose environment values.                          |
| `make ps`               | Show a compact Compose status table.                                   |
| `make backup`           | Archive the complete config directory without replacing older cargo.  |
| `make up` / `make up-pull` | Pull published application images and start the three services detached. |
| `make up-build`         | Pull Gluetun/qBittorrent, build Privateerr, and start the three services. |
| `make test-e2e`         | Enable the test profile and run live VPN fault validation in a disposable project. |
| `make test`             | Run Python tests, strict types, lint, policy, and helper checks.                 |
| `make test-workflows`   | Test release, Discord, and registry helpers without external writes.   |
| `make build`            | Build only the Privateerr image.                                       |
| `make build-buccaneerr` | Build only the Buccaneerr validation image.                            |
| `make build-platforms`  | Verify both images for every published architecture.                   |
| `make logs`             | Show Compose project logs.                                                  |
| `make down`             | Stop application/test-profile containers and project networks; retain volumes/images.  |
| `make clean`            | Remove only disposable local test and tool artifacts.                  |
| `make clean-test`       | Stop the live test stack and restore checked-in examples.              |
| `make nuke`             | Remove project Docker resources/cache and reset transient test state.  |

`make backup` archives `config/` without stopping writers. Stop the relevant services first when you need a consistent backup, protect the archive as secret-bearing data, and verify that it contains the files you need. The archive does not include `.env` or Docker-managed volumes; preserve those separately when your recovery plan requires them.

Use `make nuke` only for an intentionally destructive reset of a disposable project. It removes this project's containers, networks, volumes, eligible images, and scoped build cache. It preserves `.env`, `backups/`, and persistent bind-mounted config, then restores the checked-in WireGuard examples. Base-image removal is best effort when another container or project still uses the same image.

<a id="restore-vpn-examples"></a>

## Restore generated files 📄

Privateerr generates or reuses these files at startup. Automatic recovery replaces them only after confirming the applied settings and tunnel health; explicit one-shot generation creates a fresh pair:

| 📍 File                                   | 🧠 Notes                                                               |
| ----------------------------------------- | ---------------------------------------------------------------------- |
| `config/gluetun/wireguard/wg0.conf`       | Contains WireGuard connection material. Do not commit a live file.     |
| `config/gluetun/wireguard/privateerr.env` | Contains endpoint and region metadata consumed by the Gluetun wrapper. |

Example restoration overwrites both generated VPN files; it is not a backup restore or a recovery procedure for an active deployment. Use it only in a disposable test checkout after preserving any needed state:

```sh
make clean-test
```

The target stops the selected project, including the `test` profile, and restores examples only after shutdown succeeds. For separate control, run `make down` and then `make restore-test-config` after shutdown succeeds. Verify that only example files remain before committing; leave an operator's live configuration untouched.

## Inspect example output 📦

<!-- markdownlint-disable MD033 -->
<details>
<summary>View abbreviated example output</summary>

The checked-in examples use fake data. A real run overwrites them.

```text
[Interface]
Address = 10.10.10.10
PrivateKey = EXAMPLE-PRIVATE-KEY
DNS = 10.10.10.10

[Peer]
PersistentKeepalive = 25
PublicKey = EXAMPLE-PUBLIC-KEY
AllowedIPs = 0.0.0.0/0
Endpoint = 10.10.10.10:1234
```

```text
PIA_WG_SERVER_NAME=jolly-roger-401
PIA_WG_ENDPOINT_IP=10.10.10.10
PIA_WG_ENDPOINT_PORT=1234
PIA_REGION_ID=skull-island
PIA_REGION_NAME="Skull Island"
PIA_PORT_FORWARDING_SUPPORTED=true
PIA_GEOLOCATED_REGION=false
```

</details>
<!-- markdownlint-enable MD033 -->
