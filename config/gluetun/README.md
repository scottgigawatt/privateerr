# Gluetun configuration 🧭

Privateerr and Gluetun both mount this directory. Privateerr validates an existing configuration pair or generates one, and Gluetun uses it to start the tunnel. During automatic recovery, the supervisor applies replacement settings through Gluetun's API before publishing the confirmed pair.

The shared files live here:

```text
config/gluetun/wireguard/wg0.conf
config/gluetun/wireguard/privateerr.env
```

`privateerr.env` carries `PIA_WG_SERVER_NAME`. The wrapper turns that into Gluetun's `SERVER_NAMES` value so PIA port forwarding requests the matching server.

Privateerr installs both scripts from its image before reporting ready:

```text
config/gluetun/scripts/gluetun-entrypoint-wrapper.sh
config/gluetun/scripts/qbittorrent-port-forwarding.sh
```

Startup replaces these two generated files. Keep custom scripts under other names and select their paths explicitly in your deployment. Gluetun runs the wrapper directly from this shared directory; its forwarding commands call the installed qBittorrent hook.

The wrapper waits for `privateerr.env` and any active publication to finish, exports `PIA_WG_SERVER_NAME` as `SERVER_NAMES`, and then hands control to Gluetun's original entrypoint. When recovery is enabled, it also configures the shared health listener and disables Gluetun's competing health-triggered restart policy. It preserves operator-supplied API authentication; otherwise it creates a narrowly scoped recovery role.

Mount the directory rather than individual generated files. Privateerr's UID 0 needs write and traverse access to `scripts/` for installation and `wireguard/` for staging and atomic replacement. A `:rw` mount does not override host permissions. Startup checks use disposable `.privateerr-check.*` directories; failed recovery-storage checks warn without blocking reuse of a valid saved pair. Script installation must succeed before readiness. See [diagnostics](../../docs/automatic-recovery.md#read-diagnostics-and-check-storage).

> [!IMPORTANT]
> Runtime files such as `forwarded_port`, `ip`, `piaportforward.json`, and Gluetun's server cache are ignored by Git. Treat the whole directory as sensitive state.
