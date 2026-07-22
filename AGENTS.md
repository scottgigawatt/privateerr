<!--
  Copyright 2025-2026 Scott Gigawatt

  Licensed under the Apache License, Version 2.0.

  AGENTS.md: Contributor and AI-agent operating instructions for Privateerr.
  -->

# AGENTS.md

## Project Purpose

Privateerr packages the official, unmodified [PIA manual connection scripts](https://github.com/pia-foss/manual-connections) into a small Docker image that generates a WireGuard config file and Gluetun metadata.

Privateerr is not a VPN client. It does not establish or maintain a VPN tunnel. It generates `config/gluetun/wireguard/wg0.conf` and `config/gluetun/wireguard/privateerr.env` so Gluetun or another WireGuard-capable VPN client can use them.

The companion Buccaneerr image is test-only. It validates the Privateerr + Gluetun flow, including PIA WireGuard port forwarding.

## Repository Layout

- `docker/`: Privateerr image build context and Privateerr-owned entrypoint scripts.
- `docker/pia-manual-connections/`: PIA upstream scripts as a git submodule. Treat this as third-party code.
- `test/`: Buccaneerr image build context, e2e validator scripts, and example reset files.
- `config/`: Checked-in service config directories used by Docker Compose.
- `config/gluetun/wireguard/`: Generated WireGuard config and metadata location.
- `docs/`: Supporting project documentation.
- `.github/`: Workflows, issue templates, PR template, Dependabot, and CODEOWNERS.
- `docker-compose.yml`: Single Compose stack used for local development, Synology-style one-file deployments, and e2e validation.
- `example.env`: Complete example environment file. Keep ordering aligned with `docker-compose.yml`.

## Code Ownership Boundaries

Do not edit `docker/pia-manual-connections/` unless the explicit task is to update or manage the upstream submodule.

Privateerr-owned code wraps the upstream scripts but should keep transparency clear:

- PIA scripts should remain visibly upstream and unmodified.
- Privateerr scripts should clearly show where they invoke PIA scripts.
- Logs from wrapper scripts should identify which script produced each line.

## Documentation Voice

Public-facing Markdown uses the project voice: funny, pirate-themed, readable, and useful.

Use pirate humor in:

- `README.md`
- files under `docs/`
- config-directory README files
- GitHub issue templates
- GitHub PR templates
- user-facing Makefile `echo` output when appropriate

Do not let jokes obscure operational meaning. Commands, paths, warnings, examples, and troubleshooting details must remain precise.

Use GitHub callouts where they help:

- `[!NOTE]`
- `[!TIP]`
- `[!IMPORTANT]`
- `[!WARNING]`
- `[!CAUTION]`

## Code Comment Style

Inline code comments must be plain English, not pirate-themed.

Comments should explain intent, constraints, and non-obvious behavior. Avoid narrating obvious assignments or shell syntax.

Top-of-file comments for project-owned scripts and config-style files should include:

- copyright line
- Apache-2.0 license note
- short filename summary
- short bullet list when usage or behavior needs context

Shell scripts with a shebang should have one blank line after the shebang before the top-of-file comment.

## Shell Script Rules

Project-owned host scripts should prefer:

- `#!/bin/sh`
- POSIX-compatible syntax
- four-space indentation

Container-only scripts may use Bash when the container image intentionally installs Bash and the Dockerfile/Compose entrypoint expects it.

Keep shell error messages clear enough to diagnose failures quickly. User-facing status logs may use the project voice, but actual diagnostic errors should be direct.

## Docker Rules

Dockerfiles should be professional and registry-friendly:

- include OCI labels
- keep images small
- avoid unused packages
- explain required packages with concise plain-English comments
- keep PIA scripts unmodified
- use Alpine unless there is a strong reason to change

Use architecture-neutral base images. Do not hardcode arch-specific image names such as `arm64v8/alpine`.

Multi-architecture support is handled by GitHub Actions and Docker Buildx. Current supported platforms are:

- `linux/amd64`
- `linux/arm64`
- `linux/arm/v7`

For multi-arch images, GHCR package descriptions require index-level OCI annotations in workflow build steps, not only Dockerfile labels.

## Docker Compose Rules

This project intentionally uses one main `docker-compose.yml` file. Synology DSM Container Manager compatibility is a core constraint.

Compose conventions:

- keep service image names fixed when possible
- keep image tags configurable through `.env`
- define defaults in `.env` / `example.env`, not inline Compose fallback syntax
- use YAML anchors for reusable labels or healthcheck settings
- mount directories, not individual generated config files
- group environment variables by owner/purpose
- list PIA script variables before Privateerr-specific wrapper variables
- keep `example.env` ordered to match the Compose service environment blocks

Privateerr and Gluetun both mount `./config/gluetun` because Privateerr writes files that Gluetun consumes.

## Generated Files And Secrets

Live runs overwrite:

- `config/gluetun/wireguard/wg0.conf`
- `config/gluetun/wireguard/privateerr.env`

Never commit real generated secrets. Restore checked-in examples with:

```sh
make reset-config
```

The source example files live in:

- `test/examples/example-wg0.conf`
- `test/examples/example-privateerr.env`

Use "example files" terminology. Do not call these dummy files.

## Makefile Rules

Keep Makefile variables centralized near the top. Prefer variables for:

- target names
- service names
- Docker Compose options
- Docker Buildx options
- reusable commands
- generated paths

Target comments should include dependencies using this format:

```make
#
# $(TARGET): Short target description.
#
# Dependencies:
#   $(OTHER_TARGET) - Why this dependency is needed.
#
```

User-facing Makefile output may be pirate-themed, but should still explain what is happening.

Important commands:

```sh
make help
make build
make build-buccaneerr
make build-multiarch
make run-privateerr
make test-e2e
make test-down
make reset-config
make clean
make nuke
make config
make env
make print-config
make print-env
```

Run `make test-down` after live e2e tests to stop containers and restore example files.

## GitHub Workflow Rules

Workflow step names should be pirate-themed and include tasteful emoji.

Use current major versions of GitHub Actions where practical.

Build/publish behavior:

- PR validation should build images and validate Compose without requiring PIA credentials.
- Full live e2e should only run when credentials are available.
- Main/tag publishing builds multi-arch images.
- Release tags use git tags like `v0.1.0`.
- Docker image semver tags omit the leading `v`, e.g. `0.1.0`.
- `latest` and the semver image tag for a release should be produced from the same build output.

Security/scanning:

- keep Trivy scanning in workflows
- keep Dependabot configuration current
- keep OpenSSF / best-practice metadata current where present
- keep provenance/SBOM enabled unless there is a specific reason not to

Expect GHCR to show `unknown/unknown` entries for attestation manifests. Those are metadata artifacts, not runnable OS images.

## Validation Expectations

For small documentation-only changes, run:

```sh
pre-commit run --all-files
```

For Docker or workflow changes, run as applicable:

```sh
make help
make config
make build
make build-buccaneerr
make build-multiarch
pre-commit run --all-files
```

For behavior changes touching Privateerr, Gluetun handoff, WireGuard config generation, or port forwarding, run:

```sh
make test-e2e
make test-down
```

Do not leave live generated VPN config or metadata in the working tree.

## Branch And PR Conventions

Use funny pirate-themed branch names when creating feature branches. Do not prefix branch names with `codex-` unless explicitly requested.

Commit messages may be funny and pirate-themed, with emoji, but they should still describe the change.

PR descriptions should lead with the main functional change, then summarize quality-of-repo improvements concisely.

## Licensing

Privateerr project-owned files are Apache-2.0.

The upstream PIA scripts are third-party code under their own license. Keep license boundaries clear and do not imply Privateerr relicenses the upstream submodule.

## Operational Priorities

Primary deployment target: Synology DSM Container Manager.

Secondary development target: macOS with Docker Desktop.

Preserve one-file Compose compatibility for Synology. Avoid modular Compose designs that require multiple Compose files at runtime.

Prefer simple, maintainable automation over clever abstractions.
