# Security Policy 🛡️🏴‍☠️

Ahoy, security-minded sailor. If ye spot a cursed leak, a leaky hull, or a suspicious barnacle clingin' to Privateerr, this be the proper chart for reportin' it.

## Supported Versions ⚓

Privateerr sails mostly by the `main` branch and the latest published container images. Since this project be a small vessel, security fixes target the newest chart instead of older treasure maps.

| Version | Supported |
| ------- | --------- |
| `latest` image | ✅ |
| `main` branch | ✅ |
| Older local builds | ❌ |
| Forked or modified PIA scripts | ❌ |

> [!IMPORTANT]
> 🧭 Privateerr uses the official PIA manual connection scripts as a submodule. Security issues in those upstream scripts should also be reported to the PIA project, because Privateerr keeps those scrolls untouched.

## Reporting a Vulnerability 🦜

Please do not open a public GitHub issue for secrets, credential leaks, auth bypasses, or anything that could help another scallywag attack a user.

Report vulnerabilities using GitHub's private vulnerability reporting feature:

1. Go to the repository's **Security** tab.
2. Choose **Report a vulnerability**.
3. Include clear steps to reproduce, affected files, logs, container tags, and any relevant Docker Compose settings.

Ye can also send a message through the [🔥HADES🔥](https://discord.gg/BpEGzWwGYf) Discord server if ye need to hail the captain quickly.

If private vulnerability reporting is unavailable, open a GitHub issue with only a brief non-sensitive note asking for a secure reporting channel, or use Discord to ask where to send details. Keep the dangerous details off the public deck.

## What to Include 📜

Helpful reports include:

- What ye found.
- How to reproduce it.
- What version, branch, image tag, or commit ye tested.
- Whether it affects Privateerr code, the Docker image, Gluetun integration, or upstream PIA scripts.
- Any safe logs with secrets removed.

> [!WARNING]
> 💣 Never include real PIA usernames, passwords, WireGuard private keys, generated `wg0.conf` files, or live `privateerr.env` metadata in a public report.

## Response Expectations 🕰️

This be a small maintainer ship, not a giant navy. I will do my best to:

- Acknowledge valid private reports within 7 days.
- Triage severity and scope as soon as possible.
- Patch accepted issues in `main`.
- Publish a fresh image after a fix lands.
- Credit reporters when requested and safe to do so.

If a report is declined, I will try to explain why without leakin' dangerous details into open waters.

## Container Image Security 🔎

Privateerr images are built from pinned Alpine image digests, not floating `latest` bases. GitHub Actions are pinned to full commit SHAs for the same reason: the same source commit should build from the same known cargo unless a dependency update is reviewed and merged.

Renovate watches the pinned Docker bases, GitHub Actions, Compose images, and submodules. When Alpine, an action, or another watched dependency moves, Renovate opens a pull request. The dependency only changes after that PR passes CI and lands on `main`.

The protected build path then:

- Uses pre-commit and CodeQL before pull requests can land.
- Runs OpenSSF Scorecard on its own schedule and branch-protection events.
- Builds Privateerr and Buccaneerr for `linux/amd64`, `linux/arm64`, and `linux/arm/v7`.
- Scans built images with Trivy before publishing.
- Publishes images from `main` after checks pass.
- Attests build provenance and mirrors Privateerr from GHCR to Docker Hub with digest preservation.

Rebuilding the same commit does not automatically pick up a newer Alpine base. To pick up patched packages, merge the Renovate update PR first, then pull or publish a fresh image from the updated `main`.

> [!TIP]
> 🏴‍☠️ For the freshest patched hull, pull the newest published image after dependency update PRs have merged.

Fair winds, sharp eyes, and may yer secrets stay below deck. ☠️
