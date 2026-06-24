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

```bash
make test-e2e
```

> [!IMPORTANT]
> The e2e test uses **real PIA credentials** from `.env`. Fake credentials should fail, and live generated VPN files should not be committed.

If the test stack is running and you want to clear it:

```bash
make test-down
```

## 🏗️ Multi-Architecture Builds

Published images target:

| 🧱 Platform | 🖥️ Typical use |
| --- | --- |
| `linux/amd64` | Intel and AMD x86_64 systems. |
| `linux/arm64` | Modern ARM64 systems, including many NAS and Apple Silicon Linux targets. |
| `linux/arm/v7` | 32-bit ARMv7 systems, including older ARM boards. |

To verify both Privateerr and Buccaneerr image builds locally:

```bash
make build-multiarch
```

The default Buildx platform list is defined in the Makefile:

```make
BUILDX_PLATFORM_OPTIONS ?= --platform linux/amd64,linux/arm64,linux/arm/v7
```

Override it for one-off checks:

```bash
make build-multiarch BUILDX_PLATFORM_OPTIONS="--platform linux/amd64,linux/arm64"
```

## 📦 Registry Publishing

The `build-and-push` GitHub Actions workflow builds and publishes Privateerr to GHCR first, then mirrors the same multi-architecture image to Docker Hub with Skopeo.

| 🚢 Registry | 🏷️ Privateerr image | 📝 Notes |
| --- | --- | --- |
| GHCR | `ghcr.io/${{ github.repository_owner }}/privateerr` | The test-only Buccaneerr image is also published here for CI and release validation. |
| Docker Hub | `docker.io/${{ github.repository_owner }}/privateerr` | Docker Hub is focused on the user-facing Privateerr image. |

The workflow uses Docker Buildx to create the canonical GHCR image:

```yaml
platforms: linux/amd64,linux/arm64,linux/arm/v7
push: true
```

Then it mirrors each generated Privateerr tag to Docker Hub with:

```bash
skopeo copy --all --preserve-digests \
  docker://ghcr.io/${{ github.repository_owner }}/privateerr:TAG \
  docker://docker.io/${{ github.repository_owner }}/privateerr:TAG
```

> [!NOTE]
> `--all` copies the full multi-architecture image instead of only the runner architecture. `--preserve-digests` makes the mirror fail if Docker Hub cannot preserve the source digest. That gives GHCR and Docker Hub matching image manifests for the same tag.

Configure these GitHub Actions values before enabling Docker Hub publishing:

| 🔐 Type | 🧾 Name | 🎯 Purpose |
| --- | --- | --- |
| Secret | `DOCKERHUB_USERNAME` | Docker Hub username used to log in. |
| Secret | `DOCKERHUB_TOKEN` | Docker Hub access token used by GitHub Actions. |

The Docker Hub repository overview is updated by the same workflow from [DOCKERHUB_README.md](./DOCKERHUB_README.md). Keep that file shorter than the GitHub README: Docker Hub readers usually need to know what the image does, how to pull it, what platforms it supports, and where the full project docs live.

## 🛠️ Useful Maintenance Commands

| ⚙️ Command | ✅ Purpose |
| --- | --- |
| `make config` | Render the Docker Compose model. |
| `make env` | Print evaluated Compose environment values. |
| `make print-config` | Print uncommented Compose YAML. |
| `make print-env` | Print uncommented Compose environment values. |
| `make build` | Build only the Privateerr image. |
| `make build-buccaneerr` | Build only the Buccaneerr validation image. |
| `make test-logs` | Show test stack logs. |

## 📄 Generated Files

Privateerr overwrites these files when it runs:

| 📍 File | 🧠 Notes |
| --- | --- |
| `config/gluetun/wireguard/wg0.conf` | Contains WireGuard connection material. Do not commit a live file. |
| `config/gluetun/wireguard/privateerr.env` | Contains endpoint and region metadata consumed by the Gluetun wrapper. |

Run this to restore checked-in examples:

```bash
make reset-config
```
