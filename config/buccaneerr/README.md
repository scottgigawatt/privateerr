# Buccaneerr logs 🔎

The optional validator writes `logs/buccaneerr.log` here. Normal startup uses only the base Compose file. Including `docker-compose.test.yml` selects Buccaneerr for live validation and can deliberately interrupt the test VPN.

Inspect failures locally and sanitize excerpts before sharing. Logs are ignored by Git and may contain connection details. Follow the [test coverage and cleanup guide](../../docs/development/privateerr/testing.md) before running live checks.
