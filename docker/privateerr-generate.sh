#!/usr/bin/env bash

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# privateerr-generate.sh: This script launches the unmodified PIA manual connection
#                           scripts, then writes a dotenv metadata file for Gluetun.
#
# Usage: docker/privateerr-generate.sh
#
# The script:
#   - Runs the PIA setup script from the configured PIA script directory.
#   - Expects PIA_CONNECT=false so PIA writes a WireGuard config instead of starting a tunnel.
#   - Prefixes log lines so upstream PIA output is clearly separated from Privateerr output.
#   - Extracts the generated WireGuard endpoint from wg0.conf.
#   - Extracts the PIA WireGuard TLS server name from the PIA script output.
#   - Looks up matching region metadata from the PIA server list when available.
#   - Writes Privateerr metadata used by Gluetun port forwarding.
#

#
# Fail on any error, unset variable, or failed pipe command.
#
set -euo pipefail

#
# Default file locations.
#
: "${PIA_BIN_HOME:=/pia}"
: "${PIA_CONF_PATH:=/gluetun/wireguard/wg0.conf}"
: "${PRIVATEERR_METADATA_PATH:=/gluetun/wireguard/privateerr.env}"
: "${PRIVATEERR_HEALTHCHECK_MARKER:=/healthcheck/privateerr.ready}"
: "${PRIVATEERR_LOG_PATH:=/privateerr-config/logs/privateerr.log}"
: "${PRIVATEERR_SERVERLIST_URL:=https://serverlist.piaservers.net/vpninfo/servers/v6}"

#
# Script state used for consistent log output and graceful shutdown.
#
privateerr_script_name="privateerr-generate.sh"
privateerr_run_log_path="$(mktemp /tmp/privateerr-run.XXXXXX)"
trap 'rm -f "${privateerr_run_log_path}"' EXIT

#
# write_log_line: Write one line to stdout and the configured log file.
#
# Parameters: $1 - Complete log message.
#
# Returns: tee's exit status.
#
write_log_line() {
    printf '%s\n' "$1" | tee -a "${PRIVATEERR_LOG_PATH}"
}

#
# log_privateerr: Prefix log lines emitted by this script.
#
# Parameters: $* - Message fragments to write as one log line.
#
# Returns: write_log_line's exit status.
#
log_privateerr() {
    write_log_line "[${privateerr_script_name}] $*"
}

#
# log_pia: Prefix log lines emitted by an upstream PIA script.
#
# Parameters: $1 - Upstream script name.
#             $2 - Complete upstream log line.
#
# Returns: tee's exit status.
#
log_pia() {
    pia_script_name="$1"
    pia_log_line="$2"

    printf '[%s] %s\n' "${pia_script_name}" "${pia_log_line}" \
        | tee -a "${privateerr_run_log_path}" "${PRIVATEERR_LOG_PATH}"
}

#
# Ensure output directories exist before running the upstream scripts.
#
mkdir -p \
    "$(dirname "${PIA_CONF_PATH}")" \
    "$(dirname "${PRIVATEERR_METADATA_PATH}")" \
    "$(dirname "${PRIVATEERR_HEALTHCHECK_MARKER}")" \
    "$(dirname "${PRIVATEERR_LOG_PATH}")"

#
# Start a fresh per-run log while retaining previous recovery diagnostics.
#
: > "${privateerr_run_log_path}"
touch "${PRIVATEERR_LOG_PATH}"

#
cd "${PIA_BIN_HOME}"

#
# run_pia: Invoke unmodified upstream setup or registration for a selected endpoint.
#
# Parameters: None.
#
# Returns: The upstream script exit status.
#
# Run the upstream PIA setup exactly as shipped in the submodule.
# Some PIA output mentions connecting to WireGuard because the upstream script
# uses shared messaging. With PIA_CONNECT=false, Privateerr only writes config.
#
run_pia() {
    if [[ -z "${PRIVATEERR_CANDIDATE_IP:-}" ]]; then
        ./run_setup.sh
        return
    fi

    # Recovery selects an advertised endpoint; upstream still owns authentication and key registration.
    ./get_token.sh || return
    local token
    token="$(head -n 1 /opt/piavpn-manual/token)"
    rm -f /opt/piavpn-manual/token
    [[ -n "${token}" && "${token}" != "null" ]] || return 1
    printf 'WG_HOSTNAME=%s\n' "${PRIVATEERR_CANDIDATE_NAME}"
    PIA_TOKEN="${token}" WG_SERVER_IP="${PRIVATEERR_CANDIDATE_IP}" \
        WG_HOSTNAME="${PRIVATEERR_CANDIDATE_NAME}" DIP_TOKEN="" \
        ./connect_to_wireguard_with_token.sh
}

