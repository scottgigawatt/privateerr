#!/usr/bin/env bash

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# buccaneerr-entrypoint.sh: This script validates the Privateerr e2e stack.
#
# The script:
#   - Verifies Privateerr generated wg0.conf.
#   - Verifies Privateerr generated privateerr.env.
#   - Checks Gluetun's unauthenticated health endpoint.
#   - Checks Gluetun's forwarded_port file when port forwarding is required.
#   - Writes validation output to stdout and the Buccaneerr log file.
#

#
# Fail on any error, unset variable, or failed pipe command.
#
set -euo pipefail

#
# Script name for consistent log output.
#
buccaneerr_script_name="buccaneerr-entrypoint.sh"

#
# Default validation settings.
#
: "${BUCCANEERR_CONFIG_PATH:=/config}"
: "${BUCCANEERR_GLUETUN_PATH:=/gluetun}"
: "${BUCCANEERR_HEALTH_URL:=http://127.0.0.1:9999}"
: "${BUCCANEERR_REQUIRE_PORT_FORWARD:=true}"
: "${BUCCANEERR_LOG_PATH:=/buccaneerr-config/logs/buccaneerr.log}"

#
# Ensure the log directory exists before writing validation output.
#
mkdir -p "$(dirname "${BUCCANEERR_LOG_PATH}")"
: > "${BUCCANEERR_LOG_PATH}"

#
# Print a consistent status line for CI logs and the persisted log file.
#
log() {
    printf '[%s] %s\n' "${buccaneerr_script_name}" "$*" \
        | tee -a "${BUCCANEERR_LOG_PATH}"
}

#
# Make sure a file exists and is not empty.
#
require_file() {
    file_path="$1"
    file_label="$2"

    if [[ ! -s "${file_path}" ]]; then
        log "Missing ${file_label}: ${file_path}"
        exit 1
    fi
}

#
# Confirm Privateerr produced the expected config and metadata files.
#
wg_config_path="${BUCCANEERR_CONFIG_PATH}/wg0.conf"
metadata_path="${BUCCANEERR_CONFIG_PATH}/privateerr.env"
forwarded_port_path="${BUCCANEERR_GLUETUN_PATH}/forwarded_port"

log "Inspecting generated WireGuard config."
require_file "${wg_config_path}" "WireGuard config"
grep -q '^PrivateKey[[:space:]]*=' "${wg_config_path}"
grep -q '^PublicKey[[:space:]]*=' "${wg_config_path}"
grep -q '^Endpoint[[:space:]]*=' "${wg_config_path}"

log "Inspecting generated Gluetun metadata."
require_file "${metadata_path}" "Privateerr metadata"
grep -q '^PIA_WG_SERVER_NAME=' "${metadata_path}"
grep -q '^PIA_WG_ENDPOINT_IP=' "${metadata_path}"
grep -q '^PIA_PORT_FORWARDING_SUPPORTED=true' "${metadata_path}"

#
# Ask Gluetun's unauthenticated health server whether the VPN is alive.
#
log "Checking Gluetun VPN status."
curl -fsSL "${BUCCANEERR_HEALTH_URL}" >/dev/null

#
# Use Gluetun's forwarded_port file because the control API may require auth.
#
if [[ "${BUCCANEERR_REQUIRE_PORT_FORWARD}" == "true" ]]; then
    log "Checking Gluetun forwarded port."
    forwarded_port=""

    # Wait up to 30 seconds for Gluetun to write the forwarded_port file.
    for _ in {1..30}; do
        # If the file exists and is not empty, read the port number and break the loop.
        if [[ -s "${forwarded_port_path}" ]]; then
            forwarded_port="$(tr -dc '0-9' < "${forwarded_port_path}")"
            break
        fi
        sleep 1
    done

    # If the file is still missing or empty, fail the validation.
    if ! [[ "${forwarded_port}" =~ ^[0-9]+$ ]] || [[ "${forwarded_port}" -lt 1 ]] || [[ "${forwarded_port}" -gt 65535 ]]; then
        log "No valid forwarded port came back from Gluetun."
        exit 1
    fi

    log "Forwarded port is ${forwarded_port}."
fi

log "All checks passed. The WireGuard map floats, the tunnel breathes, and the port be plundered."
