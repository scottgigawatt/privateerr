# Support 🛟

Choose the route that matches what you need so questions, defects, and security reports reach the right deck.

## Ask a usage question

Use the [🔥HADES🔥 Discord server](https://discord.gg/BpEGzWwGYf) for setup questions, Compose planning, and informal troubleshooting. Describe the image tag, host platform, command you ran, and whether you are generating files only or starting the Gluetun stack.

Redact PIA credentials, WireGuard keys, live `wg0.conf`, live `privateerr.env`, forwarded ports, private URLs, and sensitive logs before sharing anything.

## Recover a missing PIA submodule

If an image build reports that `pia-manual-connections/LICENSE` is missing, check whether the PIA scripts were checked out:

```sh
git submodule status -- docker/pia-manual-connections
```

A leading `-` means the submodule is uninitialized. Older checkouts used an SSH URL that required a GitHub SSH key, even when the parent repository was cloned over HTTPS. A failed recursive clone exits with an error but can leave the parent checkout behind.

After updating your checkout to the HTTPS fix, synchronize the saved submodule URL and fetch the pinned scripts:

```sh
git submodule sync --recursive
git submodule update --init --recursive
git submodule status -- docker/pia-manual-connections
```

If you need to keep an older Privateerr revision, override its saved URL locally instead:

```sh
git config submodule.docker/pia-manual-connections.url https://github.com/pia-foss/manual-connections.git
git submodule update --init --recursive
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
