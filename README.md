# Privateerr 🏴‍☠️

Privateerr packages the unmodified [Private Internet Access (PIA) manual connection scripts](https://github.com/pia-foss/manual-connections) in a lightweight Docker image. Use it with Gluetun and qBittorrent to create a VPN-protected download stack. The Privateerr container creates a PIA WireGuard configuration file for the Gluetun VPN container. Gluetun runs the VPN connection, and Privateerr's built-in Python supervisor can refresh the configuration after a sustained outage.

<!-- markdownlint-disable-next-line MD033 MD041 -->
<hr />

<!-- markdownlint-disable MD033 -->
<p align="center">
  <em>🦜 Parrot says: Found this useful? Drop a ⭐ an' help another crew find the map.</em>
</p>

<p align="center">
  <a href="https://github.com/scottgigawatt/privateerr/stargazers"><img src="https://img.shields.io/github/stars/scottgigawatt/privateerr?label=Treasure%20Hunters&amp;style=social&amp;logo=github&amp;logoColor=181717" alt="GitHub stars: Treasure Hunters" /></a>
  <a href="https://github.com/scottgigawatt/privateerr/forks"><img src="https://img.shields.io/github/forks/scottgigawatt/privateerr?label=Mutinous%20Forks&amp;style=social&amp;logo=github&amp;logoColor=181717" alt="GitHub forks: Mutinous Forks" /></a>
  <a href="https://github.com/scottgigawatt/privateerr/watchers"><img src="https://img.shields.io/github/watchers/scottgigawatt/privateerr?label=Crow%27s%20Nest%20Lookouts&amp;style=social&amp;logo=github&amp;logoColor=181717" alt="GitHub watchers: Crow&#x27;s Nest Lookouts" /></a>
  <a href="https://github.com/scottgigawatt/privateerr/releases/latest"><img src="https://img.shields.io/github/v/release/scottgigawatt/privateerr?label=Latest%20Treasure%20Map&amp;style=social&amp;logo=github&amp;logoColor=181717" alt="Latest Privateerr release" /></a>
</p>

<p align="center">
  <a href="./LICENSE"><img src="https://img.shields.io/github/license/scottgigawatt/privateerr?label=Legal%20Scroll&amp;style=flat&amp;logo=apache&amp;logoColor=white&amp;color=D7263D&amp;labelColor=D7263D" alt="Legal Scroll: Apache 2.0 license" /></a>
  <a href="https://github.com/scottgigawatt/privateerr/commits/main"><img src="https://img.shields.io/github/last-commit/scottgigawatt/privateerr?label=Last%20Plunder&amp;style=flat&amp;logo=git&amp;logoColor=white&amp;color=C45100&amp;labelColor=C45100" alt="Date of the last commit to main" /></a>
  <a href="https://github.com/scottgigawatt/privateerr"><img src="https://img.shields.io/github/repo-size/scottgigawatt/privateerr?label=Cargo%20Hold&amp;style=flat&amp;logo=github&amp;logoColor=white&amp;color=8C6900&amp;labelColor=8C6900" alt="Repository size" /></a>
</p>

<p align="center">
  <a href="https://github.com/scottgigawatt/privateerr/actions/workflows/validate-pr.yml"><img src="https://img.shields.io/github/actions/workflow/status/scottgigawatt/privateerr/validate-pr.yml?label=PR%20Inspection&amp;event=pull_request&amp;style=flat&amp;logo=githubactions&amp;logoColor=white&amp;color=527C00&amp;labelColor=527C00" alt="Latest pull-request validation status" /></a>
  <a href="https://github.com/scottgigawatt/privateerr/actions/workflows/codeql-actions.yml"><img src="https://img.shields.io/github/actions/workflow/status/scottgigawatt/privateerr/codeql-actions.yml?label=CodeQL&amp;branch=main&amp;style=flat&amp;logo=githubactions&amp;logoColor=white&amp;color=16823B&amp;labelColor=16823B" alt="CodeQL on main" /></a>
  <a href="https://www.bestpractices.dev/projects/13442"><img src="https://img.shields.io/cii/summary/13442?label=OpenSSF%20Best%20Practices&amp;style=flat&amp;logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI%2BPHBhdGggZmlsbD0id2hpdGUiIGQ9Ik0xMiAyIDMgNnY2YzAgNSA0IDggOSAxMCA1LTIgOS01IDktMTBWNnptLTEgMTQtNC00IDItMiAyIDIgNC00IDIgMnoiLz48L3N2Zz4%3D&amp;logoColor=white&amp;color=008271&amp;labelColor=008271" alt="OpenSSF Best Practices badge" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Dockerized-Brig-007D9C?style=flat&amp;logo=docker&amp;logoColor=white&amp;color=007D9C&amp;labelColor=007D9C" alt="Dockerized brig" />
  <img src="https://img.shields.io/badge/Battle--Tested-Synology%20%7C%20macOS-007D9C?style=flat&amp;logo=synology&amp;logoColor=white&amp;color=007D9C&amp;labelColor=007D9C" alt="Battle-tested on Synology and macOS" />
  <img src="https://img.shields.io/badge/Cloaked-by%20PIA%20%26%20WireGuard-116DB4?style=flat&amp;logo=wireguard&amp;logoColor=white&amp;color=116DB4&amp;labelColor=116DB4" alt="Cloaked by PIA and WireGuard" />
</p>

<p align="center">
  <a href="https://github.com/scottgigawatt/privateerr/actions/workflows/build-and-push.yml"><img src="https://img.shields.io/github/actions/workflow/status/scottgigawatt/privateerr/build-and-push.yml?branch=main&amp;label=Privateerr%20build&amp;style=flat&amp;logo=githubactions&amp;logoColor=white&amp;color=3152C7&amp;labelColor=3152C7" alt="Privateerr build status on main" /></a>
  <a href="https://github.com/scottgigawatt/privateerr/actions/workflows/pages.yml"><img src="https://img.shields.io/github/actions/workflow/status/scottgigawatt/privateerr/pages.yml?label=Docs%20deploy&amp;branch=main&amp;style=flat&amp;logo=githubactions&amp;logoColor=white&amp;color=5138B6&amp;labelColor=5138B6" alt="Documentation deployment status on main" /></a>
  <a href="https://hub.docker.com/r/scottgigawatt/privateerr"><img src="https://img.shields.io/docker/pulls/scottgigawatt/privateerr?label=Privateerr%20pulls&amp;style=flat&amp;logo=docker&amp;logoColor=white&amp;color=7C3BB3&amp;labelColor=7C3BB3" alt="Privateerr image pulls on Docker Hub" /></a>
</p>

<p align="center">
  <a href="https://github.com/scottgigawatt/privateerr/pkgs/container/privateerr"><img src="https://img.shields.io/badge/Fleet-amd64%20%7C%20arm64%20%7C%20arm%2Fv7-A32BA3?style=flat&amp;logo=docker&amp;logoColor=white&amp;color=A32BA3&amp;labelColor=A32BA3" alt="Privateerr images for amd64, arm64, and arm/v7" /></a>
  <a href="https://github.com/scottgigawatt/privateerr/actions/workflows/build-and-push.yml"><img src="https://img.shields.io/badge/Bilge%20Check-Trivy-C42878?style=flat&amp;logo=aqua&amp;logoColor=white&amp;color=C42878&amp;labelColor=C42878" alt="Container images scanned with Trivy" /></a>
</p>

<p align="center">─── ⛧ ───</p>

<p align="center">
  <em>🕵️ VPN in Tartarus? Summon the network necromancers in</em>
  <a href="https://discord.gg/BpEGzWwGYf"><img src="https://img.shields.io/discord/1403601106315116626?label=%F0%9F%94%A5HADES%F0%9F%94%A5&amp;style=flat&amp;logo=discord&amp;logoColor=white&amp;color=D62F65&amp;labelColor=D62F65" alt="HADES Discord community" align="absmiddle" /></a>
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

    <!-- Keep each variable name and its emoji together in GitHub's table renderer. -->
    <!-- markdownlint-disable MD033 -->
    <table>
      <thead>
        <tr>
          <th scope="col" align="center" width="25%" nowrap>⚙️ Setting</th>
          <th scope="col" align="center" width="75%" nowrap>✏️ What to enter</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td nowrap valign="middle">🔐 <samp>PIA_USER</samp></td>
          <td valign="middle">Your PIA VPN username: <code>p</code> or <code>P</code> followed by seven digits, not your email address.</td>
        </tr>
        <tr>
          <td nowrap valign="middle">🔒 <samp>PIA_PASS</samp></td>
          <td valign="middle">Your PIA VPN password.</td>
        </tr>
        <tr>
          <td nowrap valign="middle">🔑 <samp>PRIVATEERR_GLUETUN_API_KEY</samp></td>
          <td valign="middle">The shared API key generated in step 2.</td>
        </tr>
        <tr>
          <td nowrap valign="middle">👤 <samp>QBITTORRENT_PUID</samp></td>
          <td valign="middle">The user ID that should own qBittorrent's files; find it with <code>id -u</code> on the Docker host.</td>
        </tr>
        <tr>
          <td nowrap valign="middle">👥 <samp>QBITTORRENT_PGID</samp></td>
          <td valign="middle">The group ID that should own qBittorrent's files; find it with <code>id -g</code> on the Docker host.</td>
        </tr>
        <tr>
          <td nowrap valign="middle">🕒 <samp>QBITTORRENT_TZ</samp></td>
          <td valign="middle">Your time zone, such as <code>America/New_York</code>.</td>
        </tr>
        <tr>
          <td nowrap valign="middle">📂 <samp>HOST_TORRENTS_DOWNLOADS_PATH</samp></td>
          <td valign="middle">Your host's downloads directory; the default is <code>./downloads/torrents</code>.</td>
        </tr>
        <tr>
          <td nowrap valign="middle">🔌 <samp>QBITTORRENT_WEBUI_PORT</samp></td>
          <td valign="middle">Keep <code>8080</code> unless that host port is already used.</td>
        </tr>
      </tbody>
    </table>
    <!-- markdownlint-enable MD033 -->

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
- [Use Make or build locally](https://scottgigawatt.github.io/privateerr/advanced-usage/#choose-compose-files-for-development): choose optional Compose files and shortcuts after the stack works.
- [Developer guides and Python reference](https://scottgigawatt.github.io/privateerr/development/privateerr/): architecture, tests, and source contracts.
- [Support](https://scottgigawatt.github.io/privateerr/SUPPORT/), [contributing](https://scottgigawatt.github.io/privateerr/CONTRIBUTING/), [security policy](https://scottgigawatt.github.io/privateerr/SECURITY/), and [Code of Conduct](https://scottgigawatt.github.io/privateerr/CODE_OF_CONDUCT/).

Privateerr is [Apache-2.0 licensed](LICENSE). PIA's unmodified scripts retain their [MIT license](https://github.com/pia-foss/manual-connections/blob/master/LICENSE).
