<!--
  Copyright 2025-2026 Scott Gigawatt

  Licensed under the Apache License, Version 2.0.

  AGENTS.md: Contributor and AI-agent operating instructions for Privateerr.
  -->

# AGENTS.md

## Purpose and repository map

Privateerr packages the official, unmodified [PIA manual connection scripts](https://github.com/pia-foss/manual-connections) into a small Docker image that generates WireGuard configuration and Gluetun metadata. Privateerr is not a VPN client: Gluetun owns the tunnel and port lease. The optional standard-library Python supervisor renews stale PIA registrations through Gluetun's authenticated API without restarting containers.

The default Compose example starts Privateerr, Gluetun, and qBittorrent. The test-only Buccaneerr service requires the `test` profile and verifies forwarding, application settings, and recovery through a temporary firewall fault inside the shared VPN namespace. Web UI ports and API endpoints remain driven by environment settings.

| Path | Responsibility |
| --- | --- |
| `docker/` | Production image context, Python application, Gluetun scripts, date compatibility, and health checks |
| `docker/privateerr/` | Standard-library Python supervisor, API client, validation, persistence, and script installation |
| `docker/gluetun/` | Image-owned startup wrapper and qBittorrent forwarding hook, installed into shared configuration |
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

Keep production Python standard-library-only. Lint, formatting, typing, documentation, unit-test, and runtime-test dependencies belong in Buccaneerr, never the production Privateerr image or another deployed service. Documentation packages use Buccaneerr's optional `docs` target. The restricted repository-root build context admits only test sources and the docs lockfile. Keep documentation source mounts read-only and generated `site/` output ignored.

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

`.editorconfig` is the portable source of truth; VS Code settings, other editor settings, formatters, and automation must agree. Use UTF-8, LF endings, and final newlines. Use four spaces for shell, Python, JSON, and JSON with Comments; two spaces for Markdown, YAML, TOML, AWK, jq, CSS, and JavaScript; literal tabs for Make recipes and the established Git submodule declarations. Preserve intentional Markdown hard breaks.

Comments use plain English and explain intent, constraints, or non-obvious behavior. Do not narrate assignments or obvious syntax, add repetitive step labels, or use pirate language in code comments.

Project-owned scripts and config-style files start with a copyright line, Apache-2.0 license note, a short filename summary, and a short bullet list when usage or behavior needs context. Put one blank line after a shell shebang before that block. Align inline Compose comments within each logical group with at least two spaces before `#`.

Fix the cause of lint, typing, spelling, or security findings. Any necessary exception must be narrow, justified beside the affected code, and tied to a real runtime or test constraint. Do not weaken strict modes, exclude whole code areas, or add blanket suppressions to hide findings.

## Shell and Python quality

Keep implementation and tests consistent with the repository-owned checker configurations. Put a blank line before and after logical control-flow blocks, and place a concise explanatory comment above non-obvious checks, loops, and operations. Do not add comments that merely repeat the code.

### Shell

Host scripts prefer `#!/bin/sh`, POSIX syntax, and four-space indentation. Container-only scripts may use Bash when the image deliberately installs it and the entrypoint expects it. Quote expansions and paths, preserve failure status, and make cleanup explicit. Use direct diagnostic errors even when status messages use the project voice. `.shellcheckrc` supplies source resolution; use targeted ShellCheck suppressions only when a documented runtime constraint prevents a correct code fix.

Document each shell function immediately above its declaration using this exact documentation shape, with one parameter per comment line, one space after `Returns:`, and `Parameters: None.` when appropriate:

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

Python modules and tests start with the copyright, Apache-2.0, and filename summary block, followed by a useful module docstring. Prefer small functions, explicit types at application boundaries, standard-library facilities, validated dynamic input, narrowed optional values, and explicit collection and callback contracts. Avoid blanket `Any` annotations or broad exceptions that conceal errors.

`ruff.toml` owns lint and formatting rules, including import order, four-space indentation, and Unix line endings. Editors, pre-commit, and PR validation must use this same `ruff.toml` for both Ruff lint and format checks. Run both Ruff lint and format checks through `make lint`; that target also runs strict Pyright and ShellCheck. `pyrightconfig.json` covers all project-owned Python modules and tests, including optional fuzz harnesses. `make test-types` runs the pinned containerized checker; `make test`, pre-commit, and PR/main/release validation must enforce strict Python checking. Document any targeted diagnostic exception beside the intentional test or optional dependency.

Public modules, classes, methods, and functions use concise Google-style docstrings when useful. Explain contracts and intent without duplicating the implementation. Describe meaning, side effects, invariants, and failure behavior; type annotations remain the source of truth for types. Use `Args`, `Returns`, `Raises`, `Attributes`, and `Note` sections only when applicable. Do not add empty sections, restate a parameter name as its description, or repeat a type already expressed by the signature. Give every non-obvious private helper a concise docstring stating its transformation or safety rule, even though mkdocstrings filters names beginning with `_`. Add inline comments at decision points where the reason cannot be inferred from the code. Do not duplicate generated API reference by hand.

Explain the scenario and intent of Python tests with concise docstrings and comments around controlled fixtures, injected failures, cleanup, and meaningful assertion groups. Use blank lines to separate setup, actions, and verification where it improves readability. Explain why a boundary matters rather than narrating obvious assignments or adding repetitive step labels. Keep test tools out of published production images.

Run `make spellcheck` across project-owned files. Correct misspellings; genuine project vocabulary belongs in `.vscode/settings.json` under `cSpell.words`. Never add secrets or arbitrary whole strings to silence spelling diagnostics.

## Containers and deployment constraints

Primary deployment target: Synology DSM Container Manager. Secondary development target: macOS with Docker Desktop. Preserve one main `docker-compose.yml`; avoid runtime designs requiring multiple Compose files or application profiles. Reserve the `test` profile for optional Buccaneerr validation; application startup must not enable it.

Keep Privateerr deployments unprivileged with all Linux capabilities dropped and `no-new-privileges`. UID 0 remains necessary for the unmodified upstream scripts; do not equate UID 0 with permission to add privileged mode or capabilities. Docker owns initial namespace IPv6 settings; the Python generator skips redundant writes while preserving legacy image-only behavior.

Dockerfiles use architecture-neutral base images, OCI labels, and minimal required packages. Explain required packages with concise plain-English comments. Prefer Alpine unless a specific need justifies changing it. Do not hardcode architecture-specific image names. Preserve Buildx support for `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. Multi-architecture registry descriptions need index-level OCI annotations as well as Dockerfile labels. Attestation manifests may appear as `unknown/unknown`; they are metadata, not runnable images.

Compose conventions:

- Keep image names fixed where possible and image tags configurable through environment files.
- Put deployment defaults in `.env` / `example.env`, never interpolation fallbacks in Compose.
- Enable recovery in public deployment examples; preserve the recovery-disabled image-only default when no setting is supplied.
- Use YAML anchors for reusable labels and health checks; mount directories rather than individual generated files.
- Keep Privateerr and Gluetun mounting `./config/gluetun` for the generated-file handoff.
- Group environment settings by owner and purpose, list PIA variables before Privateerr wrapper variables, and keep `example.env` ordering aligned with Compose.

Keep `.env`, `example.env`, named environment examples, and service `environment.env` fragments focused on values. Reserve their end-of-line comments for settings operators must review or commonly customize: credentials, host paths, user/group IDs, time zones, and host-port conflicts. Use short action-oriented prompts such as `Edit before launch:`, `Edit for your host:`, or `Change only for a host-port conflict`. Generated secrets requiring no manual action need no inline comment. Keep useful section headings.

Put behavior explanations, accepted values, units, limits, dependencies between settings, and implementation details in aligned end-of-line comments beside the corresponding Compose entries. Explain numeric and boolean meanings where they are not obvious. For example, `1 disables IPv6; 0 enables IPv6`. Do not move routine per-variable explanations into standalone environment comments to bypass this division.

## Make and operational safety

Use `make help` and read the actual recipes before selecting a target. Keep reusable target names, service names, Docker Compose options, Docker Buildx options, reusable commands, and generated paths centralized near the top of the Makefile. Declare operational targets phony, preserve literal recipe tabs, quote path and value arguments, use `$$` for shell variables, and propagate failures rather than masking them. Test dependency ordering and cleanup with isolated helper fixtures. A dry run is a preview, not proof of safety or successful execution.

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
| `make up`, `make up-pull`, `make all` | Pull published images and start only Privateerr, Gluetun, and qBittorrent; require PIA credentials and operational authorization |
| `make up-build` | Pull Gluetun/qBittorrent, build Privateerr, and start the three services without pulling over the local image |
| `make run-privateerr` | Generate real VPN state; requires PIA credentials and operational authorization |
| `make down` | Stops the selected Compose project; preserves volumes and images |
| `make backup` | Archives the full config directory, potentially including secrets; protect and verify the archive |
| `make restore-test-config` | Overwrites generated VPN files with checked-in examples |
| `make clean-test` | Stops the selected stack and restores examples; use after authorized disposable e2e runs |
| `make clean` | Removes disposable developer artifacts only; must preserve deployment state, examples, containers, volumes, images, and `.env` |
| `make nuke` | Removes selected project Docker resources, repository-owned Buildx cache, and transient runtime state; restores examples and preserves `.env`, `backups/`, and persistent bind-mounted config |

Destructive targets require an explicitly disposable project, verified ownership boundaries, and authorization. Back up needed data first and understand the recovery path. Never use global Docker prune or delete unrelated resources. The `clean-test` recipe must complete profile-aware teardown before restoring examples, including under parallel Make execution. Never restore files while another writer is active.

## Documentation standards

Write for the intended reader and verify the result in each renderer that serves the page.

### Content and source conventions

Public Markdown is readable, useful, and lightly pirate-themed. Put operational meaning first; humor belongs in short introductions, transitions, sign-offs, templates, and suitable status output. Commands, paths, UI labels, warnings, security guidance, destructive actions, examples, and troubleshooting details remain literal and precise. Apply this voice to `README.md`, files under `docs/`, config-directory README files, GitHub issue and PR templates, and user-facing Makefile `echo` output when appropriate.

Identify the audience and the one or two outcomes the page must deliver. Put prerequisites before numbered procedures, follow execution order, move optional detail after the main path, verify the result, and cover likely failures. Concepts explain what something is, why it exists, and when it matters; quickstart guides give the shortest safe route to a useful result; how-to guides give prerequisites, numbered steps, verification, and likely failures; references present facts for lookup with consistent structure; troubleshooting names the symptom, explains the known cause, and gives a verifiable recovery path. State required versions, permissions, credentials, and platform constraints without including actual secrets.

Use active voice and address the reader as **you** in procedures. Put one main idea in each sentence and paragraph. Lead with the conclusion or required action, then explain why. Use the exact names shown in commands, files, services, and user interfaces. Spell out unfamiliar abbreviations on first use.

Use one page title and a logical sentence-case heading hierarchy without skipped levels; introduce a section before its subsections. Put searchable words before decorative emoji. Emoji must never carry meaning alone. Use numbered lists for procedures and bullets for unordered choices. Use simple readable tables only when readers need to compare multiple attributes. Keep blank lines around structural blocks and check narrow-screen layout.

Use descriptive relative links for repository-owned files and valid heading anchors; verify targets after heading or filename changes. Link to the most specific useful upstream page instead of a generic home page. Keep established convention filenames such as `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, and `SUPPORT.md`; ordinary articles use lowercase kebab-case. Update inbound Markdown links, workflow paths, scripts, and published descriptions in the same authorized rename change.

Every fenced block has an appropriate language label. Put copyable commands in `sh` fences without prompt characters or comments; use `console` for transcripts and `text` for non-executable output. Explain uppercase kebab-case placeholders before use, quote paths correctly, and keep examples secret-free. Warn before commands that overwrite data, stop services, or delete resources, with scope, prerequisites, backup, and recovery caveats. Use `<details>` only for optional sample output or lengthy diagnostics; never hide prerequisites, primary steps, or risks there.

Check documented commands, defaults, supported platforms, and behavior against the current branch. Describe how that branch works; keep migration narratives, historical feature comparisons, and repeated documentation/image-version matching pointers out of current guides. Preserve necessary current compatibility requirements, support policies, and image-channel reference. Architecture and operational guidance must explain component ownership, persistent data, downtime, backups, and recovery limits where relevant. Verify backup and restoration claims rather than promising unsupported recovery.

Give meaningful images descriptive alt text; decorative images may have empty alt text. Use Mermaid only when it materially clarifies a relationship or sequence, and provide adjacent prose explaining the same information. Use footnotes only for tangential provenance or context; essential information stays inline. Keep task lists in issue and PR templates; static procedures use numbered steps. Write each ordinary prose paragraph on one physical source line; preserve blank lines, lists, tables, fences, intentional hard breaks, and other structured content.

### GitHub and Material rendering

Repository-facing Markdown uses GitHub-flavored Markdown. Reserve native blockquote alerts for information readers must notice while scanning: `NOTE` adds useful context, `TIP` makes a task easier, `IMPORTANT` states information required for success, `WARNING` calls for immediate attention, and `CAUTION` describes a risk or destructive outcome. Other labels render as ordinary blockquotes rather than GitHub alerts. Keep required actions and risk descriptions in the alert itself. Most pages need at most one or two; avoid consecutive alerts and routine commands wrapped as alerts. Put the first quoted prose line directly after the marker. Keep an empty quoted line only where needed to delimit a list, fence, or paragraph.

```text
> [!WARNING]
> Explain the risk and required action before the command.
```

The MkDocs Material site enables `pymdownx.quotes` with callout processing to render the same GitHub alert source as Material admonitions. Do not duplicate alerts using Material-only `!!!` syntax in shared pages, or introduce Material tabs, attributes, or directives into GitHub-facing pages that cannot render them. Use site-only syntax only where `mkdocs.yml` supports it and rendered review confirms it works.

Preserve the local Material layout and component styling, navigation, system fonts, source-generated mkdocstrings reference, the midnight navy/sapphire palette with icy blue accents, and accessibility behavior defined by `mkdocs.yml` and `docs/assets/stylesheets/extra.css`. Keep exact, SHA-256-verified `requirements-docs.txt` dependencies and separate read-only build and Pages deployment jobs. PR documentation jobs must have no deployment permissions. Pages publishes `main` and release tags whose commits belong to `main`.

### Documentation validation

For Markdown changes run `make test-precommit` and `git diff --check`. Run `make docs` after changing guides, API signatures, or docstrings; it performs a strict site build with warnings treated as errors. Use `make docs-serve` for site preview when needed. Inspect GitHub-rendered Markdown and affected site pages, including tables, alerts, code, images, diagrams, anchors, and mobile layout.

Check changed local links and anchors explicitly. A Markdown lint or strict MkDocs build does not prove every external link works or every GitHub-only page renders correctly. Validate relevant external destinations when network access permits; report unavailable link/render checks rather than claiming coverage. Follow the [local documentation-style guide](docs/documentation-style.md) and [Python documentation conventions](docs/development/privateerr/documentation.md) where consistent with these self-contained requirements. This AGENTS.md governs any conflict; report contradictions and do not import another repository's policy through a local guide.

## Dependencies and workflows

Keep updates scoped to the authorized task. Use current major versions of GitHub Actions where practical, pinned to immutable full commit SHAs with readable version comments; keep reusable workflow references pinned as well. Pin container bases by digest and retain exact dependency locks, integrity hashes, and hash-verified Python installs where supported. Do not describe package version floors or mutable tags as immutable pins. Keep synchronized Dockerfile and workflow pins aligned, and use the existing policy checks to verify them.

Grant minimum workflow permissions at the narrowest practical scope. Keep ordinary PR validation read-only and credential-free; isolate publishing, attestations, and Pages permissions to the jobs that need them. Do not expose secrets to untrusted PR code or weaken checks to make a build pass. Repository maintenance does not itself authorize workflow, security-setting, or deployment changes.

All project-owned YAML, including GitHub Actions workflows, uses two-space indentation. Workflow step names should be pirate-themed and include tasteful emoji. Preserve Trivy scanning and provenance/SBOM generation unless the task explicitly authorizes a justified change. Keep Renovate configuration and existing OpenSSF/best-practice metadata current; do not add a competing Dependabot configuration.

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

For Docker or workflow changes, run `make help`, `make config`, `make build`, `make build-buccaneerr`, `make build-platforms`, `make test`, `make test-workflows`, and `make test-precommit` as applicable. Validate Compose with a secret-free test environment and check architectures when image dependencies or build stages change. `make config` prints the rendered model and requires an environment file; do not capture real secrets in validation output.

Behavior changes affecting generation, Gluetun handoff, or forwarding warrant authorized live e2e coverage plus safe cleanup with `make clean-test` and verification of restored examples. If live testing is outside scope or credentials are unavailable, report the gap; never obtain or use production credentials merely to satisfy a checklist. Do not leave generated VPN config or metadata in the working tree.

## Handoff and review

Use descriptive, funny, lightly pirate-themed branch names; do not prefix them with `codex-` unless explicitly requested. Commit messages may be funny and pirate-themed, with emoji, but must still describe the change. PR descriptions lead with the main functional change and explain the concrete problem and resulting behavior, then summarize quality-of-repo improvements concisely and give relevant validation and limitations.

Before handoff, review the complete diff and status, confirm only intended files are staged, check license and generated-file boundaries, and run `git diff --check`. Summarize changed files, checks passed/failed/not run, residual risks, and scope decisions truthfully. Provide the commit SHA and PR URL when created. Leave draft PRs for manual review when requested and clearly distinguish local validation from CI, rendered checks, and live credentialed coverage.
