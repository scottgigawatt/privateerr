#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# qbittorrent-port-forwarding.sh: Keep qBittorrent bound to Gluetun's forwarded port.
#
# Usage: qbittorrent-port-forwarding.sh up <port> <vpn-interface> | down
#
# The script:
#   - Waits for qBittorrent's Web API to become reachable on localhost.
#   - Sets the qBittorrent listening port to Gluetun's forwarded port.
#   - Pins qBittorrent to Gluetun's VPN interface.
#   - Disables random ports and UPnP port mapping.
#   - Resets the port and interface when port forwarding is removed.
#

#
# Stop on failed API updates and reject unset variables.
#
set -eu

#
# Default script settings.
#
: "${QBITTORRENT_API_URL:=http://127.0.0.1:8080}"
: "${QBITTORRENT_API_WAIT_SECONDS:=120}"

#
# Script state used for consistent log output.
#
script_name="qbittorrent-port-forwarding.sh"

#
# log: Print a consistent status line.
#
# Parameters: $* - Message fragments to write as one status line.
#
# Returns: 0 after writing the line.
#
log() {
    printf '[%s] %s\n' "${script_name}" "$*"
}

#
# qbittorrent_api: Send a qBittorrent Web API request.
#
# Parameters: $1 - API path.
#             $2 - Optional POST payload.
#
# Returns: wget's exit status and response body on standard output.
#
qbittorrent_api() {
    api_path="$1"
    post_data="${2:-}"

    # Use POST only when the caller supplied preference changes.

    if [ -n "${post_data}" ]; then
        wget -T 5 -q -O - --post-data "${post_data}" "${QBITTORRENT_API_URL}${api_path}"
    else
        wget -T 5 -q -O - "${QBITTORRENT_API_URL}${api_path}"
    fi
}

#
# wait_for_qbittorrent: Wait for qBittorrent to answer Web API requests.
#
# Parameters: None.
#
# Returns: 0 when reachable; exits nonzero after the configured timeout.
#
wait_for_qbittorrent() {
    deadline_seconds=$(($(date +%s) + QBITTORRENT_API_WAIT_SECONDS))

    # Allow qBittorrent to start after Gluetun becomes healthy.

    while ! qbittorrent_api "/api/v2/app/preferences" >/dev/null 2>&1; do
        # Stop retrying when the total startup allowance expires.

        if [ "$(date +%s)" -ge "${deadline_seconds}" ]; then
            log "qBittorrent Web API did not become ready at ${QBITTORRENT_API_URL}."
            exit 1
        fi

        log "Waiting for qBittorrent Web API."
        sleep 2
    done
}

#
# set_forwarded_port: Apply Gluetun's forwarded port to qBittorrent.
#
# Parameters: $1 - Forwarded TCP/UDP port.
#             $2 - VPN interface name.
#
# Returns: 0 after updating qBittorrent; exits nonzero for invalid input.
#
set_forwarded_port() {
    forwarded_port="$1"
    vpn_interface="$2"

    # Reject malformed ports before composing the JSON request.

    if ! printf '%s' "${forwarded_port}" | grep -Eq '^[0-9]+$'; then
        log "Forwarded port is not numeric: ${forwarded_port}"
        exit 1
    fi

    # Accept only usable TCP and UDP port numbers.

    if [ "${forwarded_port}" -lt 1 ] || [ "${forwarded_port}" -gt 65535 ]; then
        log "Forwarded port is outside valid range: ${forwarded_port}"
        exit 1
    fi

    # Accept only safe interface names and exclude the loopback interface.

    if ! printf '%s' "${vpn_interface}" | grep -Eq '^[A-Za-z0-9_-]+$' || [ "${vpn_interface}" = "lo" ]; then
        log "VPN interface is invalid: ${vpn_interface}"
        exit 1
    fi

    wait_for_qbittorrent

    preferences_json="$(printf '{"listen_port":%s,"current_network_interface":"%s","random_port":false,"upnp":false}' "${forwarded_port}" "${vpn_interface}")"
    qbittorrent_api "/api/v2/app/setPreferences" "json=${preferences_json}" >/dev/null

    log "Set qBittorrent listen_port=${forwarded_port} on ${vpn_interface}."
}

#
# reset_forwarded_port: Reset qBittorrent when Gluetun drops the forwarded port.
#
# Parameters: None.
#
# Returns: 0 after applying the safe local-only defaults.
#
reset_forwarded_port() {
    wait_for_qbittorrent

    preferences_json='{"listen_port":0,"current_network_interface":"lo"}'
    qbittorrent_api "/api/v2/app/setPreferences" "json=${preferences_json}" >/dev/null

    log "Reset qBittorrent listen_port and network interface."
}

#
# Dispatch supported commands.
#
case "${1:-}" in
    up)
        set_forwarded_port "${2:-}" "${3:-}"
        ;;
    down)
        reset_forwarded_port
        ;;
    *)
        log "Usage: $0 up <port> <vpn-interface> | down"
        exit 1
        ;;
esac
