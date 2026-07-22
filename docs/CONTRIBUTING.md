# Contributing to Privateerr 🏴‍☠️

Ahoy, improbable contributor. Since this project will likely be maintained by one caffeine-powered captain yelling at Docker Compose in the moonlight, contributions be welcome but should arrive shipshape.

## Before Ye Start ⚓

- Read the [README](../README.md).
- Read the [security policy](SECURITY.md) before sharing logs or generated config.
- Keep to the [Code](CODE_OF_CONDUCT.md).
- Check existing issues before opening a duplicate treasure map.

## What Belongs Here 🧭

Good contributions include:

- Clear bug fixes.
- Dockerfile or Compose improvements that keep Synology and macOS in mind.
- Documentation that helps real humans avoid cursed setup mistakes.
- Test improvements for Privateerr, Gluetun, or Buccaneerr.
- Security hardening that stays free, open, and maintainable.

Questionable cargo includes:

- Huge rewrites without an issue first.
- Paid-only services, subscription gates, or magic hosted scanners.
- Changes to upstream PIA scripts inside `docker/pia-manual-connections`.
- Anything that requires committing secrets, live `wg0.conf`, or real `privateerr.env` data.

## Local Setup 🛠️

```bash
git clone --recurse-submodules git@github.com:scottgigawatt/privateerr.git
cd privateerr
cp example.env .env
```

Edit `.env` with yer own values. Keep that file private.

Useful commands:

```bash
make build
make build-buccaneerr
make test-e2e
make test-down
pre-commit run --all-files
```

> [!IMPORTANT]
> 🧪 `make test-e2e` uses real PIA credentials from `.env`. That voyage should happen locally, not with secrets flung into random public waters.

## Style Rules 📜

- Public Markdown and user-facing command output may speak fluent pirate.
- Code comments should use plain English.
- Shell scripts written for host use should use `#!/bin/sh` where possible.
- Shell scripts should use four spaces for indentation.
- Docker Compose values should come from `.env` defaults instead of inline fallback soup.
- Keep pinned GitHub Action SHAs and Alpine digests intact unless the change is a dependency update.
- If ye update `ALPINE_TAG`, update every matching Dockerfile, workflow build arg, and example env default together.
- Keep service config directories aligned with service names.
- Leave upstream PIA scripts untouched so users can verify the treasure scrolls were not tampered with.

## Release Tags 🏷️

- Create annotated release tags from commits already on `main`.
- Use semantic versions such as `v1.2.3` or `v1.2.3-rc.1`.
- Never move or reuse a published version tag.
- Successful `main` builds publish `edge`; they do not replace `latest`.
- Stable version tags publish the exact version and replace `latest`.
- Prerelease tags publish only the prerelease version and commit SHA tags.
- Wait for the image workflow, registry mirror, and provenance checks before publishing the GitHub release.

## Pull Requests 🪝

Before opening a pull request:

- Run relevant `make` targets.
- Run `pre-commit run --all-files`.
- Let Renovate handle routine dependency bumps when possible.
- Restore example config with `make test-down` or `make nuke`.
- Confirm no secrets, live VPN configs, or logs slipped into the hold.
- Explain what changed and why.

Tiny pull requests be easier to review than a kraken-sized rewrite with six unrelated tentacles.

## Security Reports 🛡️

Do not report security problems in public issues or pull requests. Use the [security policy](SECURITY.md), or hail the captain in [🔥HADES🔥](https://discord.gg/BpEGzWwGYf) Discord for a safer channel.

Fair winds, clean diffs, and may yer YAML indent on the first try. ☠️
