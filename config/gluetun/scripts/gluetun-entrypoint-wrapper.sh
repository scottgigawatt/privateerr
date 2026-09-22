#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# gluetun-entrypoint-wrapper.sh: Prepare generated PIA settings and optional recovery access before starting Gluetun.
#
# Usage: gluetun-entrypoint-wrapper.sh
#
# The script:
#   - Waits for Privateerr to finish saving its configuration and privateerr.env.
#   - Reads PIA_WG_SERVER_NAME from the generated metadata file.
#   - Exports SERVER_NAMES for Gluetun's custom WireGuard provider.
#   - When recovery is enabled, configures API authentication and the shared health listener.
#   - Disables Gluetun health-triggered restarts only when Privateerr owns recovery.
#   - Preserves an operator-supplied API authentication file.
#   - Executes Gluetun's original entrypoint.
#

#
# Exit immediately if a command exits with a non-zero status, and treat unset variables as an error.
#
set -eu

#
# Default script settings.
#
: "${PRIVATEERR_METADATA_PATH:=/gluetun/wireguard/privateerr.env}"
: "${GLUETUN_DEFAULT_ENTRYPOINT:=/gluetun-entrypoint}"
: "${PRIVATEERR_GLUETUN_METADATA_WAIT_SECONDS:=120}"
: "${PRIVATEERR_AUTO_RECOVER:=false}"

#
# Script state used for consistent log output and wait tracking.
#
gluetun_script_name="gluetun-entrypoint-wrapper.sh"
elapsed_seconds=0

#
# log: Prefix wrapper lines so they are distinct from Gluetun output.
#
# Parameters: $* - Message fragments to write as one log line.
#
# Returns: printf's exit status.
#
log() {
    printf '[%s] %s\n' "${gluetun_script_name}" "$*"
}

#
# Wait for Privateerr to write metadata before Gluetun reads its settings.
#
while [ ! -s "${PRIVATEERR_METADATA_PATH}" ] || [ -d "$(dirname "${PRIVATEERR_METADATA_PATH}")/.privateerr-commit" ]; do

    #
    # If the metadata file is not found within the expected time, log an error and exit.
    #
    if [ "${elapsed_seconds}" -ge "${PRIVATEERR_GLUETUN_METADATA_WAIT_SECONDS}" ]; then
        log "Privateerr metadata was not found at ${PRIVATEERR_METADATA_PATH}." >&2
        exit 1
    fi

    #
    # Log the wait status and sleep for 2 seconds before checking again.
    #
    log "Waiting for Privateerr metadata: ${PRIVATEERR_METADATA_PATH}"
    sleep 2
    elapsed_seconds=$((elapsed_seconds + 2))
done

#
# Enable private network access only when recovery is explicitly requested.
# An operator-supplied auth file remains authoritative for customized deployments.
#
if [ "${PRIVATEERR_AUTO_RECOVER}" = true ]; then

    #
    # Prevent Gluetun health-triggered restarts from racing Privateerr settings updates.
    #
    HEALTH_RESTART_VPN=off
    export HEALTH_RESTART_VPN
    log "Privateerr owns sustained-outage recovery; Gluetun health-triggered restarts are disabled."

    #
    # Reject characters that cannot be written safely into the API authentication file.
    #
    case "${PRIVATEERR_GLUETUN_API_KEY:-}" in
        *[!A-Za-z0-9]*|"")
            log "PRIVATEERR_GLUETUN_API_KEY must contain only letters and numbers." >&2
            exit 1
            ;;
    esac

    #
    # Require the same API key length accepted by the Privateerr monitor.
    #
    if [ "${#PRIVATEERR_GLUETUN_API_KEY}" -lt 20 ] || [ "${#PRIVATEERR_GLUETUN_API_KEY}" -gt 128 ]; then
        log "PRIVATEERR_GLUETUN_API_KEY must contain 20-128 characters." >&2
        exit 1
    fi

    #
    # Create a recovery role only when no operator-supplied authentication file takes precedence.
    #
    if [ "${HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH:-/gluetun/auth/config.toml}" = /gluetun/auth/config.toml ] \
        && [ ! -e /gluetun/auth/config.toml ]; then

        #
        # Restrict the generated API authentication file to its owner.
        #
        umask 077
        HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH=/tmp/privateerr-control-auth.toml
        cat > "${HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH}" <<AUTH
#
# Privateerr's narrowly scoped recovery role; generated on each Gluetun start.
#
[[roles]]
name = "privateerr"
routes = ["GET /v1/vpn/status", "GET /v1/vpn/settings", "PUT /v1/vpn/settings", "GET /v1/portforward"]
auth = "apikey"
apikey = "${PRIVATEERR_GLUETUN_API_KEY}"
AUTH
        export HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH
    fi

    #
    # Expose the default health listener to containers on the shared Docker network.
    #
    if [ "${HEALTH_SERVER_ADDRESS:-127.0.0.1:9999}" = "127.0.0.1:9999" ]; then
        HEALTH_SERVER_ADDRESS=0.0.0.0:9999
        export HEALTH_SERVER_ADDRESS
    fi

fi

#
# Load the generated server name from the operator-configured metadata path.
#
# shellcheck disable=SC1090
. "${PRIVATEERR_METADATA_PATH}"

#
# Validate that the expected PIA_WG_SERVER_NAME variable is set in the metadata.
#
if [ -z "${PIA_WG_SERVER_NAME:-}" ]; then
    log "PIA_WG_SERVER_NAME is missing from ${PRIVATEERR_METADATA_PATH}." >&2
    exit 1
fi

#
# Export SERVER_NAMES for Gluetun's custom WireGuard provider.
#
export SERVER_NAMES="${PIA_WG_SERVER_NAME}"

log "Gluetun received SERVER_NAMES=${SERVER_NAMES} from Privateerr metadata. 🧭"

#
# Execute Gluetun's original entrypoint to start the VPN client.
#
exec "${GLUETUN_DEFAULT_ENTRYPOINT}"
