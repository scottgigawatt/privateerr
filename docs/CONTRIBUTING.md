# Contributing to Privateerr 🏴‍☠️

Ahoy, improbable contributor. Since this project will likely be maintained by one caffeine-powered captain yelling at Docker Compose in the moonlight, contributions be welcome but should arrive shipshape.

## Before you start ⚓

- Read the [README](../README.md).
- Read the [security policy](SECURITY.md) before sharing logs or generated config.
- Read the [documentation style](documentation-style.md) before changing public Markdown.
- Keep to the [Code](CODE_OF_CONDUCT.md).
- Check existing issues before opening a duplicate treasure map.

## What belongs here 🧭

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

## Set up a development checkout 🛠️

```sh
git clone --recurse-submodules git@github.com:scottgigawatt/privateerr.git
cd privateerr
cp example.env .env
```

Edit `.env` with yer own values. Keep that file private.

Useful commands:

```sh
make test
make test-workflows
make build
make build-buccaneerr
make build-platforms
make test-e2e
make clean-test
pre-commit run --all-files
```

`make down` preserves volumes and images. `make clean` never touches Docker, `.env`, generated WireGuard state, config, or backups. Use `make nuke` only for an intentionally destructive reset of this repository's Docker resources and scoped Buildx cache; it still preserves `.env`, `backups/`, and persistent config before restoring the checked-in examples.

> [!IMPORTANT]
>
> 🧪 `make test-e2e` uses real PIA credentials from `.env`. That voyage should happen locally, not with secrets flung into random public waters.

## Follow the project style 📜

- Public Markdown and user-facing command output may use light pirate flavor after the operational meaning is clear.
- Documentation follows [`documentation-style.md`](documentation-style.md), including sentence-case headings and alert limits.
- Code comments should use plain English.
- Shell scripts written for host use should use `#!/bin/sh` where possible.
- Shell scripts should use four spaces for indentation.
- YAML, TOML, AWK, and jq use two-space indentation; JSON and
  JSON-with-comments use four.
- Docker Compose values should come from `.env` defaults instead of inline fallback soup.
- Keep pinned GitHub Action SHAs and Alpine digests intact unless the change is a dependency update.
- If ye update `ALPINE_TAG`, update every matching Dockerfile, workflow build arg, and example env default together.
- Keep service config directories aligned with service names.
- Leave upstream PIA scripts untouched so users can verify the treasure scrolls were not tampered with.

### Configure editor tooling 🧰

`.editorconfig` is the portable source of truth for indentation, line endings, final newlines, and trailing whitespace. Install the recommendations from `.vscode/extensions.json` when using VS Code; each entry carries an aligned comment explaining whether it formats, validates, or only highlights a file type.

Workspace format-on-save is deliberately disabled. Prettier is available only for explicit formatting of supported JSON and Markdown files through the checked-in `.prettierrc.json5`. It does not parse jq, and the repository excludes jq, YAML, TOML, and aligned workspace JSONC from Prettier so specialized tools cannot undo project-owned spacing. Keep two spaces before pinned-action comments in workflow YAML.

## Create release tags 🏷️

- Create annotated release tags from commits already on `main`.
- Use semantic versions such as `v1.2.3` or `v1.2.3-rc.1`.
- Never move or reuse a published version tag.
- Successful `main` builds publish `edge`; they do not replace `latest`.
- Stable version tags publish exact, minor, major, and `latest` aliases.
- Major version zero omits the broad `0` alias.
- Prerelease tags publish only the prerelease version and commit SHA tags.
- Wait for the image workflow, registry mirror, and provenance checks before publishing the GitHub release.

## Prepare a pull request 🪝

Before opening a pull request:

- Run relevant `make` targets.
- Run `make test-workflows` for workflow, release, build-pin, or image-tag changes.
- Run `pre-commit run --all-files`.
- Let Renovate handle routine dependency bumps when possible.
- Restore example config with `make clean-test` or `make nuke`.
- Confirm no secrets, live VPN configs, or logs slipped into the hold.
- Explain what changed and why.

Tiny pull requests be easier to review than a kraken-sized rewrite with six unrelated tentacles.

## Report security concerns 🛡️

Do not report security problems in public issues, pull requests, or Discord. Use the [security policy](SECURITY.md) and GitHub private vulnerability reporting. Use the [support guide](SUPPORT.md) for non-sensitive questions.

Fair winds, clean diffs, and may yer YAML indent on the first try. ☠️
