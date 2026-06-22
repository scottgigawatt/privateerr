#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# gluetun-entrypoint-wrapper.sh: This script waits for Privateerr metadata,
#                                then starts Gluetun with the generated PIA
#                                WireGuard server name.
#
# The script:
#   - Waits for Privateerr to write privateerr.env.
#   - Reads PIA_WG_SERVER_NAME from the generated metadata file.
#   - Exports SERVER_NAMES for Gluetun's custom WireGuard provider.
#   - Executes Gluetun's original entrypoint.
#

#
# Exit immediately if a command exits with a non-zero status, and treat unset variables as an error.
#
set -eu

#
# Name of this wrapper script for logging purposes.
#
wrapper_script_name="gluetun-entrypoint-wrapper.sh"
elapsed_seconds=0

#
# Default wrapper settings.
#
: "${PRIVATEERR_METADATA_PATH:=/gluetun/wireguard/privateerr.env}"
: "${GLUETUN_DEFAULT_ENTRYPOINT:=/gluetun-entrypoint}"
: "${PRIVATEERR_GLUETUN_METADATA_WAIT_SECONDS:=120}"

#
# Prefix wrapper log lines so they are distinct from Gluetun output.
#
log() {
    printf '[%s] %s\n' "${wrapper_script_name}" "$*"
}

#
# Wait for Privateerr to write metadata before Gluetun reads its settings.
#
while [ ! -s "${PRIVATEERR_METADATA_PATH}" ]; do
    # If the metadata file is not found within the expected time, log an error and exit.
    if [ "${elapsed_seconds}" -ge "${PRIVATEERR_GLUETUN_METADATA_WAIT_SECONDS}" ]; then
        log "Privateerr metadata was not found at ${PRIVATEERR_METADATA_PATH}." >&2
        exit 1
    fi

    log "Waiting for Privateerr metadata: ${PRIVATEERR_METADATA_PATH}"
    sleep 2
    elapsed_seconds=$((elapsed_seconds + 2))
done

#
# shellcheck disable=SC1090
#
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
