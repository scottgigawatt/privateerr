# Privateerr 🏴‍☠️

Privateerr generates [Private Internet Access (PIA)](https://www.privateinternetaccess.com/) WireGuard configuration and server metadata for Gluetun or another compatible VPN client. Its optional supervisor refreshes stale settings after sustained tunnel outages.

<!-- markdownlint-disable-next-line MD033 MD041 -->
<hr />

<!-- markdownlint-disable MD033 -->
<p align="center">
  <em>🦜 Parrot says: Found this useful? Drop a ⭐ an' help another crew find the map.</em>
</p>

<p align="center">
  <a href="https://github.com/scottgigawatt/privateerr/stargazers"><img src="https://img.shields.io/github/stars/scottgigawatt/privateerr?style=social&amp;label=Treasure%20Hunters" alt="GitHub stars: Treasure Hunters" /></a>
  <a href="https://github.com/scottgigawatt/privateerr/forks"><img src="https://img.shields.io/github/forks/scottgigawatt/privateerr?style=social&amp;label=Mutinous%20Forks" alt="GitHub forks: Mutinous Forks" /></a>
  <a href="https://github.com/scottgigawatt/privateerr/watchers"><img src="https://img.shields.io/github/watchers/scottgigawatt/privateerr?style=social&amp;label=Crow%27s%20Nest%20Lookouts" alt="GitHub watchers: Crow's Nest Lookouts" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Dockerized-Brig-2496ED?logo=docker&amp;logoColor=white" alt="Dockerized brig" />
  <img src="https://img.shields.io/badge/Cloaked-by%20PIA%20%26%20WireGuard-2EA44F?logo=wireguard&amp;logoColor=white" alt="Cloaked by PIA and WireGuard" />
  <a href="./LICENSE"><img src="https://img.shields.io/github/license/scottgigawatt/privateerr?label=Legal%20Scroll&amp;color=8250DF" alt="Legal Scroll: Apache 2.0 license" /></a>
</p>

<p align="center">
  <a href="https://github.com/scottgigawatt/privateerr/releases/latest"><img src="https://img.shields.io/github/v/release/scottgigawatt/privateerr?label=Latest%20Treasure%20Map&amp;logo=github&amp;color=BE123C" alt="Latest Privateerr release" /></a>
  <img src="https://img.shields.io/badge/Battle--Tested-Synology%20%7C%20macOS-0891B2" alt="Battle-tested on Synology and macOS" />
  <a href="https://www.bestpractices.dev/projects/13442"><img src="https://www.bestpractices.dev/projects/13442/badge" alt="OpenSSF Best Practices badge" /></a>
</p>

<p align="center">
  <a href="https://github.com/scottgigawatt/privateerr/actions/workflows/build-and-push.yml"><img src="https://img.shields.io/github/actions/workflow/status/scottgigawatt/privateerr/build-and-push.yml?branch=main&amp;label=Privateerr%20build&amp;logo=githubactions&amp;logoColor=white" alt="Privateerr build status on main" /></a>
  <a href="https://hub.docker.com/r/scottgigawatt/privateerr"><img src="https://img.shields.io/docker/pulls/scottgigawatt/privateerr?label=Privateerr%20pulls&amp;logo=docker&amp;logoColor=white&amp;color=FF69B4" alt="Privateerr image pulls on Docker Hub" /></a>
  <a href="https://github.com/scottgigawatt/privateerr/pkgs/container/privateerr"><img src="https://img.shields.io/badge/Fleet-amd64%20%7C%20arm64%20%7C%20arm%2Fv7-6D28D9?logo=docker&amp;logoColor=white" alt="Privateerr images for amd64, arm64, and arm/v7" /></a>
  <a href="https://github.com/scottgigawatt/privateerr/actions/workflows/build-and-push.yml"><img src="https://img.shields.io/badge/Bilge%20Check-Trivy-BE185D?logo=aqua&amp;logoColor=white" alt="Container images scanned with Trivy" /></a>
</p>

<p align="center">─── ⛧ ───</p>

<p align="center">
  <em>🕵️ VPN in Tartarus? Summon the network necromancers in</em>
  <a href="https://discord.gg/BpEGzWwGYf"><img src="https://img.shields.io/discord/1403601106315116626?label=%F0%9F%94%A5HADES%F0%9F%94%A5&logo=discord&logoColor=white&color=5865F2" alt="HADES Discord community" align="absmiddle" /></a>
</p>
<!-- markdownlint-enable MD033 -->

<!-- markdownlint-disable-next-line MD033 -->
<hr />

## Choose a task 🧭

- [Generate configuration only](#generate-a-wireguard-configuration-): use the repository, or [run Docker directly](#using-docker-directly) without Git or Make.
- [Run the supplied stack](#start-privateerr-with-gluetun-): start Privateerr, Gluetun, and qBittorrent with automatic recovery.
- [Develop or test Privateerr](docs/development/privateerr/testing.md): work on source without using a production deployment.

Gluetun owns the tunnel, firewall, DNS, and port lease. Privateerr generates settings and can refresh them after a sustained outage; it does not manage containers.

## Prepare a checkout

You need an active PIA subscription, Git, Make, and Docker with Compose. Source builds also need Buildx and the pinned PIA submodule. Run these commands from the directory where you want the checkout:

```sh
git clone --recurse-submodules https://github.com/scottgigawatt/privateerr.git
cd privateerr
cp example.env .env
```

Set `PIA_USER` and `PIA_PASS` in the private `.env`. Use your PIA VPN username (`p` or `P` followed by seven digits), not your email address. Keep `PIA_VPN_PROTOCOL=wireguard` and `PIA_CONNECT=false`. Review host paths, user/group IDs, time zone, and ports. The example enables port forwarding and selects an eligible region automatically.

> [!WARNING]
> Keep `.env`, generated VPN files, backups, and private logs out of Git and public reports. Generation replaces saved files; preserve needed state and stop any supervisor writing the destination first.

If a build reports a missing `pia-manual-connections/LICENSE`, [initialize the pinned submodule](docs/SUPPORT.md#recover-a-missing-pia-submodule).

## Generate a WireGuard configuration ⚡

In the current source (unreleased), setting both `PRIVATEERR_KEEPALIVE=false` and `PRIVATEERR_AUTO_RECOVER=false` selects one-shot generation without installing or changing Gluetun scripts. After preparing the checkout, run:

```sh
make run-privateerr
```

This builds the checked-out source and exits after writing:

| File | Purpose |
| --- | --- |
| `config/gluetun/wireguard/wg0.conf` | WireGuard configuration |
| `config/gluetun/wireguard/privateerr.env` | Matching PIA server metadata |

Confirm that the command exits successfully with `Generation complete.` and both files exist. File generation alone does not establish a working tunnel. Without Make, use the [published-image Compose command](docs/advanced-usage.md#generate-without-make).

### Using Docker directly

This route needs only Docker and an active PIA subscription. Start in a new directory outside an existing checkout or deployment:

```sh
mkdir privateerr-generation &&
  cd privateerr-generation &&
  umask 077 &&
  touch .env
```

Open `.env` and replace these placeholders with your PIA VPN username (`p` or `P` followed by seven digits) and password. Docker's `--env-file` reads values literally: do not add shell quotes or copy the Compose-oriented `example.env`:

```dotenv
PIA_USER=YOUR-PIA-VPN-USERNAME
PIA_PASS=YOUR-PIA-PASSWORD
```

> [!IMPORTANT]
> `latest` (2.3.1) still installs Gluetun scripts under `config/gluetun/scripts/`. The one-shot script isolation described above is unreleased and applies only to the current source.

Run generation from that directory. It replaces saved VPN files, so preserve any needed state and stop other writers first:

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

Docker creates missing shared directories. Existing directories must allow container UID 0 to write and traverse them with all capabilities dropped. Confirm `Generation complete.` and the two files listed above under `config/gluetun/wireguard/`. Keep the credential file and generated state private.

## Start Privateerr with Gluetun 🐳

The supplied stack requires amd64 or arm64 because of its qBittorrent image. Privateerr itself also supports arm/v7.

1. Complete the checkout and `.env` setup above.
2. Generate a shared recovery API key:

    ```sh
    openssl rand -hex 24
    ```

3. Set `PRIVATEERR_GLUETUN_API_KEY` in `.env` to that value. Review qBittorrent's storage paths, user/group IDs, and Web UI port.
4. Pull the published images and start the three services:

    ```sh
    make up
    ```

5. Check status and Privateerr's logs:

    ```sh
    make ps
    docker compose logs --tail 100 privateerr
    ```

Confirm `Automatic recovery enabled` and then `Gluetun tunnel is healthy`. Privateerr's container healthcheck proves startup readiness, not current tunnel health. Open qBittorrent on the configured host port (`8080` by default), obtain its initial password from local container logs, and change it in the Web UI. Keep those logs private.

Long-running Privateerr installs both integration scripts into the shared `config/gluetun/scripts/` directory before reporting ready, even with recovery disabled. No script copying is needed. UID 0 needs write and traverse access to the shared paths. The two installed filenames are replaced at startup; keep custom scripts under other names. Recreate all three services together when updating images.

Use `make up-build` for a source build; `make up-pull` aliases `make up`. [Direct Compose startup](docs/advanced-usage.md#start-without-make) is available without Make. Buccaneerr stays out of normal startup; its live tests deliberately interrupt a disposable VPN.

## Select a PIA region 🧭

Automatic selection is the default. To pin a region, set `PIA_AUTOCONNECT=false` and `PIA_PREFERRED_REGION=ca`, replacing `ca` with your chosen PIA region ID. Recovery-enabled startup reuses valid saved files; changing these values alone does not replace a healthy connection. Follow the [safe regeneration procedure](docs/automatic-recovery.md#choose-a-region).

## Find commands and image channels ⚙️

Use `make help` for commands and the [maintenance reference](docs/advanced-usage.md#maintenance-reference) for backup and cleanup boundaries. Use `latest` for stable releases or `edge` for successful `main` builds; see [image channels](docs/advanced-usage.md#registry-publishing) for exact tags and digests.

## Read more and get help 📚

- [Automatic recovery](docs/automatic-recovery.md): setup, diagnostics, timing, region changes, and limits.
- [Developer documentation](https://scottgigawatt.github.io/privateerr/): architecture, testing, and generated Python reference.
- [Plundarrpedia](https://scottgigawatt.github.io/plundarrpedia/): broader deployment and platform guides.
- [Support](docs/SUPPORT.md), [contributing](docs/CONTRIBUTING.md), [security policy](docs/SECURITY.md), and [Code of Conduct](docs/CODE_OF_CONDUCT.md).

Privateerr is [Apache-2.0 licensed](LICENSE). PIA's unmodified scripts retain their [MIT license](https://github.com/pia-foss/manual-connections/blob/master/LICENSE).

Fair winds, private keys below deck, and no VPN-client identity crises. 🏴‍☠️
