# Privateerr Config Hold 🏴‍☠️

Ahoy! This berth belongs to Privateerr herself.

Privateerr writes runtime logs here when she wakes, shakes the salt from her boots, and asks the official PIA scripts to draw a fresh WireGuard chart.

```text
config/privateerr/logs/privateerr.log
```

> [!NOTE]
> 🧽 That log be ignored by git, because live credentials and fresh voyage details belong in yer local hold, not nailed to the public mast.

The actual WireGuard treasure still lands in Gluetun's berth:

```text
config/gluetun/wireguard/wg0.conf
config/gluetun/wireguard/privateerr.env
```

> [!CAUTION]
> 💣 Live `wg0.conf` and `privateerr.env` can contain sensitive voyage details. Run `make restore-test-config` before committing.
