# Privateerr 🏴‍☠️

Privateerr packages the unmodified [Private Internet Access (PIA) manual connection scripts](https://github.com/pia-foss/manual-connections) in a lightweight Docker image. Use it with Gluetun and qBittorrent to create a VPN-protected download stack. The Privateerr container creates a PIA WireGuard configuration file for the Gluetun VPN container. Gluetun runs the VPN connection, and Privateerr's built-in Python supervisor can refresh the configuration after a sustained outage.

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

## Start with the three-container stack

<!-- Keep emoji and short container names together in GitHub's table renderer. -->
<!-- markdownlint-disable MD033 -->
<table>
  <thead>
    <tr>
      <th scope="col" align="center" width="25%" nowrap>🐳 Container</th>
      <th scope="col" align="center" width="75%" nowrap>🧭 What it does</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td nowrap valign="middle">🏴‍☠️ <strong>Privateerr</strong></td>
      <td valign="middle">Creates the PIA WireGuard configuration file. Its built-in Python supervisor can refresh the configuration after a sustained VPN outage.</td>
    </tr>
    <tr>
      <td nowrap valign="middle">🛡️ <strong>Gluetun</strong></td>
      <td valign="middle">Runs the VPN tunnel, firewall, DNS, and PIA port forwarding.</td>
    </tr>
    <tr>
      <td nowrap valign="middle">⚓ <strong>qBittorrent</strong></td>
      <td valign="middle">Uses the Gluetun VPN container's connection for its network traffic.</td>
    </tr>
  </tbody>
</table>
<!-- markdownlint-enable MD033 -->

The quickstart below uses published images; you do not need to build an image. For a larger media stack, [Plundarr](https://scottgigawatt.github.io/plundarr/) generates the Compose project for you; [Plundarrpedia](https://scottgigawatt.github.io/plundarrpedia/) guides the wider setup.

<!-- markdownlint-disable-next-line MD033 -->
<a id="prepare-a-checkout"></a>
<!-- markdownlint-disable-next-line MD033 -->
<a id="start-privateerr-with-gluetun-"></a>

## Quickstart

You need an active PIA subscription, Git, Docker with Compose, and `openssl` to generate a private API key. The supplied stack supports amd64 and arm64 hosts. Assume Docker is installed and running before starting.

> [!WARNING]
> Keep `.env`, generated VPN files, backups, and container logs private. Use a new checkout for this setup; generation can replace saved VPN files in an existing deployment.

1. Clone the project and create your settings file:

    ```sh
    git clone --recurse-submodules https://github.com/scottgigawatt/privateerr.git
    cd privateerr
    cp example.env .env
    ```

2. Generate a key for the Privateerr container to communicate with the Gluetun VPN container:

    ```sh
    openssl rand -hex 24
    ```

3. Open `.env` in a text editor. Replace the example values for the settings below; keep other defaults for the first launch.

    | ⚙️ Setting | ✏️ What to enter |
    | --- | --- |
    | 🔐 `PIA_USER` and `PIA_PASS` | Your PIA VPN credentials. The username is `p` or `P` followed by seven digits, not your email address. |
    | 🔑 `PRIVATEERR_GLUETUN_API_KEY` | The key from step 2. |
    | 👤 `QBITTORRENT_PUID` and `QBITTORRENT_PGID` | The user and group IDs that should own qBittorrent's files; find them with `id -u` and `id -g` on the Docker host. |
    | 🕒 `QBITTORRENT_TZ` | Your time zone, such as `America/New_York`. |
    | 📂 `HOST_TORRENTS_DOWNLOADS_PATH` | Your host's downloads directory; the default is `./downloads/torrents`. |
    | 🔌 `QBITTORRENT_WEBUI_PORT` | Keep `8080` unless that host port is already used. |

    Keep `PIA_VPN_PROTOCOL=wireguard`, `PIA_CONNECT=false`, `PRIVATEERR_KEEPALIVE=true`, and `PRIVATEERR_AUTO_RECOVER=true`. The example selects a region that supports port forwarding. The Privateerr container and the Gluetun VPN container must mount the same host configuration directory, `config/gluetun/`. Keep their default directory settings for this first launch.

4. Check the Compose settings without printing credentials. Success produces no output:

    ```sh
    docker compose --env-file .env config --quiet
    ```

5. Pull the published images, then start the three containers. Run the second command only after the pull succeeds:

    ```sh
    docker compose --env-file .env pull privateerr gluetun qbittorrent
    docker compose --env-file .env up --detach --no-build --pull never privateerr gluetun qbittorrent
    ```

6. Check startup:

    ```sh
    docker compose ps
    docker compose logs --tail 100 privateerr
    ```

    Wait for Gluetun and qBittorrent to become healthy. Privateerr's logs should show `Automatic recovery enabled` and then `Gluetun tunnel is healthy`; monitoring begins after a startup grace period. The Privateerr container's healthy status means its configuration is ready for the Gluetun VPN container, so check Gluetun too. If startup fails, use the [diagnostics](https://scottgigawatt.github.io/privateerr/automatic-recovery/#read-diagnostics-and-check-storage).

7. Open [qBittorrent at localhost:8080](http://localhost:8080). If Docker runs on another computer or NAS, replace `localhost` with that host's address; use your chosen port if you changed it. Find the initial password locally:

    ```sh
    docker compose logs --tail 100 qbittorrent
    ```

    Sign in as `admin` with the temporary password from the logs, then change it in **Tools → Options → Web UI**. Keep the logs private. You have reached the first working setup when the VPN is healthy and you can sign in to qBittorrent.

Buccaneerr is an optional test container and stays out of this startup. To stop the stack while keeping its settings and downloads, run `docker compose down`.

<!-- markdownlint-disable-next-line MD033 -->
<a id="generate-a-wireguard-configuration-"></a>
<!-- markdownlint-disable-next-line MD033 -->
<a id="using-docker-directly"></a>

<!-- markdownlint-disable-next-line MD033 -->
<a id="create-a-vpn-configuration-file-only"></a>

## Create a PIA WireGuard configuration file

To use your own VPN client, [run the published Privateerr image once](https://scottgigawatt.github.io/privateerr/advanced-usage/#generate-without-make). The Privateerr container writes `wg0.conf`, the PIA WireGuard configuration file, and matching PIA metadata to the mounted host directory, then exits. Save any existing configuration files before reusing that directory, and do not run multiple Privateerr containers against it at the same time. Creating these files does not start a VPN tunnel.

## Choose your next step

- [Automatic recovery and region selection](https://scottgigawatt.github.io/privateerr/automatic-recovery/): understand the built-in supervisor or change a region.
- [Maintenance and images](https://scottgigawatt.github.io/privateerr/advanced-usage/): update, back up, stop, or choose an image channel.
- [Use Make or build locally](https://scottgigawatt.github.io/privateerr/advanced-usage/#use-make): optional shortcuts after the stack works.
- [Developer guides and Python reference](https://scottgigawatt.github.io/privateerr/development/privateerr/): architecture, tests, and source contracts.
- [Support](https://scottgigawatt.github.io/privateerr/SUPPORT/), [contributing](https://scottgigawatt.github.io/privateerr/CONTRIBUTING/), [security policy](https://scottgigawatt.github.io/privateerr/SECURITY/), and [Code of Conduct](https://scottgigawatt.github.io/privateerr/CODE_OF_CONDUCT/).

Privateerr is [Apache-2.0 licensed](LICENSE). PIA's unmodified scripts retain their [MIT license](https://github.com/pia-foss/manual-connections/blob/master/LICENSE).
