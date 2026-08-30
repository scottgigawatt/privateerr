# Documentation style ✍️

Privateerr documentation should help readers complete a task or understand a boundary without making them decode the theme first. Keep the operational meaning plain and let the pirate voice add a little character around it.

## Start with the reader

Before writing, identify the audience and the one or two outcomes the page must deliver. Put prerequisites before procedures, order steps as readers perform them, and move optional detail after the main path.

Use these content shapes:

- **Concept:** Explain what something is, why it exists, and when it matters.
- **Quickstart:** Give the shortest safe route to a useful result.
- **How-to:** State the outcome, list prerequisites, provide numbered steps, verify the result, and cover likely failures.
- **Reference:** Present facts for lookup with consistent headings, lists, or genuinely comparative tables.
- **Troubleshooting:** Name the symptom, explain the cause when known, and give a verifiable recovery path.

## Write plainly first

- Use active voice and address the reader as **you** in procedures.
- Put one main idea in each sentence and paragraph.
- Lead with the conclusion or required action, then explain why.
- Use the exact names shown in commands, files, services, and user interfaces.
- Spell out an unfamiliar abbreviation on first use.
- Keep ordinary prose paragraphs on one physical source line and use visual editor wrapping.

Pirate language belongs in short introductions, transitions, and sign-offs. Commands, paths, warnings, security guidance, destructive actions, and troubleshooting instructions stay literal. A joke should never carry operational meaning.

## Make headings searchable

Use sentence case and put the useful keyword first. Emoji may follow a heading as decoration, but it must not replace a word or warning.

- Prefer `## Generate a WireGuard configuration ⚡` over `## Fastest Path`.
- Prefer `## Inspect environment values 🔎` over `## Inspect The Knobs`.
- Do not skip heading levels.
- Introduce a section before adding a subsection.

## Format for the task

- Use numbered lists for procedures and bullets for unordered choices.
- Use tables only when readers need to compare multiple attributes.
- Keep commands in `sh` fences without prompt characters or comments.
- Put terminal transcripts in `console` fences and non-executable output in `text` fences.
- Use uppercase kebab-case placeholders such as `YOUR-REGION` and explain what replaces them.
- Use descriptive link text and relative links for repository-owned pages.
- Link to the most specific useful upstream page instead of a generic home page.

## Reserve alerts for critical information

GitHub alerts are for information readers must notice while scanning. Most pages should need no more than one or two.

- `[!NOTE]` adds useful context.
- `[!TIP]` makes a task easier.
- `[!IMPORTANT]` states information required for success.
- `[!WARNING]` calls for immediate attention.
- `[!CAUTION]` describes a risk or destructive outcome.

Do not wrap routine commands in alerts. Do not place alerts back to back. Keep required actions and risk descriptions in the alert itself.

## Use advanced Markdown deliberately

- Use `<details>` only for optional sample output or lengthy diagnostics. Never hide prerequisites, primary steps, or risks.
- Use footnotes only for tangential provenance or context. Essential information stays inline.
- Use Mermaid when a relationship or sequence is materially clearer as a diagram. Provide adjacent prose that communicates the same information.
- Keep task lists in issue and pull request templates. Static procedures use numbered steps.

## Name files consistently

Keep GitHub and project convention files in their established form, including `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, and `SUPPORT.md`. Name ordinary articles with lowercase kebab-case, such as `advanced-usage.md`.

When renaming a page, update inbound Markdown links, workflow paths, scripts, and published descriptions in the same change.

## Review the rendered result

Before publishing documentation:

1. Check commands, paths, defaults, and examples against the current source.
2. Read the page in rendered GitHub Markdown.
3. Verify diagrams, tables, alerts, anchors, and narrow-screen readability.
4. Run `pre-commit run --all-files` and inspect `git diff --check`.
5. Confirm no credentials, generated WireGuard state, private logs, or deployment-specific values entered the change.

## Read the source guidance

- [GitHub's basic writing and formatting syntax](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)
- [GitHub's advanced formatting guide](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting)
- [GitHub's README guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes)
- [GitHub's contributor-guideline guidance](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors)
