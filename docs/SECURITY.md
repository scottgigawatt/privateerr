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

Privateerr images are built from current Alpine images and scanned during the GitHub workflow. Rebuilds pick up newer base image packages when Alpine publishes fixes.

> [!TIP]
> 🏴‍☠️ For the freshest patched hull, pull or rebuild the latest image before long voyages.

Fair winds, sharp eyes, and may yer secrets stay below deck. ☠️
