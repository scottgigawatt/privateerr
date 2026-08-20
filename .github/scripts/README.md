# Workflow Helper Chart ⚙️

These documented POSIX shell helpers keep reusable release, notification, and
registry logic out of workflow `run` blocks. Workflows provide metadata through
explicit long options and reserve environment variables for credentials.

## Helper Chart 🧭

| Helper                    | Purpose                                                            |
| ------------------------- | ------------------------------------------------------------------ |
| `discord-notifier.sh`     | Validate inputs, render a selected jq payload, and notify Discord  |
| `registry-mirror.sh`      | Copy published container tags from GHCR to Docker Hub              |
| `validate-release-tag.sh` | Require annotated SemVer release tags whose commits belong to main |

`discord-notifier.sh` reads the stable profiles, themed strings, presentation
values, and payload shapes documented in the
[Discord wardrobe](../discord/README.md). `registry-mirror.sh` verifies copied
manifest digests instead of trusting a successful transfer alone.

## Workflow Consumers 🧵

`build-and-push.yml` uses all three helpers for guarded multi-registry image
publication. The notifier also understands the shared documentation profile so
the same byte-identical helper and structured assets can serve repositories
that publish a documentation site.

## Offline Validation 🧪

Run the complete helper and publishing-policy suite without contacting Discord
or either container registry:

> [!TIP]
>
> ```sh
> make test-workflows
> ```

The suite uses temporary Git repositories, deterministic payload selection, and
a local Skopeo stub. It covers short and long options, release-tag rejection,
message rendering, registry mirroring, digest comparison, synchronized build
pins, and canonical image-tag channels.
