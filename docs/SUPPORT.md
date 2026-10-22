# Support 🛟

Choose the route that matches what you need so questions, defects, and security reports reach the right deck.

## Ask a usage question

Use the [🔥HADES🔥 Discord server](https://discord.gg/BpEGzWwGYf) for setup questions, Compose planning, and informal troubleshooting. Describe the image tag, host platform, command you ran, and whether you are generating files only or starting the Gluetun stack.

Redact PIA credentials, WireGuard keys, live `wg0.conf`, live `privateerr.env`, forwarded ports, private URLs, and sensitive logs before sharing anything.

## Diagnose storage and recovery failures

Start with [recovery diagnostics](automatic-recovery.md#read-diagnostics-and-check-storage). Share the sanitized failure category, operation, numeric UID/GID and mode, image versions, and relevant volume mapping. Avoid posting full environment output or Gluetun settings responses, which can contain secrets. Report whether the message concerns startup, candidate generation, API application, or saving an already-applied candidate.

A healthy Privateerr container means startup configuration is ready for Gluetun. It does not prove the tunnel is healthy or that future recovery writes are possible. Region messages identify the configured VPN destination; redact them too if that preference is private.

## Recover a missing PIA submodule

If an image build reports that `pia-manual-connections/LICENSE` is missing, check whether the PIA scripts were checked out:

```sh
git submodule status -- docker/pia-manual-connections
```

A leading `-` means the submodule is uninitialized. Synchronize its HTTPS URL and fetch the pinned scripts:

```sh
git submodule sync --recursive
git submodule update --init --recursive
git submodule status -- docker/pia-manual-connections
```

Confirm `docker/pia-manual-connections/LICENSE` exists and the status no longer starts with `-`, then retry your build. These commands keep the upstream revision pinned by Privateerr; they do not update it to upstream's latest commit.

## Report a reproducible bug

Open a [Privateerr bug report](https://github.com/scottgigawatt/privateerr/issues/new?template=bug-report.md) when current source or a published image behaves incorrectly.

Include:

- The Privateerr, Gluetun, and Buccaneerr image tags involved.
- Your operating system, Docker version, and Docker Compose version.
- The exact command and a minimal reproduction.
- Whether `make config` succeeds.
- Sanitized logs or output.

## Request a documentation improvement

Open a [documentation request](https://github.com/scottgigawatt/privateerr/issues/new?template=documentation-enhancement.md) and identify the page, heading, command, or example that is unclear.

## Report a vulnerability

Do not use Discord or a public issue for vulnerability details. Follow the [security policy](SECURITY.md) and use GitHub private vulnerability reporting.

Privateerr is maintained by a small crew, so support is best effort. Clear reproductions and sanitized evidence make a safe answer much easier to chart.
