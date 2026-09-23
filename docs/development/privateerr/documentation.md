# Python documentation style 📚

Privateerr documentation should explain contracts and intent without duplicating the implementation. Type annotations remain the source of truth for types; docstrings describe meaning, side effects, invariants, and failure behavior.

## Document public APIs

Public modules, classes, methods, and functions use Google-style sections when they add useful information:

```python
def connection_settings(config: Path, metadata: Path) -> ConnectionSettings:
    """Build only connection fields so Gluetun preserves unrelated settings.

    Args:
        config: Generated WireGuard configuration to validate.
        metadata: PIA metadata naming the same endpoint and port.

    Returns:
        The minimal connection update accepted by Gluetun's control API.

    Raises:
        InvalidSettings: If required fields are missing, malformed, or inconsistent.
        OSError: If either source file cannot be read.
    """
```

Use `Args`, `Returns`, `Raises`, `Attributes`, or `Note` only when applicable. Do not add an empty section, restate a parameter name as its description, or repeat a type already expressed by the signature.

## Document private helpers

Private helpers are filtered out of the generated API reference, but they are not undocumented. Give every non-obvious helper a concise docstring that states its transformation or safety rule. Add inline comments at decision points where the reason cannot be inferred from the code.

Good private-helper documentation explains matters such as:

- Why startup readiness depends on saved files rather than tunnel health.
- Why an uncertain API response must be reconciled before another registration.
- Why a pending candidate is retained across process restarts.
- Why only connection fields are sent to Gluetun.
- Why health and catalog requests omit the control API key.

Avoid comments that merely translate the following expression into English.

## Use Markdown alerts sparingly

Write alerts once using GitHub's supported blockquote syntax:

```text
> [!IMPORTANT]
> Explain the required action here.
```

GitHub renders that syntax natively. MkDocs enables `pymdownx.quotes` with callout processing, which converts the same source into Material admonitions. The project stylesheet supplies Material treatments for GitHub's `important` and `caution` types. Do not duplicate alerts with MkDocs-only `!!!` syntax.

Reserve alerts for information whose meaning would materially change if the reader skipped it. Most pages should need no more than one or two. Put routine commands in ordinary `sh` fences, then put the first quoted prose line immediately below any alert marker without an empty `>` separator. Retain one empty quoted line when the alert begins with a fenced code block or list because Markdown requires it to delimit that block. Keep later empty quoted lines only where they intentionally separate paragraphs or blocks inside the alert. Write ordinary Markdown prose paragraphs on one physical source line and rely on visual editor wrapping.

> [!CAUTION]
> GitHub recognizes only `NOTE`, `TIP`, `IMPORTANT`, `WARNING`, and `CAUTION`. Other labels fall back to an ordinary blockquote instead of an alert.

## Preserve the generated reference boundary

The MkDocs configuration renders names that do not begin with `_`. This keeps the published reference focused on reusable interfaces while source links and the architecture guide preserve visibility into implementation details.

Run `make docs` after changing Python signatures or docstrings. Strict mode treats malformed cross-references, invalid navigation, and documentation warnings as build failures.
