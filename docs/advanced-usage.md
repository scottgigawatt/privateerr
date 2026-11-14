# Maintenance and image reference 🧭

Use this guide after the [quickstart](https://github.com/scottgigawatt/privateerr/blob/main/README.md#quickstart). Run checkout commands from the repository root. [Create a PIA WireGuard configuration file](#generate-without-make) if you want to use another VPN client.

<a id="maintenance-reference"></a>

## Stop or update the stack

`docker compose down` stops the selected stack and removes its containers and network while keeping volumes, images, and bind-mounted configuration.

Before updating, back up `.env` and configuration as described below and check the image's [release notes](https://github.com/scottgigawatt/privateerr/releases), then repeat the quickstart's pull and startup commands for all three services together. This can interrupt traffic. Pulling an image alone does not update a running container.

The Privateerr container installs its Gluetun startup wrapper and qBittorrent forwarding hook into the shared `config/gluetun/scripts/` directory at startup. The two managed filenames are replaced; keep custom scripts under other names. The Privateerr container and Gluetun VPN container must mount the complete shared directory. UID 0 needs write and traverse access to it.

## Back up configuration

Archive `config/` with your host backup tools, or use `make backup` if Make is installed. The Make command does not stop writers or replace earlier archives. Stop relevant services first when you need a consistent archive. Protect it as secret-bearing data and verify the files you need are included.

The archive excludes `.env` and Docker-managed volumes. Preserve those separately when your recovery plan requires them. A config archive is not an application-aware database backup. There is no application-aware restore command: check ownership, destination paths, and application compatibility before restoring files.

## Read container logs

Use your container manager's log view, or run:

```sh
docker compose logs --tail 100 privateerr
```

Each record includes a UTC timestamp, severity, and source. `[privateerr]` identifies the Python supervisor; `[PIA/run_setup.sh]` includes that upstream script and its children. Redaction is best effort: inspect and sanitize excerpts before sharing. See [recovery diagnostics](automatic-recovery.md#read-diagnostics-and-check-storage) for failure categories.

> [!CAUTION]
> `make config`, `make env`, `make print-config`, and `make print-env` can expose credentials. For a syntax check without displaying them, use `docker compose --env-file .env config --quiet`.

## Use Make

Make is an optional shortcut for the same checkout. Run `make help` for the complete menu.

| Task | Command | Effect |
| --- | --- | --- |
| Start or update | `make up` | Pull published images and start Privateerr, Gluetun, and qBittorrent |
| Check status | `make ps` | Show container status |
| Read logs | `make logs` | Follow stack logs |
| Stop | `make down` | Preserve volumes and images |
| Build and start | `make up-build` | Build Privateerr locally; pull Gluetun and qBittorrent |
| Create VPN files from source | `make wireguard-config` | Build Privateerr, create the files once, and exit |

Local builds need Docker Buildx and the pinned PIA source submodule. From the checkout, initialize it before using a build command:

```sh
git submodule update --init --recursive
```

Use the [developer testing guide](development/privateerr/testing.md) for build validation and tests.

### Choose Compose files for development

Normal deployment needs only [`docker-compose.yml`](https://github.com/scottgigawatt/privateerr/blob/main/docker-compose.yml), which contains the three published runtime images and no build or test service. Optional files add local development tasks:

| Task | Files after `docker-compose.yml` | Image selection |
| --- | --- | --- |
| Run published images | None | Published Privateerr, Gluetun, and qBittorrent |
| Build Privateerr locally | `docker-compose.build.yml` | `privateerr:local` plus published Gluetun/qBittorrent |
| Validate published Privateerr | `docker-compose.test.yml` | Published runtime images plus locally built `buccaneerr:local` |
| Validate local Privateerr | `docker-compose.build.yml`, then `docker-compose.test.yml` | Locally built Privateerr and Buccaneerr plus published Gluetun/qBittorrent |

Pass the base file first and keep the same `.env` and project name for every combination. Make and direct Compose commands use `COMPOSE_PROJECT_NAME` from `.env` by default. If you explicitly set Make's `PRIVATEERR_COMPOSE_PROJECT_NAME` override, retain it for later commands and cleanup. Both overlays select local image names with `pull_policy: build`; they do not overwrite the published registry tags. Including the test file selects Buccaneerr without a profile and can deliberately interrupt the VPN. Follow the [live test procedure](development/privateerr/testing.md#validate-the-complete-example) before starting that combination.

`make up` uses the base file. `make up-build`, `make build`, and `make wireguard-config` use base plus build; `make build-test-image` uses base plus test; `make test-e2e` uses all three. `make down`, `make reset-test-stack`, and `make remove-stack` use the complete model so they include Buccaneerr and the local image references.

### Clean developer artifacts

`make clean-artifacts` removes disposable developer artifacts. It preserves deployments, `.env`, configuration, backups, containers, volumes, and images.

`make remove-stack` is a destructive reset for an explicitly disposable project. It removes that project's Docker containers, networks, volumes, eligible images, and scoped Buildx cache, then resets transient state and restores the checked-in VPN examples. It preserves `.env`, `backups/`, and persistent bind-mounted config, but example restoration replaces the VPN files. Back up needed state first. Shared or in-use base images are retained. Never use it to repair an active deployment.

<a id="restore-vpn-examples"></a>

### Restore test examples

Example restoration replaces `config/gluetun/wireguard/wg0.conf` and `privateerr.env`. It is not a backup restore. Use it only in a disposable test checkout after saving any VPN configuration files you need:

```sh
make reset-test-stack
```

This stops the selected stack using all three Compose files, including Buccaneerr, and restores examples only after shutdown succeeds. For separate control, run `make down`, wait for success, then `make restore-vpn-examples`. Never restore examples while a supervisor is writing those files or against an active deployment. Confirm that only example data remains before committing.

<a id="registry-publishing"></a>

## Choose an image channel

Privateerr is available from `ghcr.io/scottgigawatt/privateerr` and `docker.io/scottgigawatt/privateerr`. Use `latest` for the current stable release. Privateerr supports amd64, arm64, and arm/v7; the supplied qBittorrent stack supports amd64 and arm64.

| Channel | Use |
| --- | --- |
| `latest` | Current stable release |
| `edge` | Preview changes from a successful `main` build |
| Exact version | Select a release |
| `sha-<commit>` | Select a commit build |
| Image digest | Pin exact image contents |

Tags can move where policy allows; a digest fixes the exact contents. [Release requirements](CONTRIBUTING.md#release-tags) describe publishing aliases, mirrors, and attestations. The test-only Buccaneerr image publishes to GHCR. A passing vulnerability gate does not mean zero findings; see the [security policy](SECURITY.md).

## Generate without Make

This standalone route needs only Docker and an active PIA subscription. The published Privateerr image creates a PIA WireGuard configuration file for Gluetun or another compatible VPN client, then exits. The Privateerr container saves the files in a mounted directory so they remain on your host after the container exits. It does not start a tunnel or monitor it afterward.

1. Start in a new directory outside an existing deployment:

    ```sh
    mkdir privateerr-generation
    cd privateerr-generation
    umask 077
    touch .env
    ```

2. Open `.env` and replace these placeholders with your PIA VPN credentials. Docker's `--env-file` reads values literally: do not add shell quotes or copy the Compose-oriented `example.env`.

    ```dotenv
    PIA_USER=YOUR-PIA-VPN-USERNAME
    PIA_PASS=YOUR-PIA-PASSWORD
    ```

    The username is `p` or `P` followed by seven digits, not your email address. Keep this file private.

3. Run the published Privateerr image to generate the PIA WireGuard configuration file in the mounted directory. This replaces saved VPN files. Save any existing WireGuard configuration files before reusing the directory, and ensure no other Privateerr container is writing to it. The volume mount below maps the host's `config/gluetun` directory to `/gluetun` inside the Privateerr container.

    ```sh
    docker run --rm --pull always \
      --cap-drop ALL \
      --security-opt no-new-privileges:true \
      --env-file .env \
      --env VPN_PROTOCOL=wireguard \
      --env PIA_CONNECT=false \
      --env DISABLE_IPV6=no \
      --env DIP_TOKEN=no \
      --env AUTOCONNECT=true \
      --env PIA_PF=true \
      --env PIA_DNS=true \
      --env PRIVATEERR_AUTO_RECOVER=false \
      --env PRIVATEERR_KEEPALIVE=false \
      --volume "$(pwd)/config/gluetun:/gluetun" \
      ghcr.io/scottgigawatt/privateerr:latest
    ```

4. Confirm `Generation complete.` and that these files exist:

    | File | Purpose |
    | --- | --- |
    | `config/gluetun/wireguard/wg0.conf` | PIA WireGuard configuration file for the VPN client |
    | `config/gluetun/wireguard/privateerr.env` | Matching PIA server metadata for the Gluetun VPN container |

The Privateerr container exits without installing or changing Gluetun scripts. Docker creates missing shared directories; existing directories must permit UID 0 to write and traverse them with all capabilities dropped. Keep the output private, and follow your VPN client's instructions to use it.

### Generate from a checkout

After the quickstart's environment setup, use the same published Privateerr image through Compose. This also replaces saved VPN files: save any existing configuration files, stop the stack, and confirm no other Privateerr container is writing to the shared directory first:

```sh
docker compose --env-file .env run --rm --no-deps --pull always \
  --env PRIVATEERR_AUTO_RECOVER=false \
  --env PRIVATEERR_KEEPALIVE=false \
  --env PIA_CONNECT=false \
  --env VPN_PROTOCOL=wireguard \
  privateerr
```

<a id="start-without-make"></a>

## Start without Make

The [quickstart](https://github.com/scottgigawatt/privateerr/blob/main/README.md#quickstart) contains the complete published-image startup procedure. No Make installation or local build is needed.
