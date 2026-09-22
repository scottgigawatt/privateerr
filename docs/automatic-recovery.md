# Automatic Gluetun recovery 🧭

Privateerr can refresh a stale PIA WireGuard connection after a sustained tunnel outage. Enable it when a tunnel repeatedly retries an unusable endpoint. Privateerr remains a configuration generator; Gluetun still owns the tunnel, firewall, DNS, and port forwarding.

Recovery runs inside the existing Privateerr container and uses Gluetun's authenticated control API. It needs no additional service or Docker socket. The Gluetun container stays running, preserving the network namespace shared by applications such as qBittorrent. Existing connections may still disconnect while the tunnel changes.

## Enable recovery

Before you begin, use the updated Privateerr image, Compose file, and Gluetun entrypoint wrapper together. The integration is tested against Gluetun **v3.41.3**. Other versions must support the same authenticated control API routes and settings schema. The reference deployment keeps your chosen Gluetun image tag.

> [!IMPORTANT]
> Recovery makes Privateerr responsible for sustained-outage recovery and sets Gluetun's `HEALTH_RESTART_VPN=off`. Keep Privateerr outside Gluetun's VPN network namespace so it can reach PIA when the tunnel fails.

Follow these steps from the repository root:

1. Generate an API key:

   ```sh
   openssl rand -hex 24
   ```

2. Add the following settings to `.env`, replacing `YOUR-GENERATED-KEY` with that value:

   ```dotenv
   PRIVATEERR_AUTO_RECOVER=true
   PRIVATEERR_KEEPALIVE=true
   PRIVATEERR_GLUETUN_API_KEY=YOUR-GENERATED-KEY
   ```

3. Recreate the deployment so both containers receive the new environment:

   ```sh
   make up
   ```

4. Read Privateerr's logs:

   ```sh
   docker compose logs privateerr
   ```

   Confirm that you see `Automatic recovery enabled`, followed by `Gluetun tunnel is healthy` after startup.

## Configure a custom deployment

The supplied wrapper disables Gluetun's health-triggered restarts when recovery is enabled because those restarts can race a settings update. WireGuard still reconnects naturally after brief network interruptions. Do not publish Gluetun's control or health ports to the host for this feature.

The supplied Compose stack gives both containers a shared Docker network. When recovery is enabled, the Gluetun wrapper changes the default health listener from `127.0.0.1:9999` to `0.0.0.0:9999` and creates a temporary API authentication file with only the required routes. When recovery is disabled, the listener, authentication, and Gluetun restart policy remain unchanged.

For a custom deployment, adopt the updated wrapper or configure `HEALTH_RESTART_VPN=off`, the shared network, health listener, and API authentication yourself.

If an authentication file already exists at `/gluetun/auth/config.toml`, or `HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH` names a custom path, the wrapper preserves that file. Add a role with your shared key and these routes:

- `GET /v1/vpn/status`
- `GET /v1/vpn/settings`
- `PUT /v1/vpn/settings`
- `GET /v1/portforward`

