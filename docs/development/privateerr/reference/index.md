---
icon: material/language-python
---

# Python reference map 📚

These pages render public names directly from `docker/privateerr` using mkdocstrings. Type signatures and source links come from the same revision as the guides; do not maintain a second handwritten API listing.

| Module | Responsibility |
| :--- | :--- |
| [Configuration](config.md) | Environment validation and compatibility defaults |
| [HTTP client](client.md) | Bounded control requests, health checks, and catalog downloads |
| [JSON validation](data.md) | Runtime checks at dynamic data boundaries |
| [Connection settings](settings.md) | Validated connection objects and recoverable file publication |
| [Supervisor](supervisor.md) | Endpoint selection, generation, recovery decisions, and shutdown |

Names beginning with `_` are excluded from the generated reference. Public here means visible to developer documentation, not a promise of a separately supported library API. The deployment contract remains environment settings, generated files, and container behavior.
