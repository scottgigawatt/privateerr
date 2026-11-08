# Discord build notifications

Workflow maintainers use this guide to configure optional Docker image and GitHub Pages notifications, edit copy, and preview messages locally.

## Configure destinations

You need permission to manage the intended Discord webhook and the repository’s Actions secrets. Keep webhook URLs out of files, command arguments, screenshots, and logs.

1. Create or select a webhook in the intended server and channel.
2. Confirm the server and channel in Discord; a secret name alone does not verify the destination.
3. In the repository’s **Settings → Secrets and variables → Actions**, store each optional webhook URL under the matching secret name below.
4. Follow [Preview without sending](#preview-without-sending) to inspect synthetic messages before a separately authorized live check.

| Profile | Destination | Repository Actions secret | Content |
| --- | --- | --- | --- |
| `image-primary` | Private Asteres | `DISCORD_WEBHOOK_URL` | Image notices with light gay culture humor |
| `image-secondary` | Public Hades | `DISCORD_HADES_HOOK_URL` | Image notices with light underworld humor |
| `docs` | Private Asteres | `DISCORD_WEBHOOK_URL` | GitHub Pages notices with light gay culture humor |

A missing webhook skips that destination. Each image and destination is reported independently. Delivery failures are visible in the notification step and do not change image publication results or prevent another destination from being attempted. Documentation notices remain separate from Docker image notices, even when both describe documentation products.

Start notices run independently of validation. Final image notices use the validation and publication results, including failures that prevent a publishing job from starting. Final documentation notices distinguish the site build from Pages deployment. Cancellation reporting is best effort: forced cancellation or runner loss can prevent a notification job from running.

## Review identities and colors

Sender names include the image name, `Image Builds`, and its destination-specific identity. Documentation sender names include the project name and `Docs`. Each image keeps one started color on both servers; joke selection never changes the color.

| Image | Asteres identity | Hades identity | Started color |
| --- | --- | --- | --- |
| Privateerr | Tunnel Werkroom | Styx Tunnel Authority | `#00C2FF` |
| Buccaneerr | Quality Queens | Cerberus Sniff Test | `#FF4FD8` |

The documentation sender is **Privateerr Docs • Read Me, Daddy**. Documentation starts use `#00C2FF`. Successful image publication and Pages deployment use green `#57F287`. Failures, timeouts, and startup failures use red `#ED4245`. Warnings, action-required results, and unrecognized outcomes use yellow `#FEE75C`. Cancelled, skipped, and neutral results use gray `#99AAB5`. Skipped jobs do not create extra standalone messages; their result can explain why a pipeline did not publish.

Privateerr publishes to GHCR and Docker Hub; the test-only Buccaneerr image publishes to GHCR only.

A successful image message requires a successful pipeline result, a successful push outcome, and a digest. Metadata calculated before a failed push is never labeled as published tags. A later failure retains evidence of a completed GHCR push and names the stage needing attention. Docker Hub mirror status is reported separately; a GHCR digest alone does not prove a successful mirror. Review the linked run before using a partially verified image.

## Validate notification tags

The published-tags field uses short tags such as `edge`, `sha-ABC123`, or `1.2.3`. [notification-tags.sh](../scripts/notification-tags.sh) accepts already-short tags or full references beginning with the exact expected image name followed by a colon. It preserves order and spelling, permits up to 128 ASCII characters per Docker tag, and rejects whitespace, digests, malformed tags, and references to another image. Blank lines are optional metadata. The whole list is validated before any output is printed; errors do not echo the rejected input.

The image workflow normalizes these notification tags before exporting them between jobs. Build and registry-mirror steps continue to receive full image references. Removing unnecessary owner and image prefixes reduces collisions with GitHub's secret filtering without disabling or bypassing that filtering. A short tag can still coincidentally match a configured secret. If optional tag metadata is unavailable, the notifier omits the tags field and retains a confirmed digest; it never invents a tag.

## Edit presentation and copy

| File | Responsibility |
| --- | --- |
| [themes.jq](themes.jq) | Project-specific identities, fixed colors, titles, footers, and joke variants |
| [payloads/common.jq](payloads/common.jq) | Factual descriptions, literal field labels, metadata limits, and mention policy |
| [image-start.jq](payloads/image-start.jq), [image-verdict.jq](payloads/image-verdict.jq) | Image payload entry points |
| [docs-start.jq](payloads/docs-start.jq), [docs-verdict.jq](payloads/docs-verdict.jq) | Documentation payload entry points |
| [discord-notifier.sh](../scripts/discord-notifier.sh) | Input validation, outcome classification, deterministic selection, and delivery |
| [notification-tags.sh](../scripts/notification-tags.sh) | Validate and shorten image tags before notification output boundaries |

1. Find the image and destination in `themes.jq`, or the `docs` definition for Pages messages.
2. Edit the applicable `jokes` array. Each supported outcome has two short variants. Keep each joke independent of operational facts.
3. Preserve the literal event title and factual first sentence. Use the workflow name only in the `Workflow` field, never as part of a sentence.
4. Render every changed variant using `--random-value 0` and `--random-value 1`, then run the helper suite.

Themes contain data rather than executable shell. No message tokens are expanded. Metadata is passed as quoted arguments to `jq`, mentions are disabled, and fields and descriptions are bounded to fit Discord limits. Registry fields appear only where applicable. Each repository maintains its own assets; themed content is intentionally different across projects.

## Preview without sending

Install a POSIX shell and `jq` for direct rendering. Use synthetic metadata only. `--dry-run` prints JSON without requiring a webhook or contacting Discord.

```sh
sh .github/scripts/discord-notifier.sh \
    --type image-start \
    --profile image-primary \
    --image-name Privateerr \
    --run-url https://example.invalid/run \
    --repository example/privateerr \
    --ref-name main \
    --ghcr-image ghcr.io/example/privateerr \
    --workflow-name "Example image workflow" \
    --random-value 0 \
    --dry-run
```

The result contains one embed with a descriptive started title, the image's fixed color, metadata fields, and an empty `allowed_mentions.parse` array. Changing `--profile` to `image-secondary` selects Hades copy while preserving the started color.

For a final image preview, use `--type image-verdict`, `--job-status`, and `--publication-status`. A successful preview also needs `--published-digest`; `--published-tags`, registry links, `--mirror-status`, and `--failure-stage` supply supporting evidence. Use the actual workflow step outcomes in automation, not a guessed status inferred from available tags.

For documentation previews, select `--profile docs` with `--type docs-start` or `--type docs-verdict`. A verdict needs `--build-status` and `--deploy-status`; `--site-url` adds the site link when available. Run `sh .github/scripts/discord-notifier.sh --help` for the complete interface.

## Diagnose delivery failures safely

Each request logs only a numeric HTTP status and curl exit code with fixed text, for example `Discord notification request finished: HTTP 204; curl exit 0.` Raw response bodies, headers, curl error text, webhook URLs, payloads, and tokens are never logged. An unavailable or malformed HTTP status is reported as `000`.

Use the codes to choose the next check. An HTTP error does not identify the rejected payload detail because response bodies remain private.

| Result | What to check |
| --- | --- |
| HTTP `400` with curl exit `22` | Review a synthetic payload and its metadata against Discord limits and required fields |
| HTTP `401` or `403` with curl exit `22` | Verify webhook access and permissions in Discord without sharing its URL |
| HTTP `404` with curl exit `22` | Verify that the existing webhook is still available |
| HTTP `429` with curl exit `22` | Wait before another authorized send; rebuilding the image does not resolve rate limits |
| HTTP `5xx` with curl exit `22` | Check Discord service availability before another authorized send |
| HTTP `000` | Use curl exit `6` for a name-resolution check, `7` for a connection check, or `28` for a timeout check |

A failed request returns its original curl exit code. Notification failures do not change build or publication results, and retries are not automatic.

## Validate and recover

Docker must be available for `make test-workflows`, which runs in the Buccaneerr test image. Preparing that image can need network access. The fixtures themselves use no live provider credentials and contact neither Discord nor a registry.

```sh
make test-workflows
```

To run only the notifier fixtures with a POSIX shell and `jq` on the host, use `sh test/helpers/test-discord-notifier.sh`.

The notifier fixtures cover every maintained image, destination, state, and joke variant; fixed colors; partial publication; missing evidence; metadata escaping and size limits; missing hooks; short-tag boundaries and atomic rejection; and sanitized HTTP/curl status reporting. Other workflow fixtures validate release policy and registry mirroring. These checks do not prove live Discord delivery or a healthy deployed application.

If a notification fails, inspect the notification step and linked publishing run. Check destination configuration, required metadata, and whether the run was cancelled. A delivery error alone is not a reason to rebuild or republish an image. Live test messages require explicit authorization.
