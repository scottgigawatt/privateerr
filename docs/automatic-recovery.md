# Automatic Gluetun recovery 🧭

Privateerr refreshes stale PIA WireGuard settings after a sustained tunnel outage. Gluetun owns the tunnel, firewall, DNS, and forwarded port. Recovery uses its authenticated API without replacing the container or application network namespace. Existing connections can still disconnect while the tunnel changes.

## Configure recovery

Use the supplied Compose file and complete the [repository setup](https://github.com/scottgigawatt/privateerr#readme). Integration is tested against Gluetun **v3.41.3**; other versions need the same authenticated routes and settings schema.

Privateerr installs its Gluetun wrapper and qBittorrent hook into the shared `/gluetun/scripts/` directory before readiness. No manual script copying is needed.

> [!IMPORTANT]
> Keep Privateerr outside Gluetun's VPN namespace so it can reach PIA during an outage. Recovery sets `HEALTH_RESTART_VPN=off` to prevent Gluetun's health-triggered restarts from racing an update. Keep API and health ports unpublished.

1. Generate a private shared key:

    ```sh
    openssl rand -hex 24
    ```

2. Set these values in `.env`, replacing `YOUR-GENERATED-KEY` with the result:

    ```dotenv
    PRIVATEERR_AUTO_RECOVER=true
    PRIVATEERR_KEEPALIVE=true
    PRIVATEERR_GLUETUN_API_KEY=YOUR-GENERATED-KEY
    ```

3. Apply the settings from the repository root. Recreating affected containers can interrupt traffic:

    ```sh
    make up
    ```

4. Check Privateerr's logs:

    ```sh
    docker compose logs --tail 100 privateerr
    ```

    Confirm `Automatic recovery enabled`, followed by `Gluetun tunnel is healthy`. Container readiness alone does not prove tunnel health.

`make up` starts only Privateerr, Gluetun, and qBittorrent. Use `make up-build` for a source build or [direct Compose startup](advanced-usage.md#start-without-make) without Make.

## Configure a custom deployment

Share the complete `/gluetun` directory between Privateerr and Gluetun, retain Gluetun's dependency on Privateerr's startup healthcheck, and use:

```yaml
entrypoint: ["/bin/sh", "/gluetun/scripts/gluetun-entrypoint-wrapper.sh"]
```

Privateerr needs write and traverse access to install its two managed scripts at each startup. Keep custom scripts under other filenames; recreate the application stack together after image updates.

Both VPN services need a shared Docker network. With recovery enabled, the wrapper changes the default health listener from `127.0.0.1:9999` to `0.0.0.0:9999` and prepares an API authentication role. With recovery disabled, the listener, authentication, and Gluetun restart policy remain unchanged.

An existing `/gluetun/auth/config.toml`, or a custom `HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH`, is preserved. Add your shared key with these allowed routes:

- `GET /v1/vpn/status`
- `GET /v1/vpn/settings`
- `PUT /v1/vpn/settings`
- `GET /v1/portforward`

Follow [Gluetun authentication guidance](https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/control-server.md#authentication). Settings responses contain secrets; keep them private. Without the wrapper, you must configure authentication, the health listener, shared network, and `HEALTH_RESTART_VPN=off` yourself.

## Restart a healthy stack

Recovery-enabled startup reuses a valid saved `wg0.conf` and `privateerr.env` pair. It does not rerun lowest-latency selection or switch a healthy connection. With recovery disabled, startup generates fresh files.

To change the current registration, use the [regeneration procedure](#choose-a-region), rather than repeatedly restarting containers.

## Choose a region

Automatic selection is the default. From a checkout, run `make list-pia-regions` with host `curl` and `jq` installed. It lists every region with its ID and Yes/No port-forwarding support. Terminal output uses color; set `NO_COLOR=1` to disable it. Redirected output is plain text.

Without Make, use this plain-text lookup. It requires `curl`, `jq`, and `column` and reads [PIA's public region catalog](https://serverlist.piaservers.net/vpninfo/servers/v6):

```sh
(
  set -eu
  lookup_dir=$(mktemp -d)
  trap 'rm -rf "$lookup_dir"' 0
  trap 'exit 1' 1 2 15
  curl -fsSL --max-time 30 https://serverlist.piaservers.net/vpninfo/servers/v6 \
    --output "$lookup_dir/catalog"
  jq --raw-input --slurp --exit-status --raw-output '
    split("\n")[0] | fromjson
    | .regions | sort_by(.name) | select(length > 0)
    | [["LOCATION", "REGION ID", "PORT FORWARDING"]]
      + map([.name, .id, (if .port_forward then "Yes" else "No" end)])
    | .[] | @tsv
  ' "$lookup_dir/catalog" >"$lookup_dir/regions.tsv"
  NO_COLOR=1 column -t -s "$(printf '\t')" "$lookup_dir/regions.tsv"
)
```

Copy an ID from the `REGION ID` column. If `PIA_PF=true`, choose a region marked `Yes`. To pin that region, edit `.env`:

```dotenv
PIA_AUTOCONNECT=false
PIA_PREFERRED_REGION=YOUR-CHOSEN-PIA-REGION-ID
```

Replace the placeholder with the chosen ID. `PIA_AUTOCONNECT=true` ignores the preferred region.

Changing settings and recreating containers does not replace a healthy saved pair. Applying a region or forwarding-selection change requires fresh generation. This interrupts traffic, removes the selected project's containers/network, and replaces its VPN files; preserve needed configuration and stop the supervisor first. Volumes and images are retained. Run each command only after the previous one succeeds:

```sh
make down
make run-privateerr
make up-build
```

The one-shot command disables recovery and keepalive only for that run. `make up-build` retains its locally built Privateerr image. A plain restart does not reload environment changes.

Recovery prefers another advertised endpoint in the selected region. Pinned selection never changes regions; automatic selection tries eligible endpoints in the current region, then other regions, without rerunning the latency benchmark. `PIA_PF=true` restricts selection to forwarding-capable regions. With no unused eligible endpoint, Privateerr tries fresh registration against the permitted current endpoint. Dedicated IPs retain upstream's dedicated endpoint.

## How the supervisor runs

A standard-library Python supervisor runs inside Privateerr; the Gluetun wrapper remains shell. No additional service, web server, or production Docker socket is needed. The [architecture guide](development/privateerr/architecture.md) explains process bounds, timers, logging, and publication.

The example's `restart: unless-stopped` policy restarts exited services and brings them back after a host reboot unless explicitly stopped. Docker health failures alone do not trigger container restarts. Buccaneerr uses `restart: "no"` so its test result remains final.

For custom one-shot generation, set `PRIVATEERR_AUTO_RECOVER=false`, `PRIVATEERR_KEEPALIVE=false`, and `restart: "no"`. Stop any supervisor writing the same directory first.

## Understand the recovery sequence

After startup readiness and a grace period, Privateerr:

1. Checks Gluetun's API and tunnel health.
2. Generates a staged candidate after a sustained outage and the retry cooldown.
3. Applies the connection fields through `PUT /v1/vpn/settings`, then reads them back and checks tunnel health.
4. Saves the matching VPN files only after confirmation.

Generation failure leaves saved files unchanged. An uncertain API response is reconciled before another candidate is generated; a candidate or interrupted save can survive a Privateerr restart.

Gluetun retains the port lease and application hooks. A forwarding-only failure does not rotate a healthy tunnel. See the [publication state and file lifetimes](development/privateerr/architecture.md#confirm-updates-before-saving) for implementation details.

## Read diagnostics and check storage

Use Dockge, Synology Container Manager's log view, or `docker compose logs --tail 100 privateerr`. Messages also go to `PRIVATEERR_LOG_PATH` when available. Inspect and redact full excerpts before sharing; keys, private logs, paths, and region preferences can be sensitive.

| Message or symptom | Action |
| --- | --- |
| Permission denied | Give container UID 0 write/traverse access to the mapped host path, accounting for UID remapping. A read/write mount does not override host permissions. Do not broadly apply `chmod 777` or remove ACLs. |
| Read-only filesystem, disk exhaustion, quota limit, or missing path | Correct the reported condition at the corresponding host mount. Permission denial alone does not establish an ACL fault. |
| API `401` or `403` | Check the shared key and role routes. Keep the key and full settings response private. |
| API timeout or connection failure | Check the shared network and listener. Authentication/connectivity failures do not trigger blind regeneration. |
| Saving failed after API acceptance | Repair storage and preserve `.privateerr-pending` and `.privateerr-commit`. Gluetun may already use the candidate while saved files are older or partly replaced. Do not delete state or regenerate concurrently. |
| Privateerr ready, with recovery-storage warning | A valid saved pair allowed startup, but future recovery writes remain unavailable. Repair the reported storage condition. |
| Privateerr cannot start | Check script installation, directory preparation, persistent-log access, pending-save reconciliation, and readiness-marker errors. Valid VPN files do not bypass those failures. |

Filesystem diagnostics identify the container path, operation, error category, numeric UID/GID, and available ownership/mode. Map the container path to its host path before changing permissions. Retain `cap_drop: ALL` and `no-new-privileges`.

Startup probes create, write, replace, and remove disposable files beside the saved pair without changing existing configuration, ownership, or ACLs. Failure can warn while reusing a valid pair; when generation is required it stops startup. A passed probe cannot guarantee later writes or access to existing recovery files. Interrupted cleanup can leave a `.privateerr-check.*` directory.

New registrations follow a cooldown; retained candidates are reconciled on monitoring cycles before another registration. Restarting Privateerr resets process timers but does not repair storage or force a fresh registration.

### Understand VPN region messages

Region labels describe the provider-advertised VPN destination, not your location, measured latency, or verified physical server location. Missing/malformed labels display `unknown` without invalidating a usable pair. Reused or generated settings do not prove a healthy tunnel; only a confirmed-recovery message follows API readback, health verification, and saving.

## Configure timing

Set values in `.env` using `example.env`. Compose has no interpolation fallbacks. Image-only recovery is disabled unless explicitly enabled.

| Variable | Example default | Purpose |
| --- | --- | --- |
| `PRIVATEERR_AUTO_RECOVER` | `true` | Enable monitoring |
| `PRIVATEERR_GLUETUN_URL` | `http://gluetun:8000` | Authenticated API |
| `PRIVATEERR_GLUETUN_HEALTH_URL` | `http://gluetun:9999` | Tunnel health |
| `PRIVATEERR_RECOVERY_INTERVAL_SECONDS` | `30` | Seconds between probes |
| `PRIVATEERR_RECOVERY_FAILURE_SECONDS` | `120` | Startup grace and continuous failure threshold, in seconds |
| `PRIVATEERR_RECOVERY_COOLDOWN_SECONDS` | `300` | Initial retry delay; doubles on failures to one hour |
| `PRIVATEERR_GENERATION_TIMEOUT_SECONDS` | `180` | Generation work deadline in seconds |

Monitoring starts after the grace period. A continuous failure must then reach the threshold measured from an unhealthy probe. Gluetun's own detection/retries add delay, so recovery can take several minutes. Healthy probes reset the timer. A manually stopped VPN pauses recovery. Timers use elapsed time and are unaffected by host clock corrections.

## Compatibility and limits

Recovery needs keepalive, `PIA_CONNECT=false`, a private shared key, a directory mount for both VPN files, and one Privateerr writer. Keep `.privateerr-pending` and `.privateerr-commit` beside the saved pair; they retain candidates and permit completion of interrupted saves.

Privateerr cannot start a stopped Gluetun container, repair Docker, restore unavailable PIA services, fix account credentials, or escape a fully unavailable pinned region. Repeated failures use a cooldown.

## Run without privileged mode

Privateerr retains UID 0 for unmodified upstream scripts, while dropping all Linux capabilities and enabling `no-new-privileges`. Gluetun separately needs `NET_ADMIN` for the tunnel.

`PRIVATEERR_IPV6_DISABLED=1` disables IPv6 in Privateerr's namespace before startup. Keep it alongside `PIA_DISABLE_IPV6=yes`; the wrapper skips redundant upstream writes. This does not change host or Gluetun IPv6 settings.

The VPN services disable unattended Watchtower updates. Intentional image replacement can still interrupt traffic; pulling an image alone does not change container privileges or sysctls.

## Disable recovery

Set `PRIVATEERR_AUTO_RECOVER=false` in `.env`. Applying this recreates affected containers, interrupts traffic, and replaces the saved VPN pair. Preserve needed state first:

```sh
make up
```

Gluetun resumes its configured health-restart policy, and Privateerr generates fresh files at startup. Normal startup excludes Buccaneerr's fault-injection tests.

## Understand container and application limits

[`depends_on.restart: true`](https://docs.docker.com/reference/compose-file/services/#depends_on) follows explicit Compose operations, not every Docker runtime restart. Recreating Gluetun separately can leave applications attached to its old namespace; recreate dependent services together. Privateerr has no Docker socket or application watchdog.

If qBittorrent remains unavailable beyond the hook's wait limit, restore it and reapply the current port with the hook or restart forwarding.

## Try the qBittorrent example

Review qBittorrent's PUID, PGID, storage paths, and port in `.env`, then follow [stack startup](https://github.com/scottgigawatt/privateerr#start-privateerr-with-gluetun-). The example supports amd64/arm64.

`QBITTORRENT_WEBUI_PORT` defaults to `8080` and controls the host mapping, internal listener, healthcheck, hook API URL, and tests together. Change it for a host-port conflict; [LinuxServer requires synchronized ports](https://docs.linuxserver.io/images/docker-qbittorrent/#webui).

Obtain the initial password from local qBittorrent logs and change it in the Web UI. The seed permits unauthenticated API access from loopback for the hook; other containers sharing Gluetun's namespace share that trust boundary. Remote Web UI sessions require authentication. Existing application configuration is preserved and must permit the hook's localhost API access.

The hook binds qBittorrent to the VPN interface and assigned port, disables random ports/UPnP, and binds to loopback after lease removal. VPN peer ports need no host publication.

### Test the example

Use the [canonical testing guide](development/privateerr/testing.md#validate-the-complete-example) for optional live validation. It requires a disposable project and real PIA credentials and deliberately interrupts the test tunnel. Ordinary startup never runs it.
