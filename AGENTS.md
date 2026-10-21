<!--
  Copyright 2025-2026 Scott Gigawatt

  Licensed under the Apache License, Version 2.0.

  AGENTS.md: Contributor and AI-agent operating instructions for Privateerr.
  -->

# AGENTS.md

## Purpose and repository map

Privateerr packages the official, unmodified [PIA manual connection scripts](https://github.com/pia-foss/manual-connections) into a small Docker image that generates WireGuard configuration and Gluetun metadata. Privateerr is not a VPN client: Gluetun owns the tunnel and port lease. The optional standard-library Python supervisor renews stale PIA registrations through Gluetun's authenticated API without restarting containers.

The default Compose example includes Privateerr, Gluetun, qBittorrent, and the test-only Buccaneerr service without application profiles. Buccaneerr verifies forwarding, application settings, and recovery through a temporary firewall fault inside the shared VPN namespace. Web UI ports and API endpoints remain driven by environment settings.

| Path | Responsibility |
| --- | --- |
| `docker/` | Production image context, shell adapters, and health checks |
| `docker/privateerr/` | Standard-library Python supervisor, API client, validation, and persistence |
| `docker/pia-manual-connections/` | Licensed upstream PIA git submodule; leave its contents unmodified |
| `test/` | Buccaneerr image and test tooling using the restricted repository-root build context |
| `test/policy/` | Static repository policy and spelling checks |
| `test/unit/` | Supervisor, client, generation, and forwarding-hook unit tests |
| `test/runtime/` | Real Gluetun and qBittorrent tests, including explicitly selected live PIA tests |
| `test/helpers/`, `test/stubs/` | Isolated automation tests and deterministic command stubs |
| `test/examples/` | Checked-in example VPN files for test restoration |
| `scripts/compose/`, `scripts/awk/` | Host-side preflight, lifecycle, backup, and configuration helpers |
| `scripts/docs/`, `docs/`, `mkdocs.yml` | Documentation build driver, guides, and Material site configuration |
| `config/` | Service configuration, persistent bind mounts, and generated VPN state |
| `.github/` | Workflows, workflow helpers, templates, Renovate policy, and CODEOWNERS |
| `docker-compose.yml`, `example.env` | One-file deployment stack and its ordered example settings |

This file supplies repository-wide guidance. Before editing a directory, inspect any applicable nested `AGENTS.md` and relevant `.agents/skills/` instructions if present. Nested guidance may refine local work; report conflicts with the requested scope instead of silently changing unrelated guidance. Keep these instructions self-sufficient, with no dependency on another repository's style or workflow policy.

## Scope and working tree

Inspect the current branch, status, diff, and relevant source before editing. Use a fresh base and an isolated branch or checkout when needed; preserve unrelated edits, untracked files, and user work. Do not reset, clean, stash, or reformat unrelated work to make validation pass. Stage explicit paths and review the complete diff before committing.

Make the smallest coherent change that satisfies the task. Consolidate duplicate guidance while retaining meaningful local constraints. Report contradictory linked guidance rather than expanding a narrowly scoped task to rewrite it. Prefer simple, maintainable automation over clever abstractions.

Repository edits do not authorize production operations. Starting stacks, registering with PIA, changing a running VPN, restoring configuration, deleting Docker resources, publishing packages, deploying Pages, merging, or releasing requires authorization for that action. Honor requested draft-PR and manual-review checkpoints; do not approve, merge, enable auto-merge, tag, or release on the user's behalf without authorization.

## Source, generated state, and secrets

Keep production Python standard-library-only. Lint, formatting, typing, documentation, unit-test, and runtime-test dependencies belong in Buccaneerr, never the production Privateerr image or another deployed service. Documentation packages use Buccaneerr's optional `docs` target. Keep build-context allowlists restrictive, source mounts read-only where supported, and generated `site/` output ignored.

Do not edit `docker/pia-manual-connections/` unless the task explicitly requests upstream submodule management. Preserve its pinned revision, license, and attribution. Privateerr-owned wrappers must visibly identify upstream invocations; logs should identify the originating script. Privateerr-owned files are Apache-2.0; the upstream submodule retains its own license and is not relicensed by Privateerr.

Live runs overwrite these secret-bearing files:

- `config/gluetun/wireguard/wg0.conf`
- `config/gluetun/wireguard/privateerr.env`

Never print or commit real credentials, private keys, API tokens, generated VPN state, private logs, backups, or operator-specific environment values. Use secret-free examples and inspect the diff for accidental disclosure. When explicitly editing a local environment file, preserve all assignment values and operator overrides except the requested change.

After authorized live tests in a disposable checkout, restore the checked-in example files from `test/examples/example-wg0.conf` and `test/examples/example-privateerr.env`:

```sh
make restore-test-config
```

This overwrites both destination files; never run it against an operator's active VPN configuration. Use the term "example files" rather than "dummy files". Verify restoration and working-tree status before handoff.

## Formatting and comments

`.editorconfig` is the portable source of truth; editor settings, formatters, and automation must agree. Use UTF-8, LF endings, and final newlines. Use four spaces for shell, Python, JSON, and JSON with Comments; two spaces for Markdown, YAML, TOML, AWK, jq, CSS, and JavaScript; literal tabs for Make recipes and the established Git submodule declarations. Preserve intentional Markdown hard breaks.

Comments use plain English and explain intent, constraints, or non-obvious behavior. Do not narrate assignments or obvious syntax, add repetitive step labels, or use pirate language in code comments. Separate logical blocks with blank lines where useful; let the configured formatter decide layout.

Project-owned scripts and config-style files start with copyright, Apache-2.0 notice, and a short filename summary; add usage bullets only when useful. Put one blank line after a shell shebang before that block. Align inline Compose comments within each logical group with at least two spaces before `#`.

Fix the cause of lint, typing, spelling, or security findings. Any necessary exception must be narrow, justified beside the affected code, and tied to a real runtime or test constraint. Do not weaken strict modes, exclude whole code areas, or add blanket suppressions to hide findings.

## Shell and Python quality

Keep implementation and tests consistent with the repository-owned checker configurations.

### Shell

Host scripts prefer `#!/bin/sh`, POSIX syntax, and four-space indentation. Container-only scripts may use Bash when the image deliberately installs it and the entrypoint expects it. Quote expansions and paths, preserve failure status, and make cleanup explicit. Use direct diagnostic errors even when status messages use the project voice. `.shellcheckrc` supplies source resolution; use targeted ShellCheck suppressions only when a documented constraint prevents a correct fix.

Document each shell function immediately above its declaration using this shape, with one parameter per comment line, one space after `Returns:`, and `Parameters: None.` when appropriate:

```sh
#
# function_name: Describe the function's purpose.
#
# Parameters: $1 - Describe the first parameter.
#             $2 - Describe the second parameter.
#
# Returns: Describe the return value or exit behavior.
#
```

Keep each short explanatory sentence on one comment line. Test shell helpers with isolated fixtures and stubs; do not turn a helper test into a real deployment mutation.

### Python

Python modules and tests start with the license and filename-summary block followed by a useful module docstring. Prefer small functions, explicit types at application boundaries, validated dynamic input, narrowed optional values, and explicit collection and callback contracts. Avoid blanket `Any` annotations or broad exceptions that conceal errors.

`ruff.toml` owns lint, import order, and formatting. Run both Ruff lint and format checks through `make lint`; that target also runs strict Pyright and ShellCheck. `pyrightconfig.json` covers all project-owned Python modules and tests, including optional fuzz harnesses. `make test-types` runs the containerized checker; preserve enforcement in Make, pre-commit, and PR/main/release validation.

Public modules, classes, methods, and functions use concise Google-style docstrings when useful. Describe meaning, side effects, invariants, and failure behavior; types remain in signatures. Use `Args`, `Returns`, `Raises`, `Attributes`, and `Note` sections only when applicable. Document non-obvious private helpers even though mkdocstrings filters names beginning with `_`. Do not duplicate generated API reference by hand.

Tests explain the scenario and boundary they protect. Add concise comments for controlled fixtures, injected failures, cleanup, and meaningful assertion groups; separate setup, action, and verification when it improves readability. Keep test tools out of published production images.

Run `make spellcheck` across project-owned files. Correct misspellings; genuine project vocabulary belongs in `.vscode/settings.json` under `cSpell.words`. Never add secrets or arbitrary whole strings to silence spelling diagnostics.

## Containers and deployment constraints

Primary deployment target: Synology DSM Container Manager. Secondary development target: macOS with Docker Desktop. Preserve one main `docker-compose.yml`; avoid runtime designs requiring multiple Compose files or application profiles.

Keep Privateerr deployments unprivileged with all Linux capabilities dropped and `no-new-privileges`. UID 0 remains necessary for the unmodified upstream scripts; do not equate UID 0 with permission to add privileged mode or capabilities. Docker owns initial namespace IPv6 settings; the adapter skips redundant writes while preserving legacy image-only behavior.

Dockerfiles use architecture-neutral base images, concise package explanations, OCI labels, and minimal required packages. Prefer Alpine unless a specific need justifies changing it. Do not hardcode architecture-specific image names. Preserve Buildx support for `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. Multi-architecture registry descriptions need index-level OCI annotations as well as Dockerfile labels. Attestation manifests may appear as `unknown/unknown`; they are metadata, not runnable images.

Compose conventions:

- Keep image names fixed where possible and image tags configurable through environment files.
- Put deployment defaults in `.env` / `example.env`, never interpolation fallbacks in Compose.
- Enable recovery in public deployment examples; preserve the recovery-disabled image-only default when no setting is supplied.
- Use YAML anchors for reusable labels and health checks; mount directories rather than individual generated files.
- Keep Privateerr and Gluetun mounting `./config/gluetun` for the generated-file handoff.
- Group environment settings by owner and purpose, list PIA variables before Privateerr wrapper variables, and keep `example.env` ordering aligned with Compose.

Keep environment files focused on values. Their end-of-line comments should flag operator actions: credentials, host paths, user/group IDs, time zones, or host-port conflicts. Use short prompts such as `Edit before launch:` or `Edit for your host:`. Generated secrets requiring no manual action need no inline comment. Keep useful section headings.

Explain behavior, accepted values, units, limits, dependencies, and numeric/boolean meanings beside the corresponding Compose entries in aligned comments. For example, `1 disables IPv6; 0 enables IPv6`. Do not move routine per-variable explanations into standalone environment comments to bypass this division.

## Make and operational safety

Use `make help` and read the actual recipes before selecting a target. Keep reusable target names, service names, commands, options, and generated paths centralized near the top of the Makefile. Declare operational targets phony, preserve literal recipe tabs, quote path and value arguments, use `$$` for shell variables, and propagate failures rather than masking them. Test dependency ordering and cleanup with isolated helper fixtures. A dry run is a preview, not proof of safety or successful execution.

Document targets and dependencies in the established form:

```make
#
# $(TARGET): Short target description.
#
# Dependencies:
#   $(OTHER_TARGET) - Why this dependency is needed.
#
```

User-facing Make output may be lightly pirate-themed while clearly describing the action. Preserve these actual boundaries:

| Target | Effect and caution |
| --- | --- |
| `make help` | Prints the command chart without starting the stack |
| `make config`, `make env`, `make print-config`, `make print-env` | Print configuration or environment content that can expose secrets; keep output private |
| `make build`, `make build-buccaneerr`, `make build-platforms` | Build images or check architectures; can fetch dependencies and create Buildx resources |
| `make up`, `make all`, `make run-privateerr` | Start services or generate real VPN state; require PIA credentials and operational authorization |
| `make down` | Stops the selected Compose project; preserves volumes and images |
| `make backup` | Archives the full config directory, potentially including secrets; protect and verify the archive |
| `make restore-test-config` | Overwrites generated VPN files with checked-in examples |
| `make clean-test` | Stops the selected stack and restores examples; use after authorized disposable e2e runs |
| `make clean` | Removes disposable developer artifacts only; must preserve deployment state, examples, containers, volumes, images, and `.env` |
| `make nuke` | Removes selected project Docker resources, repository-owned Buildx cache, and transient runtime state; restores examples and preserves `.env`, `backups/`, and persistent bind-mounted config |

Destructive targets require an explicitly disposable project, verified ownership boundaries, and authorization. Back up needed data first and understand the recovery path. Never use global Docker prune or delete unrelated resources. The `clean-test` recipe expresses stopping and restoration as prerequisites; do not assume parallel Make execution enforces a safe sequence. Confirm services are stopped before restoring files.

## Documentation standards

Write for the intended reader and verify the result in each renderer that serves the page.

### Content and source conventions

Public Markdown is readable, useful, and lightly pirate-themed. Put operational meaning first; humor belongs in short introductions, transitions, sign-offs, templates, and suitable status output. Commands, paths, UI labels, warnings, security guidance, destructive actions, and troubleshooting remain literal and precise.

Identify the audience and outcome. Put prerequisites before numbered procedures, follow execution order, verify the result, and cover likely failures. Keep concepts, quickstart guides, how-to guides, reference, and troubleshooting focused on their distinct purpose. State required versions, permissions, credentials, and platform constraints without including actual secrets.

Use one page title and a logical sentence-case heading hierarchy without skipped levels; introduce a section before its subsections. Put searchable words before decorative emoji. Emoji must never carry meaning alone. Use numbered lists for procedures, bullets for unordered choices, and simple readable tables for comparisons. Keep blank lines around structural blocks and check narrow-screen layout.

Use descriptive relative links for repository-owned files and valid heading anchors; verify targets after heading or filename changes. Keep established convention filenames such as `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, and `SUPPORT.md`; ordinary articles use lowercase kebab-case. Update inbound links and affected configuration paths with authorized renames.

Every fenced block has an appropriate language label. Put copyable commands in `sh` fences without prompts or inline explanatory comments; use `console` for transcripts and `text` for non-executable output. Explain uppercase kebab-case placeholders before use, quote paths correctly, and keep examples secret-free. Warn before commands that overwrite data, stop services, or delete resources, with scope, prerequisites, backup, and recovery caveats. Never hide risks or required steps in `<details>`.

Check documented commands, defaults, supported platforms, and behavior against source and the relevant release. Distinguish current stable behavior from unreleased changes on `main`; do not advertise pending capabilities as released. Architecture and migration guidance must explain component ownership, compatibility, persistent data, downtime, backups, and rollback limitations where relevant. Verify backup and restoration claims rather than promising unsupported recovery.

Give meaningful images descriptive alt text; decorative images may have empty alt text. Mermaid diagrams need adjacent prose explaining the same relationship. Use footnotes only for tangential context and task lists mainly in issue/PR templates. Write each ordinary prose paragraph on one physical source line; preserve blank lines, lists, tables, fences, intentional hard breaks, and other structured content.

### GitHub and Material rendering

Repository-facing Markdown uses GitHub-flavored Markdown. Reserve native blockquote alerts for information readers must notice: `NOTE`, `TIP`, `IMPORTANT`, `WARNING`, or `CAUTION`. Most pages need at most one or two; avoid consecutive alerts and routine commands wrapped as alerts. Put the first quoted prose line directly after the marker. Keep an empty quoted line only where needed to delimit a list, fence, or paragraph.

```text
> [!WARNING]
> Explain the risk and required action before the command.
```

The MkDocs Material site enables `pymdownx.quotes` with callout processing to render the same GitHub alert source as Material admonitions. Do not duplicate alerts using Material-only `!!!` syntax in shared pages, or introduce Material tabs, attributes, or directives into GitHub-facing pages that cannot render them. Use site-only syntax only where `mkdocs.yml` supports it and rendered review confirms it works.

Preserve Material navigation, system fonts, source-generated mkdocstrings reference, the midnight navy/sapphire palette with icy blue accents, and accessible component behavior. Keep exact, SHA-256-verified `requirements-docs.txt` dependencies and separate read-only build and Pages deployment jobs. PR documentation jobs must have no deployment permissions. Pages publishes `main` and release tags whose commits belong to `main`.

### Documentation validation

For Markdown changes run `make test-precommit` and `git diff --check`. Run `make docs` after changing guides, API signatures, or docstrings; it performs a strict site build with warnings treated as errors. Use `make docs-serve` for site preview when needed. Inspect GitHub-rendered Markdown and affected site pages, including tables, alerts, code, images, diagrams, anchors, and mobile layout.

Check changed local links and anchors explicitly. A Markdown lint or strict MkDocs build does not prove every external link works or every GitHub-only page renders correctly. Validate relevant external destinations when network access permits; report unavailable link/render checks rather than claiming coverage. The local documentation-style guide offers additional examples; report any contradiction with this file instead of importing external repository policy.

## Dependencies and workflows

Keep updates scoped to the authorized task. Use supported Action versions pinned to immutable full commit SHAs, with readable version comments; keep reusable workflow references pinned as well. Pin container bases by digest and retain exact dependency locks, integrity hashes, and hash-verified Python installs where supported. Do not describe package version floors or mutable tags as immutable pins. Keep synchronized Dockerfile and workflow pins aligned, and use the existing policy checks to verify them.

Grant minimum workflow permissions at the narrowest practical scope. Keep ordinary PR validation read-only and credential-free; isolate publishing, attestations, and Pages permissions to the jobs that need them. Do not expose secrets to untrusted PR code or weaken checks to make a build pass. Repository maintenance does not itself authorize workflow, security-setting, or deployment changes.

Workflow YAML uses two-space indentation; step names may use tasteful pirate-themed wording and emoji. Preserve Trivy scanning, Renovate rather than a competing Dependabot configuration, existing OpenSSF/best-practice metadata, and provenance/SBOM generation unless the task explicitly authorizes a justified change.

Preserve publishing policy: PRs validate without PIA credentials; live e2e is separately credentialed. Main/tag publishing builds all supported architectures. Git release tags use `v0.1.0`, while image semver tags omit `v`. Stable releases publish exact, minor, major, and `latest` aliases from one build; major zero omits a `0` alias. Prereleases publish only the exact version and `sha-*`, never movable aliases. Successful `main` builds publish `edge` and `sha-*`. These rules describe authorized publishing, not permission to trigger it.

## Validation

Select checks from the actual changed behavior and recipes. Report exact commands, results, and limits; do not replace a real test with a dry run. Tool-image builds and hook installation may require network access even when the subsequent suite runs offline.

| Change or check | Actual command | Boundary |
| --- | --- | --- |
| Target inventory | `make help` | No service startup |
| Markdown | `scripts/compose/test.sh markdown` | Buccaneerr; offline, read-only source after image build |
| All repository hooks | `make test-precommit` | Network, writable checkout, nested Docker access; hooks may fix files |
| Spelling | `make spellcheck` | Buccaneerr CSpell using project vocabulary |
| Guides, signatures, docstrings | `make docs` | Strict Material and API build; writes ignored `site/` output |
| Python and shell quality | `make lint` | Ruff lint/format, strict Pyright, ShellCheck |
| Strict Python types | `make test-types` | Pyright, not runtime validation |
| Full offline suite | `make test` | Lint/types, helpers, policies, actionlint, and unit tests; no PIA credentials |
| Make and Compose helpers | `make test-make-helpers` | Stubbed automation and cleanup boundaries |
| Workflow helpers and policy | `make test-workflows` | Fixture tests, pin/tag policy checks, actionlint |
| Recovery and generation units | `make test-recovery` | Python unit tests without PIA credentials |
| Real Gluetun API | `make test-recovery-api` | Docker socket and built `PRIVATEERR_TEST_IMAGE`; isolated real containers, no PIA credentials |
| Live PIA recovery | `make test-recovery-live` | Credentials and live VPN; explicit authorization required |
| Full application e2e | `make test-e2e` | Starts all four services, generates secrets, and injects a recovery fault by default |

Docker or workflow changes additionally require applicable image builds, Compose validation with a secret-free test environment, and architecture checks when affected. `make config` prints the rendered model and requires an environment file; do not capture real secrets in validation output.

Behavior changes affecting generation, Gluetun handoff, or forwarding warrant authorized live e2e coverage plus safe cleanup with `make clean-test` and verification of restored examples. If live testing is outside scope or credentials are unavailable, report the gap; never obtain or use production credentials merely to satisfy a checklist. Do not leave generated VPN config or metadata in the working tree.

## Handoff and review

Use a descriptive, lightly pirate-themed branch name; do not prefix it with `codex-` unless requested. Commit messages may use the project voice but must explain the change. PR descriptions lead with the concrete problem and resulting behavior, then give relevant validation and limitations.

Before handoff, review the complete diff and status, confirm only intended files are staged, check license and generated-file boundaries, and run `git diff --check`. Summarize changed files, checks passed/failed/not run, residual risks, and scope decisions truthfully. Provide the commit SHA and PR URL when created. Leave draft PRs for manual review when requested and clearly distinguish local validation from CI, rendered checks, and live credentialed coverage.
