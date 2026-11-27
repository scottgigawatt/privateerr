# Automatic Gluetun recovery 🧭

The built-in Python supervisor in the Privateerr container checks the Gluetun VPN container and refreshes stale PIA WireGuard configuration after a sustained VPN outage. Gluetun runs the tunnel, firewall, DNS, and forwarded port. The supervisor updates Gluetun through its authenticated API; it does not restart containers. Existing connections can still disconnect while the VPN reconnects.

## Configure recovery

The [quickstart](https://github.com/scottgigawatt/privateerr/blob/main/README.md#quickstart) enables automatic recovery and creates its shared API key. Keep `PRIVATEERR_AUTO_RECOVER=true` and `PRIVATEERR_KEEPALIVE=true` in `.env`.

Check monitoring locally:

```sh
docker compose logs --tail 100 privateerr
```

After the startup grace period, confirm `Automatic recovery enabled` followed by `Gluetun tunnel is healthy`. Privateerr's container healthcheck confirms that its files and scripts are ready for Gluetun; it does not check the VPN tunnel.

<a id="how-the-supervisor-runs"></a>

## Understand the recovery sequence

After startup and a grace period, the Python supervisor inside the Privateerr container:

1. Checks Gluetun's API and tunnel health.
2. Creates replacement VPN settings after a sustained outage and the retry delay.
3. Applies those settings through Gluetun's API, reads them back, and checks the tunnel.
4. Saves the matching VPN files only after confirmation.

A generation failure leaves saved files unchanged. If an API result is uncertain, the supervisor checks Gluetun before generating more settings. Saved recovery state allows it to finish an interrupted update after Privateerr restarts. [Supervisor architecture](development/privateerr/architecture.md) explains that process.

Gluetun manages the forwarded port and qBittorrent update hook. By default Privateerr keeps a healthy tunnel when its port is missing. Operators who depend on incoming connections can [enable forwarding recovery](#recover-a-missing-forwarded-port). There is no extra supervisor container or production Docker socket.

## Recover a missing forwarded port

Enable this option if you rely on incoming connections. When Gluetun has a healthy tunnel but cannot obtain a forwarded port, Privateerr can try another PIA server in the same region. Switching servers can briefly interrupt every application using the tunnel.

> [!WARNING]
> Keep `PRIVATEERR_RECOVER_ON_PORT_FORWARD=false` with the example’s default Gluetun v3.41.3 image. During WireGuard shutdown, packets from established connections can leave the VPN. Before enabling server switching, use a Gluetun image that includes the [WireGuard shutdown fix](https://github.com/passteque/gluetun/pull/3510).

1. Start with the running Compose example and [automatic recovery enabled](#configure-recovery). Use a [Privateerr release](https://github.com/scottgigawatt/privateerr/releases) that includes forwarded-port recovery and a shared PIA server. Dedicated IPs stay on their assigned server. Check that your `.env` uses `PIA_PF=true`, `GLUETUN_VPN_PORT_FORWARDING=on`, and `GLUETUN_VPN_PORT_FORWARDING_PROVIDER="private internet access"`.
2. Set the following in `.env`. By default, Privateerr waits five minutes for Gluetun to obtain a port. To change the wait, set `PRIVATEERR_PORT_FORWARD_FAILURE_SECONDS` to a value from 1 to 9999. In a custom Compose file, pass the opt-in setting to Privateerr, along with the timeout if you change it.

    ```dotenv
    PRIVATEERR_RECOVER_ON_PORT_FORWARD=true
    ```

3. From the Compose directory, apply the change to Privateerr. This command uses your local image. If you also changed Gluetun’s settings or updated images, follow the [quickstart](https://github.com/scottgigawatt/privateerr/blob/main/README.md#quickstart) to apply those changes to the stack.

    ```sh
    docker compose --env-file .env up --detach \
      --no-deps --no-build --pull never privateerr
    ```

4. Check the service logs locally. They can contain private connection details.

    ```sh
    docker compose --env-file .env logs --tail 100 privateerr gluetun
    ```

    When Gluetun has a port, Privateerr logs `Gluetun tunnel is healthy and a forwarded port is assigned.` If a missing port returns, it also logs `Gluetun reports a forwarded port again.` In Gluetun’s log, look for `Set qBittorrent listen_port=` followed by the port and VPN interface. If the application missed the update, see [qBittorrent and the VPN connection](#qbittorrent-and-the-vpn-connection).

If Privateerr logs `waiting for Gluetun to obtain a forwarded port`, it gives Gluetun the full wait on the same healthy connection. An unreadable response or a VPN transition restarts the wait. If the port returns while Privateerr prepares a replacement, the tunnel stays on its current server.

Privateerr tries up to two other server addresses, even when region selection is automatic. An unsuccessful registration counts as an attempt. If Privateerr cannot confirm the region, finds no other address, or reaches the limit, it keeps the current tunnel. Check Gluetun’s forwarding errors or [choose another region](#choose-a-region) if you can use a different VPN location. A reported port clears the attempt count. Restarting Privateerr also clears it.

## Restart a healthy stack

With recovery enabled, Privateerr reuses a valid saved `wg0.conf` and `privateerr.env` pair. Restarting does not select a new region or replace a healthy connection. Use the procedure below to change the current registration.

The example selects a tested Gluetun release and multi-platform digest through `GLUETUN_TAG`. Set an explicit release or `latest` in `.env` only when you intend to test another image; the repository's compatibility checks cover its pinned default. Existing `.env` values remain authoritative. Gluetun uses the stable container name `${COMPOSE_PROJECT_NAME}-gluetun`, independent of the selected image.

The example's `restart: unless-stopped` policy restarts exited services and brings them back after a host reboot unless explicitly stopped. Docker health failures alone do not restart containers. Recreate Privateerr, Gluetun, and qBittorrent together after image updates; recreating Gluetun alone can leave qBittorrent attached to its previous network.

## Choose a region

Automatic selection is the default. To choose a region yourself:

1. From the checkout, list PIA's region IDs and port-forwarding support. The helper needs host `curl` and `jq`:

    ```sh
    sh scripts/compose/list-pia-regions.sh
    ```

2. Copy an ID from the `REGION ID` column. If `PIA_PF=true`, choose a region marked `Yes`. Edit `.env`, replacing the placeholder:

    ```dotenv
    PIA_AUTOCONNECT=false
    PIA_PREFERRED_REGION=YOUR-CHOSEN-PIA-REGION-ID
    ```

3. Save any PIA WireGuard configuration files you need, then stop the stack, generate a new configuration file and matching metadata, and start all three containers. This interrupts traffic, replaces VPN files, and removes the selected project's containers and network; volumes and images are retained. Run each command only after the previous one succeeds:

    ```sh
    docker compose down
    docker compose --env-file .env run --rm --no-deps --pull always \
      --env PRIVATEERR_AUTO_RECOVER=false \
      --env PRIVATEERR_KEEPALIVE=false \
      --env PIA_CONNECT=false \
      --env VPN_PROTOCOL=wireguard \
      privateerr
    docker compose --env-file .env up --detach --no-build --pull never privateerr gluetun qbittorrent
    ```

4. Check Privateerr's logs for `Gluetun tunnel is healthy` again.

`PIA_AUTOCONNECT=true` ignores the preferred region. Environment changes alone do not replace a healthy saved configuration. During recovery from a tunnel outage, pinned selection stays within that region; automatic selection tries eligible endpoints in the current region, then other regions, without rerunning the latency benchmark. `PIA_PF=true` restricts selection to forwarding-capable regions. If no unused endpoint remains, Privateerr tries fresh registration with the permitted current endpoint. Dedicated IPs retain PIA's dedicated endpoint.

## Read diagnostics and check storage

Use your container manager's log view or the log command above. Messages also go to `PRIVATEERR_LOG_PATH` when available. Inspect and redact excerpts before sharing; keys, paths, region preferences, and application logs can be sensitive.

The persistent file rotates at 10 MiB and keeps three backups (`.1` through `.3`, newest first), providing roughly 40 MiB of ongoing history. Complete records and a pre-existing oversized file can temporarily exceed that budget. Docker manages console logs separately; its retention settings do not bound this file. The log directory must allow file creation, renaming, and removal for rotation.

| Message or symptom | Action |
| --- | --- |
| Permission denied | Give UID 0 write/traverse access to the mapped host path, accounting for UID remapping. A read/write mount does not override host permissions. Do not broadly apply `chmod 777` or remove ACLs. |
| Read-only filesystem, disk exhaustion, quota limit, or missing path | Correct the reported condition at the corresponding host mount. Permission denial alone does not establish an ACL fault. |
| Gluetun control API `401` or `403` | Check the shared Gluetun API key and allowed routes. Privateerr keeps retrying; keep the key and full settings response private. |
| Gluetun control API timeout or connection failure | Check the Gluetun control listener and shared Docker network. Privateerr retries the API request without generating a new VPN configuration. |
| `PIA server list` warning | Check Privateerr's internet access and the source set by `PRIVATEERR_SERVERLIST_URL`. Privateerr keeps the saved configuration and retries after the recovery delay. |
| Saving failed after API acceptance | Repair storage and preserve `.privateerr-pending` and `.privateerr-commit`. Gluetun may already use the replacement while saved files are incomplete. Do not delete state or regenerate concurrently. |
| Privateerr ready, with recovery-storage warning | Saved VPN files allowed startup, but recovery cannot yet save replacements. Repair the reported storage condition. |
| Discarded invalid interrupted-save files | No action is needed for the discarded journal. Startup reuses a valid saved configuration with recovery enabled, or generates fresh files from the configured preferences. Storage or generation failures report a separate error. |
| Privateerr cannot start | Check script installation, paths, persistent-log access, interrupted saves, and readiness-marker errors. Valid VPN files do not bypass these checks. |

Diagnostics name the container path, operation, error category, numeric UID/GID, and available ownership/mode. Match that container path to its host mount before changing permissions. Retain `cap_drop: ALL` and `no-new-privileges`.

Startup checks create, write, replace, and remove disposable files beside the VPN files. They do not change existing configuration, ownership, or ACLs. Failure can warn while reusing valid files; it stops startup when generation is required. A successful check cannot guarantee later writes. Interrupted cleanup can leave a `.privateerr-check.*` directory. [Architecture and file lifetimes](development/privateerr/architecture.md#confirm-updates-before-saving) explain retained state.

### Understand VPN region messages

The region in Privateerr’s log is the VPN destination advertised by PIA. PIA can reuse a server name across regions. When generating metadata, Privateerr matches the WireGuard endpoint IP and the registered server name. If several regions advertise the same pair, Privateerr uses the known selection when available. If the region is still ambiguous, the log shows `unknown` and the configuration remains usable.

When Privateerr reuses saved files, it reports their saved region. A fresh registration updates the label. Look for `Gluetun is using the replacement WireGuard settings.` after Privateerr verifies the tunnel and saves the matching files. Gluetun reports its forwarded port separately.

## Configure timing

Set values in `.env` using `example.env`. The supplied Compose example enables recovery; when running the image in your own deployment, enable `PRIVATEERR_AUTO_RECOVER` explicitly if you want monitoring.

| Variable | Example default | Purpose |
| --- | --- | --- |
| `PRIVATEERR_AUTO_RECOVER` | `true` | Enable the built-in supervisor's monitoring |
| `PRIVATEERR_GLUETUN_URL` | `http://gluetun:8000` | Authenticated API |
| `PRIVATEERR_GLUETUN_HEALTH_URL` | `http://gluetun:9999` | Tunnel health |
| `PRIVATEERR_RECOVERY_INTERVAL_SECONDS` | `30` | Seconds between checks |
| `PRIVATEERR_RECOVERY_FAILURE_SECONDS` | `120` | Startup grace and continuous failure threshold, in seconds |
| `PRIVATEERR_RECOVERY_COOLDOWN_SECONDS` | `300` | Initial retry delay for a tunnel outage, doubling on failures to one hour |
| `PRIVATEERR_PORT_FORWARD_FAILURE_SECONDS` | `300` | Seconds without a port before [forwarding recovery](#recover-a-missing-forwarded-port) can try another server |
| `PRIVATEERR_GENERATION_TIMEOUT_SECONDS` | `180` | Generation deadline, in seconds |

Monitoring begins after the grace period. For a tunnel outage, Privateerr measures the threshold from the first unhealthy check. Gluetun's detection and retries add delay, so recovery can take several minutes. A healthy tunnel resets the outage timer. Manually stopping the VPN pauses both types of recovery. Restarting Privateerr resets process timers but does not repair storage or force a fresh registration.

## Compatibility and limits

Recovery requires keepalive, `PIA_CONNECT=false`, a private shared API key, and a directory mount containing both VPN files and retained recovery state. Only one Privateerr container may write to that directory at a time. Privateerr cannot start a stopped Gluetun VPN container, repair Docker, restore unavailable PIA services, fix credentials, or escape an unavailable pinned region.

<a id="understand-container-and-application-limits"></a>
<a id="try-the-qbittorrent-example"></a>

### qBittorrent and the VPN connection

`depends_on.restart: true` follows explicit Compose operations, not every Docker runtime restart. Privateerr has no application watchdog. If qBittorrent remains unavailable beyond the forwarding hook's wait limit, restore qBittorrent and reapply the current port with the hook or restart forwarding.

`QBITTORRENT_WEBUI_PORT` controls the host mapping, internal listener, healthcheck, hook API URL, and tests together; change it only for a host-port conflict. [LinuxServer requires synchronized ports](https://docs.linuxserver.io/images/docker-qbittorrent/#webui).

The seed permits unauthenticated API access from loopback for Gluetun's hook. Containers sharing Gluetun's network share that trust boundary; remote Web UI sessions require authentication. Existing qBittorrent configuration is preserved and must allow the hook's localhost API access. The hook binds qBittorrent to the VPN interface and assigned port, disables random ports/UPnP, and binds to loopback after lease removal. VPN peer ports need no host publication.

<a id="test-the-example"></a>

Use the [testing guide](development/privateerr/testing.md#validate-the-complete-example) only for intentional live validation in a disposable project. Tests use real credentials and can interrupt the VPN; ordinary startup never runs them.

## Run without privileged mode

Privateerr retains UID 0 for PIA's unmodified scripts while dropping all Linux capabilities and enabling `no-new-privileges`. Gluetun separately needs `NET_ADMIN` for its tunnel.

`PRIVATEERR_IPV6_DISABLED=1` disables IPv6 in Privateerr's container before startup. Keep it alongside `PIA_DISABLE_IPV6=yes`; Privateerr skips redundant upstream changes. This does not change host or Gluetun IPv6 settings. The VPN services disable unattended Watchtower updates.

## Disable recovery

Set `PRIVATEERR_AUTO_RECOVER=false` in `.env`, then repeat the quickstart's startup command. This recreates affected containers, interrupts traffic, and replaces saved VPN files. Save any PIA WireGuard configuration files you need before continuing. Gluetun resumes its configured health-restart policy, and Privateerr generates fresh files at startup.

To create a PIA WireGuard configuration file for another VPN client and then exit, [run the published Privateerr image once](advanced-usage.md#generate-without-make).

## Configure a custom deployment

The integration uses the authenticated API routes and settings schema exercised by [the pinned Gluetun API test](https://github.com/scottgigawatt/privateerr/blob/main/test/runtime/test-recovery-api.py). Share the complete `/gluetun` directory between Privateerr and Gluetun, keep Privateerr on a shared Docker network outside Gluetun's VPN network, and make Gluetun wait for Privateerr's startup healthcheck.

Privateerr installs its two managed scripts before reporting ready. Keep custom scripts under different filenames and give UID 0 write/traverse access. Use this Gluetun entrypoint:

```yaml
entrypoint: ["/bin/sh", "/gluetun/scripts/gluetun-entrypoint-wrapper.sh"]
```

> [!IMPORTANT]
> Keep API and health ports unpublished. With recovery enabled, the wrapper sets `HEALTH_RESTART_VPN=off` so Gluetun's own retries do not conflict with Privateerr's settings update.

The wrapper changes the default health listener from `127.0.0.1:9999` to `0.0.0.0:9999` and prepares an API authentication role. When recovery is disabled, it leaves the listener, authentication, and Gluetun restart policy unchanged.

An existing `/gluetun/auth/config.toml` or custom `HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH` is preserved. Add the shared key with `GET /v1/vpn/status`, `GET /v1/vpn/settings`, `PUT /v1/vpn/settings`, and `GET /v1/portforward` permissions, following [Gluetun's authentication guidance](https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/control-server.md#authentication). Settings responses contain secrets. Without the wrapper, configure authentication, the health listener, shared network, and `HEALTH_RESTART_VPN=off` yourself.
