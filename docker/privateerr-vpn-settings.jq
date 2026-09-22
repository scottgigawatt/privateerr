#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# privateerr-vpn-settings.jq: Validate generated files and build a minimal Gluetun update.
#

# Parse only assignments; duplicate keys are rejected rather than silently overwritten.
def assignments:
  reduce (split("\n")[] | select(test("^[A-Za-z_]+\\s*="))
    | capture("^(?<key>[A-Za-z_]+)\\s*=\\s*(?<value>.*?)\\s*$")) as $line
    ({}; if has($line.key) then error("Duplicate configuration field")
      else .[$line.key] = $line.value end);

# PIA generates IPv4 endpoints and interface addresses.
def ipv4:
  split(".") as $parts
  | ($parts | length) == 4 and all($parts[]; test("^[0-9]{1,3}$") and (tonumber <= 255));

def key:
  test("^[A-Za-z0-9+/]{43}=$");

($config | assignments) as $wg
| ($metadata | assignments) as $meta
| ($wg.Endpoint // "" | split(":")) as $endpoint
| ($wg.Address // "" | split("/")) as $address
| if (($wg.PrivateKey // "" | key) and ($wg.PublicKey // "" | key)
    and ($endpoint | length) == 2 and ($endpoint[0] | ipv4)
    and ($endpoint[1] | test("^[0-9]{1,5}$"))
    and ($endpoint[1] | tonumber) > 0 and ($endpoint[1] | tonumber) <= 65535
    and ($address | length) <= 2 and ($address[0] | ipv4)
    and (($address[1] // "32") | test("^([0-9]|[12][0-9]|3[0-2])$"))
    and ($meta.PIA_WG_SERVER_NAME // "" | test("^[A-Za-z0-9][A-Za-z0-9.-]*$"))
    and $meta.PIA_WG_ENDPOINT_IP == $endpoint[0]
    and $meta.PIA_WG_ENDPOINT_PORT == $endpoint[1])
  then {
    wireguard: {
      private_key: $wg.PrivateKey,
      addresses: [($address[0] + "/" + ($address[1] // "32"))]
    },
    provider: {
      server_selection: {
        names: [$meta.PIA_WG_SERVER_NAME],
        wireguard: {
          endpoint_ip: $endpoint[0],
          endpoint_port: ($endpoint[1] | tonumber),
          public_key: $wg.PublicKey
        }
      }
    }
  }
  else error("Generated WireGuard configuration or metadata is invalid") end