run_pia 2>&1 | sed -E \
    -e 's/(PIA_TOKEN=)[^[:space:]\\]+/\1[redacted]/g' \
    -e 's/(DIP_TOKEN=)[^[:space:]\\]+/\1[redacted]/g' \
    -e 's/(PIA_USER=)[^[:space:]\\]+/\1[redacted]/g' \
    -e 's/(Using existing token )[[:alnum:]]+/\1[redacted]/g' \
    | while IFS= read -r pia_log_line; do
        log_pia "run_setup.sh" "${pia_log_line}"
    done

#
# The generated WireGuard config is the source of truth for the endpoint that Gluetun will use.
#
if [[ ! -f "${PIA_CONF_PATH}" ]]; then
    log_privateerr "Privateerr could not find the generated WireGuard config at ${PIA_CONF_PATH}."
    exit 1
fi

#
# Extract the WireGuard endpoint from the generated config. The endpoint is in the form of "host:port".
#
endpoint_line="$(awk -F '=' '/^[[:space:]]*Endpoint[[:space:]]*=/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "${PIA_CONF_PATH}")"

#
# Validate that the endpoint was found and is in the expected format.
#
if [[ -z "${endpoint_line}" || "${endpoint_line}" != *:* ]]; then
    log_privateerr "Privateerr could not read a WireGuard Endpoint from ${PIA_CONF_PATH}."
    exit 1
fi

#
# Split the endpoint into IP and port for metadata.
#
endpoint_ip="${endpoint_line%:*}"
endpoint_port="${endpoint_line##*:}"
wg_server_name="$(grep -Eo 'WG_HOSTNAME=[^[:space:]]+' "${privateerr_run_log_path}" | tail -n 1 | cut -d '=' -f 2- || true)"

#
# Start with useful fallbacks from the run itself. The server-list lookup below
# will enrich these values when it can, but the same-run hostname is the most
# trustworthy clue because it came from the script that generated wg0.conf.
#
region_id="unknown"
region_name="unknown"
port_forwarding_supported="${PIA_PF:-unknown}"
geolocated_region="unknown"

#
# Fetch PIA's server list and match the generated endpoint IP back to its TLS
# server name. Gluetun needs that name as SERVER_NAMES when using PIA port
# forwarding with a custom WireGuard provider.
#
server_data="$(curl -fsSL --connect-timeout 10 --max-time 20 "${PRIVATEERR_SERVERLIST_URL}" | sed -n '1p' || true)"

#
# Parse the server metadata from the fetched data.
#
server_metadata="$(printf '%s' "${server_data}" | jq -r --arg ENDPOINT_IP "${endpoint_ip}" --arg WG_SERVER_NAME "${wg_server_name}" '
    .regions[]
    | select(any(.servers.wg[]?; .ip == $ENDPOINT_IP or .cn == $WG_SERVER_NAME))
    |   {
            id,
            name,
            port_forward,
            geo,
            wg: (.servers.wg[] | select(.ip == $ENDPOINT_IP or .cn == $WG_SERVER_NAME))
        }
    |   [
            .id,
            .name,
            (.port_forward | tostring),
            (.geo | tostring),
            .wg.cn
        ]
    | @tsv
' 2>/dev/null | head -n 1 || true)"

#
# If the server metadata was found, extract the values into variables.
#
if [[ -n "${server_metadata}" ]]; then
    IFS=$'\t' read -r region_id region_name port_forwarding_supported geolocated_region matched_wg_server_name <<< "${server_metadata}"

    # If the matched WireGuard server name is not empty or "null", use it as the authoritative value.
    if [[ -n "${matched_wg_server_name}" && "${matched_wg_server_name}" != "null" ]]; then
        wg_server_name="${matched_wg_server_name}"
    fi
fi

#
# Validate that the WireGuard TLS server name was found. This is critical for Gluetun port forwarding.
#
if [[ -z "${wg_server_name}" || "${wg_server_name}" == "null" ]]; then
    log_privateerr "Privateerr found ${endpoint_ip}, but could not find the WireGuard TLS server name."
    exit 1
fi

#
# dotenv_escape: Escape one value for a double-quoted dotenv assignment.
#
# Parameters: $1 - Raw dotenv value.
#
# Returns: Prints the escaped value.
#
dotenv_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

#
# Write an env file that downstream projects can source or pass to Compose.
#
cat > "${PRIVATEERR_METADATA_PATH}" <<EOF
#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# Generated by Privateerr. Do not edit manually.
#
PIA_WG_SERVER_NAME=${wg_server_name}
PIA_WG_ENDPOINT_IP=${endpoint_ip}
PIA_WG_ENDPOINT_PORT=${endpoint_port}
PIA_REGION_ID=${region_id}
PIA_REGION_NAME="$(dotenv_escape "${region_name}")"
PIA_PORT_FORWARDING_SUPPORTED=${port_forwarding_supported}
PIA_GEOLOCATED_REGION=${geolocated_region}
EOF

log_privateerr "Privateerr wrote WireGuard config: ${PIA_CONF_PATH}"
log_privateerr "Privateerr wrote Gluetun metadata: ${PRIVATEERR_METADATA_PATH}"
log_privateerr "PIA_WG_SERVER_NAME=${wg_server_name}"
