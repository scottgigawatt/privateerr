# Discord Notification Wardrobe 🎭

One generic helper renders image-build and documentation notifications from
reviewable data files. Workflow metadata remains command-line data, the webhook
remains the only secret environment value, and no message pack is sourced or
evaluated as shell code.

## Wardrobe Chart 🧵

| Path                             | Purpose                                                                                           |
| -------------------------------- | ------------------------------------------------------------------------------------------------- |
| `themes.jq`                      | Stores every theme, presentation value, and randomized message behind stable destination profiles |
| `payloads/*.jq`                  | Defines the Discord JSON embed shape for each notification type                                   |
| `../scripts/discord-notifier.sh` | Validates inputs, selects copy, renders JSON, and delivers or prints the payload                  |

Workflows select the stable `image-primary`, `image-secondary`, or `docs`
profile rather than a creative theme name. Today those profiles wear the
shamelessly gay Rainbow Werkroom, Infernal Helpdesk, and Greek-mythology
Olympian Oracle themes. Replacing a theme later requires editing only
`themes.jq`; filenames, workflows, and helper arguments stay unchanged.

## Editing Copy 💄

Each notification and outcome in `themes.jq` owns a `messages` array beside its
title, footer, color, and labels. Add complete JSON strings to the applicable
array, preserving the two-space indentation and trailing commas between items.

Supported literal tokens are:

- `{{workflow_name}}`
- `{{job_status}}`
- `{{build_status}}`
- `{{deploy_status}}`

The notifier substitutes these values through `jq`; it never uses `eval`,
sources a message file, or treats workflow metadata as executable content.

## Testing Payloads 🧪

Use `--random-value` with `--dry-run` to select deterministic copy and print the
public JSON payload without requiring or contacting a webhook. The offline
workflow-helper suite exercises every supported profile and outcome:

> [!TIP]
>
> ```sh
> make test-workflows
> ```
