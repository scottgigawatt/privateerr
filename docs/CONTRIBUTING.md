# Contributing to Privateerr 🏴‍☠️

Help improve configuration generation, Gluetun integration, tests, or documentation. Keep changes focused and discuss large design changes in an issue first.

## Before you start ⚓

Read the [README](https://github.com/scottgigawatt/privateerr#readme), [documentation standards](documentation-style.md), [security policy](SECURITY.md), and [Code of Conduct](CODE_OF_CONDUCT.md). Search existing issues before opening one.

Keep upstream PIA scripts unmodified. Never contribute credentials, live VPN files, private logs, or operator-specific values. Production code uses the Python standard library; test dependencies belong in Buccaneerr.

<a id="development-checkout"></a>

## Set up a development checkout 🛠️

You need Git, Docker with Compose/Buildx, and Make:

```sh
git clone --recurse-submodules https://github.com/scottgigawatt/privateerr.git
cd privateerr
cp example.env .env
```

Offline checks and documentation builds need no real PIA credentials. Configure credentials only for an intentional, isolated live test. If the public HTTPS submodule is missing, [recover its pinned checkout](SUPPORT.md#recover-a-missing-pia-submodule).

## Validate your change

Select checks from the [canonical testing guide](development/privateerr/testing.md). It explains offline, real-API, live-VPN, build, and documentation boundaries. Report commands actually run and any skipped coverage. Pre-commit can modify files and download hooks; inspect its diff.

Live tests deliberately interrupt VPN traffic. Use a disposable checkout and preserve needed state first. After complete-example testing, [stop the stack and restore examples](advanced-usage.md#restore-vpn-examples). Never restore test files into an active deployment.

## Follow project conventions

`.editorconfig`, Ruff, and strict Pyright own formatting and type rules. Shell/Python/JSON use four spaces; Markdown/YAML/TOML/AWK/jq use two; Make recipes use tabs. Code comments use plain English. Keep Compose defaults in environment files and behavior explanations beside Compose entries.

Public documentation must apply the [GitHub and ISO plain-language policy](documentation-style.md), including reader-task review and duplicate-content removal. Preserve badges/community links and meaningful project voice.

Keep action SHAs, base-image digests, build arguments, and matching example defaults synchronized; use the existing policy checks. Renovate owns routine dependency updates.

### Configure editor tooling 🧰

Install the recommendations in `.vscode/extensions.json` when using VS Code. Format-on-save is disabled; explicit Prettier formatting is limited by `.prettierrc.json5` and exclusions. It must not undo aligned YAML, jq, TOML, or workspace JSONC. Ruff and Pyright configurations are shared with CI.

## Strict Python checks

Use `make test-types` for pinned containerized Pyright and `make lint` for Ruff lint/format, types, and ShellCheck. They require Docker; they do not prove runtime behavior. See [Python documentation conventions](development/privateerr/documentation.md) for source contracts.

## Build the developer documentation

Use `make docs` for the strict Material/API build and `make docs-serve` for preview. Follow [documentation validation](development/privateerr/testing.md#validate-documentation) for spelling, links, rendering, and reader-task review. PRs validate without deploying; Pages deployment is separate.

<a id="release-tags"></a>

## Create release tags 🏷️

Publishing requires separate maintainer authorization. Create annotated, immutable SemVer tags such as `v1.2.3` or `v1.2.3-rc.1` from commits already on `main`; never move/reuse them.

Successful `main` builds publish `edge` and SHA tags. Stable tags publish exact/minor/major/`latest` aliases; major zero omits `0`. Prereleases publish exact and SHA tags only. See [image channels](advanced-usage.md#registry-publishing).

The build workflow validates tags before registry login, builds all supported architectures, and verifies mirrors/provenance. Docker Hub publishing needs the repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`. Wait for publication verification before announcing a GitHub release.

## Prepare a pull request 🪝

Explain the problem and resulting behavior, list relevant validation and limits, and review the complete diff for unrelated changes or sensitive data. Documentation changes must preserve operational meaning while reducing repeated or unnecessary content.

Report vulnerabilities through the [private security route](SECURITY.md); use [support](SUPPORT.md) for non-sensitive questions. Small pull requests are easier to review than a kraken with six unrelated tentacles.
