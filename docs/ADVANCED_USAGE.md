# 🧭 Advanced Usage

The main README stays focused on the shortest path: generate `wg0.conf`, inspect `privateerr.env`, and move on with your day. This page keeps the deeper project details.

## 🧪 Full Stack Validation

Privateerr includes an end-to-end Compose test path:

1. Build the Privateerr image.
2. Generate `wg0.conf`.
3. Generate `privateerr.env`.
4. Start Gluetun after Privateerr reports healthy.
5. Enable PIA port forwarding through Gluetun when configured.
6. Run Buccaneerr inside Gluetun's network namespace.

```sh
make test-e2e
```

> [!IMPORTANT]
>
> The e2e test uses **real PIA credentials** from `.env`. Fake credentials should fail, and live generated VPN files should not be committed.

Before Privateerr starts, Make asks Docker Compose for the resolved environment
and checks only `PIA_USER` and `PIA_PASS`. The preflight never sources `.env` or
prints either value, and it rejects the documented examples before a live run.

If the test stack is running and you want to clear it:

```sh
make clean-test
```

## 🏗️ Multi-Architecture Builds

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

## 📦 Registry Publishing

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

Then it mirrors each generated Privateerr tag to Docker Hub with:

```sh
skopeo copy --all --preserve-digests \
  docker://ghcr.io/${{ github.repository_owner }}/privateerr:TAG \
  docker://docker.io/${{ github.repository_owner }}/privateerr:TAG
```

> [!NOTE]
>
> `--all` copies the full multi-architecture image instead of only the runner architecture. `--preserve-digests` keeps the source content intact, and the workflow then inspects every published tag in both registries. A digest mismatch fails the publication instead of becoming a notification-only warning.

Configure these GitHub Actions values before enabling Docker Hub publishing:

| 🔐 Type | 🧾 Name              | 🎯 Purpose                                      |
| ------- | -------------------- | ----------------------------------------------- |
| Secret  | `DOCKERHUB_USERNAME` | Docker Hub username used to log in.             |
| Secret  | `DOCKERHUB_TOKEN`    | Docker Hub access token used by GitHub Actions. |

The Docker Hub repository overview is updated by the same workflow from [DOCKERHUB_README.md](./DOCKERHUB_README.md). Keep that file shorter than the GitHub README: Docker Hub readers usually need to know what the image does, how to pull it, what platforms it supports, and where the full project docs live.

## 🧷 Pinned Build Inputs

The release workflow uses pinned GitHub Action SHAs and a pinned Alpine image digest. That makes release builds boring in the best way: the same source commit should use the same action code and base image bits every time.

Renovate keeps those pins from going stale. It tracks:

- GitHub Actions pinned by SHA.
- Docker image tags and digests.
- Compose image references.
- Git submodules.

When Renovate opens a dependency PR, the validation workflow checks that every pinned `ALPINE_TAG` value still matches across Dockerfiles, workflow build args, and the example environment file. If one build arg drifts away from the fleet, [check-alpine-tag-pins.sh](../test/policy/check-alpine-tag-pins.sh) fails before the PR can merge.

> [!NOTE]
>
> 🧭 `latest` remains the recommended stable image tag for users, while `edge` follows successful `main` builds. Neither tag is used as the Alpine base. The base image is intentionally pinned and moved by reviewed Renovate PRs.

## 🛠️ Useful Maintenance Commands

| ⚙️ Command              | ✅ Purpose                                                             |
| ----------------------- | ---------------------------------------------------------------------- |
| `make config`           | Render the Docker Compose model.                                       |
| `make env`              | Print evaluated Compose environment values.                            |
| `make print-config`     | Print uncommented Compose YAML.                                        |
| `make print-env`        | Print uncommented Compose environment values.                          |
| `make ps`               | Show a compact Compose status table.                                   |
| `make test`             | Run policy checks plus Make and workflow helper tests.                 |
| `make test-workflows`   | Test release, Discord, and registry helpers without external writes.   |
| `make build`            | Build only the Privateerr image.                                       |
| `make build-buccaneerr` | Build only the Buccaneerr validation image.                            |
| `make build-platforms`  | Verify both images for every published architecture.                   |
| `make logs`             | Show test stack logs.                                                  |
| `make clean`            | Remove only disposable local test and tool artifacts.                  |
| `make clean-test`       | Stop the live test stack and restore checked-in examples.              |

## 📄 Generated Files

Privateerr overwrites these files when it runs:

| 📍 File                                   | 🧠 Notes                                                               |
| ----------------------------------------- | ---------------------------------------------------------------------- |
| `config/gluetun/wireguard/wg0.conf`       | Contains WireGuard connection material. Do not commit a live file.     |
| `config/gluetun/wireguard/privateerr.env` | Contains endpoint and region metadata consumed by the Gluetun wrapper. |

Run this to restore checked-in examples:

```sh
make restore-test-config
```
