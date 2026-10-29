# Privateerr configuration ⚓

These directories hold persistent logs and shared VPN state. Treat them as sensitive; ignored runtime files must not enter commits or public reports.

| Directory | Owner and contents |
| --- | --- |
| [gluetun/](gluetun/README.md) | Shared VPN configuration, metadata, installed scripts, and Gluetun state |
| [privateerr/](privateerr/README.md) | Supervisor and upstream-generation logs |
| [buccaneerr/](buccaneerr/README.md) | Test-validator logs |

Generation and example restoration can replace VPN files. Stop their supervisor and preserve needed state first. Use [test-example restoration](../docs/advanced-usage.md#restore-vpn-examples) only in a disposable checkout, never in an active deployment.
