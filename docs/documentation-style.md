# Documentation style ✍️

Every project-owned page must follow [GitHub Docs writing guidance](https://docs.github.com/en/contributing/writing-for-github-docs/best-practices-for-github-docs), its [style guide](https://docs.github.com/en/contributing/style-guide-and-content-model/style-guide), and the reader-centered principles of [ISO 24495-1:2023](https://www.iso.org/standard/78907.html). This project adopts both; GitHub does not require the ISO standard.

## Meet the reader's needs

Apply all four ISO outcomes during writing and review:

| Outcome | Required review |
| --- | --- |
| Relevant | Identify the audience and task. Include what readers need to complete it; remove unrelated detail. |
| Findable | Use task-based titles, useful navigation, and specific links. Put the main action and prerequisites first. |
| Understandable | Use familiar words, active voice, exact product labels, and explained abbreviations. |
| Usable | Give ordered steps, expected results, likely failures, and necessary recovery/backup limits. Evaluate the task path and revise it. |

Syntax checks cannot prove these outcomes. Do not claim certification or full ISO conformity from adopting these rules. Record reader evaluation and unresolved usability limits separately from lint/build results.

## Keep one owner for each topic

Before adding a page, check whether an existing page can answer the task. Replace duplicate explanations with short context and a specific link. Delete obsolete or unnecessary prose instead of moving it elsewhere solely to shorten a page. Do not target a word count at the expense of a necessary instruction.

Privateerr owns its image, configuration, recovery contract, and developer reference. Plundarr owns generated stack integration; Plundarrpedia owns broader deployment/platform guidance. Keep local guides self-contained for essential steps and safety.

Public prose may be lightly pirate-themed after the meaning is clear. Commands, UI labels, warnings, security/reporting instructions, destructive actions, and diagnostics stay literal. Preserve licensing, upstream attribution, security evidence, compatibility requirements, and backup limitations.

## Structure and format

Use one descriptive H1, sentence-case headings without skipped levels, and searchable words before decorative emoji. Procedures use numbered steps; choices use bullets; tables serve real comparisons. Keep required values and risks visible before commands.

Use GitHub-flavored Markdown and [GitHub's formatting syntax](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax). Label fences: `sh` for copyable commands without prompts/prose comments, `console` for transcripts, `text` for output. Explain placeholders. Use descriptive relative links locally and specific upstream destinations.

Write prose paragraphs on one physical source line. Keep structural blank lines, intentional hard breaks, readable narrow layouts, and meaningful image alt text. Use Mermaid only when it helps, with an equivalent adjacent explanation. Reserve details/footnotes for optional material; never hide prerequisites or risks.

Keep established convention filenames; ordinary articles use lowercase kebab-case. Preserve useful published routes and anchors. Update inbound links, navigation, and consumers when renaming.

## Use alerts sparingly

GitHub recognizes `NOTE`, `TIP`, `IMPORTANT`, `WARNING`, and `CAUTION`. Most pages need at most one or two. Keep required actions/risks in the alert; do not wrap routine commands or place alerts consecutively.

```text
> [!CAUTION]
> Explain the risk and required action before the command.
```

Put quoted prose directly after the marker. Use an empty quoted line only to separate meaningful paragraphs or delimit a list/fence.

Shared pages use native GitHub alerts; configured `pymdownx.quotes` renders them in Material. Keep Material-only tabs, attributes, and API directives on site-specific pages that support them.

## Verify the result

Follow the [documentation validation procedure](development/privateerr/testing.md#validate-documentation). Check current-source claims and label unreleased behavior. Inspect GitHub and Material rendering as applicable, changed links/anchors, commands, diagrams, alerts, and narrow layouts. Check that a reader can locate the task, understand required values, and recognize success/failure without following unrelated guides.

Preserve the local Material layout, accessibility, system fonts, and midnight navy/sapphire palette. Keep generated API reference in source docstrings and generated HTML ignored. Exact hash-verified documentation dependencies remain isolated in Buccaneerr's docs target; PR builds remain read-only and deployment stays separate.