Follow [Gluetun's authentication documentation](https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/control-server.md#authentication). Settings responses contain secrets; do not paste them into support discussions.

## Choose a region

Automatic selection remains the default. To select the `ca` region, edit `.env`:

```dotenv
PIA_AUTOCONNECT=false
PIA_PREFERRED_REGION=ca
```

`PIA_PREFERRED_REGION` defaults to `ca`, matching Plundarr. Choose another PIA region ID to use that region instead. `PIA_AUTOCONNECT=true` takes precedence and ignores the preferred region. A container restart alone does not reload Compose environment changes; recreate with `make up`.

Recovery tries another advertised endpoint in the selected region. A pinned region never falls back to another region. Automatic selection prefers other endpoints in the current region, then other eligible regions in the server catalog; recovery does not rerun a full latency benchmark. With `PIA_PF=true`, only regions advertising port forwarding are eligible. If no unused endpoint remains, Privateerr attempts fresh registration against the current permitted endpoint. Dedicated IPs retain their dedicated endpoint through upstream setup.

## Understand the recovery sequence

Privateerr generates and validates the initial configuration before reporting ready. Gluetun can therefore retain `depends_on: service_healthy`; Privateerr's Docker healthcheck does not depend on a working tunnel.

After the startup grace period, Privateerr checks Gluetun's control API and tunnel health. A sustained outage triggers one fresh PIA registration. Generation uses staging files and a deadline, leaving saved configuration untouched on failure. The upstream PIA scripts remain unmodified.

Privateerr submits the new WireGuard keys, address, endpoint, and PIA server name together through `PUT /v1/vpn/settings`. Gluetun restarts its internal tunnel. Privateerr reads back the applied settings and waits for tunnel health before saving the new configuration and metadata. An ambiguous API timeout is reconciled before another candidate is generated. Pending candidates and an interrupted publication can be recovered after Privateerr restarts.

Privateerr reports port-forwarding status separately. Gluetun continues obtaining and renewing the forwarded port; a forwarding-only failure does not cause Privateerr to rotate otherwise healthy tunnels. Existing application port-update hooks remain Gluetun's responsibility.

## Configure timing

Defaults work without adding the new timing variables to an existing `.env`.

| Variable | Default | Purpose |
| --- | --- | --- |
| `PRIVATEERR_AUTO_RECOVER` | `false` | Enable the optional monitor |
| `PRIVATEERR_GLUETUN_URL` | `http://gluetun:8000` | Authenticated control API |
| `PRIVATEERR_GLUETUN_HEALTH_URL` | `http://gluetun:9999` | Tunnel health endpoint |
| `PRIVATEERR_RECOVERY_INTERVAL` | `30` | Seconds between probes |
| `PRIVATEERR_RECOVERY_FAILURE_SECONDS` | `120` | Startup grace and continuous failure threshold, in seconds |
| `PRIVATEERR_RECOVERY_COOLDOWN` | `300` | Initial seconds between attempts; doubles on failures up to one hour |
| `PRIVATEERR_GENERATION_TIMEOUT` | `180` | Maximum seconds for each upstream generation |

At startup, Privateerr waits through the grace period before monitoring. Recovery then requires a continuous failure lasting the configured threshold, measured from an unhealthy probe. Gluetun's own periodic probes and retries add detection time, so a blocked endpoint can take several minutes to trigger recovery. Healthy probes reset the failure timer. A manually stopped VPN pauses recovery. Failed API authentication or an unreachable control server does not cause repeated configuration generation.

## Compatibility and limits

Recovery defaults to off. Existing deployments using the image alone continue generating once and optionally keeping the container alive. Existing `.env` files can omit the new settings; the wrapper supplies defaults. An explicitly selected region requires `PIA_AUTOCONNECT=false`; the new default removes the need for interactive region selection when no preference was supplied.

Recovery requires the configuration and metadata to share a directory mount and one Privateerr instance to own those files. The existing `wg0.conf` and `privateerr.env` paths remain regular files. Privateerr keeps copies of both files in `.privateerr-commit` until both replacements finish, allowing startup to complete an interrupted save. It stores a candidate awaiting API and health confirmation in `.privateerr-pending`. Both directories sit beside the generated files. Do not delete those directories during recovery. A normal one-shot regeneration still replaces saved files; avoid running it concurrently with the monitor.

This feature cannot start a stopped Gluetun container or repair a hung Docker daemon. An unavailable PIA service, invalid account credentials, or a fully unavailable pinned region can also prevent recovery. Logs identify those failures while the saved configuration remains available. Repeated failures use a cooldown rather than a container restart loop.

## Disable recovery

Set `PRIVATEERR_AUTO_RECOVER=false` in `.env` and recreate both containers with `make up`. Gluetun resumes its configured health-restart policy. Privateerr returns to ordinary startup behavior and generates a fresh configuration pair.
