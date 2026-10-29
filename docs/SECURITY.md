# Security policy 🛡️🏴‍☠️

Use this policy to report vulnerabilities privately and understand supported versions and image-security limits.

## Supported versions ⚓

Security fixes target the newest stable `latest` image and `edge` image built from `main`, rather than older releases.

| Version                             | Supported |
| ----------------------------------- | --------- |
| `latest` stable image               | ✅        |
| `edge` image and `main` branch      | ✅        |
| Older version tags and local builds | ❌        |
| Forked or modified PIA scripts      | ❌        |

> [!IMPORTANT]
> Privateerr uses unmodified official PIA scripts as a submodule. Also report vulnerabilities in those scripts to PIA.

## Report a vulnerability 🦜

Do not open public issues for credential leaks, authentication bypasses, or other vulnerability details.

Report vulnerabilities using [GitHub's private vulnerability reporting form](https://github.com/scottgigawatt/privateerr/security/advisories/new). To find it from the repository:

1. Go to the repository's **Security** tab.
2. Choose **Report a vulnerability**.
3. Include clear steps to reproduce, affected files, logs, container tags, and any relevant Docker Compose settings.

Do not send vulnerability details through Discord, discussions, issues, or pull requests. Those routes are for non-sensitive support and public collaboration.

If private vulnerability reporting is unavailable, open a GitHub issue containing only a brief, non-sensitive request for a private reporting channel. Do not describe the vulnerability publicly.

## Include useful evidence 📜

Helpful reports include:

- What you found.
- How to reproduce it.
- The version, branch, image tag, or commit you tested.
- Whether it affects Privateerr code, the Docker image, Gluetun integration, or upstream PIA scripts.
- Any safe logs with secrets removed.

> [!WARNING]
> Never include PIA credentials, WireGuard private keys, live `wg0.conf`, or live `privateerr.env` metadata in public reports.

## Understand response expectations 🕰️

This is a small maintainer project. I aim to:

- Acknowledge valid private reports within 7 days.
- Triage severity and scope as soon as possible.
- Patch accepted issues in `main` and publish the fix to `edge`.
- Publish a stable semantic-version release when the fix is ready for `latest`.
- Credit reporters when requested and safe to do so.

If a report is declined, I will try to explain why without exposing sensitive details.

## Understand container image security 🔎

Privateerr images are built from pinned Alpine image digests, not floating `latest` bases. GitHub Actions are pinned to full commit SHAs for the same reason: the same source commit should build from the same known cargo unless a dependency update is reviewed and merged.

Renovate watches the pinned Docker bases, GitHub Actions, Compose images, and submodules. When Alpine, an action, or another watched dependency moves, Renovate opens a pull request. The dependency only changes after that PR passes CI and lands on `main`.

The protected build path then:

- Uses pre-commit and CodeQL before pull requests can land.
- Runs OpenSSF Scorecard on its own schedule and branch-protection events.
- Builds Privateerr and Buccaneerr for `linux/amd64`, `linux/arm64`, and `linux/arm/v7`.
- Scans built images with Trivy before publishing.
- Publishes `edge` from `main` after checks pass.
- Publishes exact, minor, major, and `latest` aliases from stable semantic-version tags.
- Attests build provenance and mirrors Privateerr from GHCR to Docker Hub with digest preservation.

Rebuilding the same commit keeps the pinned base image, but uncached APK installation can pick up newer packages from Alpine. Renovate updates base and tool pins separately. Pull the resulting `edge` image or publish a stable release to deliver fixes to `latest`.

The remaining exact-path Compose exception for CVE-2026-78669 expires on November 6, 2026. The advisory remains unresolved. The exception keeps that known finding excluded at the existing path until then; all other scan rules remain unchanged. See the [current exception scope and risk](container-scan-review.md#current-compose-exception).

See the [dated container scan review](container-scan-review.md) for the reviewed image identities, dependency-fix scope, and upstream evidence behind remaining package-level alerts. Its scan dates and image revisions matter; results for an `edge` image do not describe every stable release.

Use `latest` for stable releases or `edge` to preview successful `main` builds.

Use the [support guide](SUPPORT.md) for non-sensitive setup questions and reproducible bugs.
