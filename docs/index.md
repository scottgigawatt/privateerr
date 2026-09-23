---
icon: material/ship-wheel
---

# Privateerr developer chart room 🏴‍☠️

Welcome aboard the developer documentation for **Privateerr** and its Python recovery supervisor. These charts explain how Privateerr generates PIA connection settings, hands them to Gluetun, and repairs sustained tunnel failures without adding another service.

## Choose a route 🧭

| Destination | Best for |
| :--- | :--- |
| [Supervisor overview](development/privateerr/index.md) | Understanding responsibilities and source layout |
| [Architecture](development/privateerr/architecture.md) | Following generation, API updates, and verified publication |
| [Python documentation](development/privateerr/documentation.md) | Writing useful public docstrings and implementation notes |
| [Testing](development/privateerr/testing.md) | Selecting the right validation voyage |
| [Python reference](development/privateerr/reference/index.md) | Looking up public classes and functions from source |
| [Automatic recovery](automatic-recovery.md) | Configuring a deployment and understanding its limits |

> [!NOTE]
> Privateerr generates and supervises connection settings. Gluetun owns the VPN tunnel, firewall, DNS, and forwarded port. Buccaneerr is the separate test image, not a production recovery service.

## Understand documentation boundaries 📚

This site owns code-adjacent developer documentation, repository guides, and the version-matched Python reference. Broader fleet guidance remains in [Plundarrpedia](https://scottgigawatt.github.io/plundarrpedia/); generated stack development belongs in the [Plundarr developer site](https://scottgigawatt.github.io/plundarr/).

The static HTML is generated during validation and deployment. Only Markdown sources, MkDocs configuration, styling, and pinned documentation dependencies belong in Git; the generated `site/` directory does not.
