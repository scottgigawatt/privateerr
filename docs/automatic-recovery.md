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

Gluetun retains responsibility for the forwarded port and qBittorrent update hook. A forwarding-only failure does not rotate a healthy tunnel. There is no extra supervisor container or production Docker socket.

## Restart a healthy stack

With recovery enabled, Privateerr reuses a valid saved `wg0.conf` and `privateerr.env` pair. Restarting does not select a new region or replace a healthy connection. Use the procedure below to change the current registration.

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

3. Preserve needed configuration, then stop the stack, generate fresh settings, and start all three containers. This interrupts traffic, replaces VPN files, and removes the selected project's containers and network; volumes and images are retained. Run each command only after the previous one succeeds:

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

`PIA_AUTOCONNECT=true` ignores the preferred region. Environment changes alone do not replace a healthy saved configuration. During recovery, pinned selection stays within that region; automatic selection tries eligible endpoints in the current region, then other regions, without rerunning the latency benchmark. `PIA_PF=true` restricts selection to forwarding-capable regions. If no unused endpoint remains, Privateerr tries fresh registration with the permitted current endpoint. Dedicated IPs retain PIA's dedicated endpoint.

## Read diagnostics and check storage

Use your container manager's log view or the log command above. Messages also go to `PRIVATEERR_LOG_PATH` when available. Inspect and redact excerpts before sharing; keys, paths, region preferences, and application logs can be sensitive.

| Message or symptom | Action |
| --- | --- |
| Permission denied | Give UID 0 write/traverse access to the mapped host path, accounting for UID remapping. A read/write mount does not override host permissions. Do not broadly apply `chmod 777` or remove ACLs. |
| Read-only filesystem, disk exhaustion, quota limit, or missing path | Correct the reported condition at the corresponding host mount. Permission denial alone does not establish an ACL fault. |
| API `401` or `403` | Check the shared key and allowed routes. Keep the key and full settings response private. |
| API timeout or connection failure | Check the shared network and listener. Connectivity failures do not trigger blind regeneration. |
| Saving failed after API acceptance | Repair storage and preserve `.privateerr-pending` and `.privateerr-commit`. Gluetun may already use the replacement while saved files are incomplete. Do not delete state or regenerate concurrently. |
| Privateerr ready, with recovery-storage warning | Saved VPN files allowed startup, but recovery cannot yet save replacements. Repair the reported storage condition. |
| Privateerr cannot start | Check script installation, paths, persistent-log access, interrupted saves, and readiness-marker errors. Valid VPN files do not bypass these checks. |

Diagnostics name the container path, operation, error category, numeric UID/GID, and available ownership/mode. Match that container path to its host mount before changing permissions. Retain `cap_drop: ALL` and `no-new-privileges`.

Startup checks create, write, replace, and remove disposable files beside the VPN files. They do not change existing configuration, ownership, or ACLs. Failure can warn while reusing valid files; it stops startup when generation is required. A successful check cannot guarantee later writes. Interrupted cleanup can leave a `.privateerr-check.*` directory. [Architecture and file lifetimes](development/privateerr/architecture.md#confirm-updates-before-saving) explain retained state.

### Understand VPN region messages

Region labels name the provider-advertised VPN destination, not your location, measured latency, or verified physical server location. Missing labels show `unknown` without invalidating usable settings. A generated or reused configuration does not prove a working tunnel; confirmed recovery follows API readback, health verification, and saving.

## Configure timing

Set values in `.env` using `example.env`. The supplied Compose example enables recovery; when running the image in your own deployment, enable `PRIVATEERR_AUTO_RECOVER` explicitly if you want monitoring.

| Variable | Example default | Purpose |
| --- | --- | --- |
| `PRIVATEERR_AUTO_RECOVER` | `true` | Enable the built-in supervisor's monitoring |
| `PRIVATEERR_GLUETUN_URL` | `http://gluetun:8000` | Authenticated API |
| `PRIVATEERR_GLUETUN_HEALTH_URL` | `http://gluetun:9999` | Tunnel health |
| `PRIVATEERR_RECOVERY_INTERVAL_SECONDS` | `30` | Seconds between checks |
| `PRIVATEERR_RECOVERY_FAILURE_SECONDS` | `120` | Startup grace and continuous failure threshold, in seconds |
| `PRIVATEERR_RECOVERY_COOLDOWN_SECONDS` | `300` | Initial retry delay; doubles on failures to one hour |
| `PRIVATEERR_GENERATION_TIMEOUT_SECONDS` | `180` | Generation deadline, in seconds |

Monitoring begins after the grace period. Continuous failure must then reach the threshold measured from an unhealthy check. Gluetun's detection and retries add delay, so recovery can take several minutes. Healthy checks reset the timer; a manually stopped VPN pauses recovery. Restarting Privateerr resets process timers but does not repair storage or force a fresh registration.

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

Set `PRIVATEERR_AUTO_RECOVER=false` in `.env`, then repeat the quickstart's startup command. This recreates affected containers, interrupts traffic, and replaces saved VPN files; preserve needed state first. Gluetun resumes its configured health-restart policy, and Privateerr generates fresh files at startup.

To create a PIA WireGuard configuration file for another VPN client and then exit, [run the published Privateerr image once](advanced-usage.md#generate-without-make).

## Configure a custom deployment

The integration uses Gluetun v3.41.3's authenticated API routes and settings schema. Share the complete `/gluetun` directory between Privateerr and Gluetun, keep Privateerr on a shared Docker network outside Gluetun's VPN network, and make Gluetun wait for Privateerr's startup healthcheck.

Privateerr installs its two managed scripts before reporting ready. Keep custom scripts under different filenames and give UID 0 write/traverse access. Use this Gluetun entrypoint:

```yaml
entrypoint: ["/bin/sh", "/gluetun/scripts/gluetun-entrypoint-wrapper.sh"]
```

> [!IMPORTANT]
> Keep API and health ports unpublished. With recovery enabled, the wrapper sets `HEALTH_RESTART_VPN=off` so Gluetun's own retries do not conflict with Privateerr's settings update.

The wrapper changes the default health listener from `127.0.0.1:9999` to `0.0.0.0:9999` and prepares an API authentication role. When recovery is disabled, it leaves the listener, authentication, and Gluetun restart policy unchanged.

An existing `/gluetun/auth/config.toml` or custom `HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH` is preserved. Add the shared key with `GET /v1/vpn/status`, `GET /v1/vpn/settings`, `PUT /v1/vpn/settings`, and `GET /v1/portforward` permissions, following [Gluetun's authentication guidance](https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/control-server.md#authentication). Settings responses contain secrets. Without the wrapper, configure authentication, the health listener, shared network, and `HEALTH_RESTART_VPN=off` yourself.
