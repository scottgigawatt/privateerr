# Python documentation style 📚

Document contracts and intent. Type annotations own types; docstrings explain meaning, side effects, invariants, and failure behavior. General prose and Markdown follow the mandatory [documentation standards](../../documentation-style.md).

## Document public APIs

Use Google-style sections only when they add useful information:

```python
def connection_settings(config: Path, metadata: Path) -> ConnectionSettings:
    """Build connection fields while preserving unrelated Gluetun settings.

    Args:
        config: WireGuard configuration to validate.
        metadata: PIA metadata naming the same endpoint and port.

    Returns:
        The connection update accepted by Gluetun's control API.

    Raises:
        InvalidSettings: If fields are missing, malformed, or inconsistent.
        OSError: If either source file cannot be read.
    """
```

Use `Args`, `Returns`, `Raises`, `Attributes`, and `Note` where applicable. Omit empty sections, repeated signature types, and descriptions that merely restate parameter names.

Indent continuation lines in `Returns` and `Yields` four spaces beyond the first description line so the renderer does not create separate table entries. For context managers, describe the yielded value and lifetime. Supply the element type when needed to avoid displaying the generator container as the yielded type, and inspect the rendered table.

## Explain non-obvious private helpers

State the transformation or safety rule, such as why uncertain API updates must be reconciled before another registration. Add comments at decisions whose reason is unclear from the code. Avoid translating expressions into prose.

## Preserve generated reference

Mkdocstrings renders names that do not begin with `_`. Keep API reference in source docstrings instead of maintaining a handwritten duplicate. Public documentation visibility is not a separately supported library API.

Run `make docs` after changing signatures or docstrings, then inspect generated tables and cross-references. Strict compilation detects warnings; it does not establish plain-language usability.
