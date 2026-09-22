#!/usr/bin/env bash

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test-recovery.sh: Exercise recovery decisions with isolated configuration and API fixtures.
#
# Usage: test/helpers/test-recovery.sh
#
# The script:
#   - Builds isolated example configuration and metadata files.
#   - Checks validation, interrupted saves, and uncertain API updates.
#   - Verifies region selection and recovery timing with simulated API responses.
#   - Uses a virtual clock so the monitor scenarios need no network or real delays.
#

#
# Fail on command errors, unset variables, and failed assertions in pipelines.
#
set -euo pipefail

#
# Keep test files in an isolated temporary directory.
#
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_root="$(mktemp -d)"
export PRIVATEERR_BIN_HOME="${repo_root}/docker"
export PIA_CONF_PATH="${test_root}/wireguard/wg0.conf"
export PRIVATEERR_METADATA_PATH="${test_root}/wireguard/privateerr.env"
export PRIVATEERR_LOG_PATH="${test_root}/privateerr.log"
export PRIVATEERR_HEALTHCHECK_MARKER="${test_root}/ready"
PRIVATEERR_GLUETUN_API_KEY="$(printf '%040d' 1)"
export PRIVATEERR_GLUETUN_API_KEY
export PRIVATEERR_KEEPALIVE=true
export PIA_CONNECT=false
export VPN_PROTOCOL=wireguard
export PREFERRED_REGION=ca
export PIA_PF=true
export AUTOCONNECT=false
mkdir "${test_root}/wireguard"

#
# Locate the entrypoint and its recovery library relative to this test script.
#
# shellcheck source-path=SCRIPTDIR/../../docker
# shellcheck source=privateerr-entrypoint.sh
source "${PRIVATEERR_BIN_HOME}/privateerr-entrypoint.sh"
trap 'cleanup_privateerr; rm -rf "${test_root}"' EXIT
configure_recovery

#
# fixture: Write a complete pair with generated test-only key material.
#
# Parameters: $1 - Output directory.
#             $2 - Endpoint IPv4 address.
#             $3 - PIA TLS server name.
#
# Returns: 0 after creating the files.
#
fixture() {
    mkdir -p "$1"
    local key
    key="$(printf '%032d' 1 | base64 | tr -d '\n')"
    cat > "$1/wg0.conf" <<CONFIG
[Interface]
PrivateKey = ${key}
Address = 10.0.0.2
[Peer]
PublicKey = ${key}
Endpoint = $2:1337
CONFIG
    cat > "$1/privateerr.env" <<METADATA
PIA_WG_SERVER_NAME=$3
PIA_WG_ENDPOINT_IP=$2
PIA_WG_ENDPOINT_PORT=1337
PIA_REGION_ID=ca
METADATA
    jq -en --rawfile config "$1/wg0.conf" --rawfile metadata "$1/privateerr.env" \
        -f "${PRIVATEERR_BIN_HOME}/privateerr-vpn-settings.jq" > "$1/settings.json"
}

#
# Confirm valid files produce matching connection fields before testing duplicate rejection.
#
fixture "${test_root}/wireguard" 198.51.100.10 example-one
jq -e '.wireguard.addresses == ["10.0.0.2/32"] and .provider.server_selection.names == ["example-one"]' \
    "${test_root}/wireguard/settings.json" >/dev/null
cp "${test_root}/wireguard/settings.json" "${privateerr_runtime}/active.json"
printf '\nPIA_WG_ENDPOINT_PORT=9999\n' >> "${test_root}/wireguard/privateerr.env"

#
# Reject duplicate metadata fields instead of accepting an ambiguous configuration.
#
if jq -en --rawfile config "${PIA_CONF_PATH}" --rawfile metadata "${PRIVATEERR_METADATA_PATH}" \
    -f "${PRIVATEERR_BIN_HOME}/privateerr-vpn-settings.jq" >/dev/null 2>&1; then
    echo 'FAIL: duplicate metadata accepted' >&2
    exit 1
fi

fixture "${test_root}/wireguard" 198.51.100.10 example-one

#
# An interrupted save retains both source files so the next start can finish replacing them.
#
fixture "${test_root}/candidate" 198.51.100.11 example-two
publish_privateerr "${test_root}/candidate"
cmp "${PIA_CONF_PATH}" "${test_root}/candidate/wg0.conf"
mkdir "${test_root}/wireguard/.privateerr-commit"
cp "${test_root}/wireguard/"{wg0.conf,privateerr.env} "${test_root}/wireguard/.privateerr-commit/"
touch "${test_root}/wireguard/.privateerr-commit/ready"
publish_privateerr "${test_root}/wireguard/.privateerr-commit"
[[ ! -e "${test_root}/wireguard/.privateerr-commit" ]]

api_available=true
api_match=true
tunnel_healthy=false
api_calls="${test_root}/api-calls"
: > "${api_calls}"

#
# gluetun_api: Simulate API outages, explicit stops, and settings acknowledgements.
#
# Parameters: $1 - HTTP method.
#             $2 - Route.
#             $3 - Response destination.
#             $4 - Optional request file.
#
# Returns: 0 for a response, 1 for a simulated API outage.
#
gluetun_api() {
    printf '%s %s\n' "$1" "$2" >> "${api_calls}"
    [[ "${api_available}" == true ]] || return 1

    #
    # Return the response fixture for the requested API route.
    #
    case "$2" in
        /v1/vpn/status)
            printf '{"status":"%s"}\n' "${api_status:-running}" > "$3"
            ;;
        /v1/vpn/settings)

            #
            # Simulate an accepted update with a lost response, or return the selected settings fixture.
            #
            if [[ "$1" == PUT ]]; then
                cp "$4" "${test_root}/applied.json"
                return 1
            elif [[ "${api_match}" == true ]]; then
                cp "${test_root}/candidate/settings.json" "$3"
            else
                cp "${test_root}/wireguard/settings.json" "$3"
            fi

            ;;
        /v1/portforward)
            printf '{"port":12345}\n' > "$3"
            ;;
    esac

}

#
# gluetun_healthy: Return the fixture's tunnel health independently of process state.
#
# Parameters: None.
#
# Returns: 0 for healthy, 1 for unhealthy.
#
gluetun_healthy() {
    [[ "${tunnel_healthy}" == true ]]
}

#
# Preserve pending files until the API confirms both applied settings and tunnel health.
#
fixture "${privateerr_pending}" 198.51.100.11 example-two
touch "${privateerr_pending}/ready"
api_available=false
result=0
resolve_pending || result=$?
[[ "${result}" == 1 && -f "${privateerr_pending}/ready" ]]
api_available=true
result=0
resolve_pending || result=$?
[[ "${result}" == 2 && -f "${privateerr_pending}/ready" ]]
tunnel_healthy=true
resolve_pending
[[ ! -e "${privateerr_pending}" ]]
cmp "${PIA_CONF_PATH}" "${test_root}/candidate/wg0.conf"
fixture "${privateerr_pending}" 198.51.100.11 example-two
touch "${privateerr_pending}/ready"
api_match=false
resolve_pending
[[ ! -e "${privateerr_pending}" ]]

#
# Endpoint selection stays in a pinned region and skips endpoints already tried.
#
cat > "${test_root}/catalog" <<'CATALOG'
{"regions":[{"id":"ca","port_forward":true,"servers":{"wg":[{"ip":"198.51.100.10","cn":"example-one"},{"ip":"198.51.100.11","cn":"example-two"}]}},{"id":"ca_toronto","port_forward":true,"servers":{"wg":[{"ip":"198.51.100.12","cn":"example-three"}]}},{"id":"no_pf","port_forward":false,"servers":{"wg":[{"ip":"198.51.100.13","cn":"example-four"}]}}]}
CATALOG

#
# curl: Supply the server catalog without performing network requests.
#
# Parameters: $* - Ignored curl arguments.
#
# Returns: 0 after printing the catalog.
#
curl() {
    cat "${test_root}/catalog"
}

#
# Try unused endpoints first, then the current endpoint, without leaving a pinned region.
#
cp "${test_root}/wireguard/settings.json" "${privateerr_runtime}/active.json"
: > "${privateerr_failed_ips}"
select_recovery_endpoint
[[ "${PRIVATEERR_CANDIDATE_IP}" == 198.51.100.11 ]]
printf '198.51.100.11\n' >> "${privateerr_failed_ips}"
select_recovery_endpoint
[[ "${PRIVATEERR_CANDIDATE_IP}" == 198.51.100.10 ]]
AUTOCONNECT=true
select_recovery_endpoint
[[ "${PRIVATEERR_CANDIDATE_IP}" == 198.51.100.12 ]]
DIP_TOKEN=test-only-dedicated-token
select_recovery_endpoint
[[ -z "${PRIVATEERR_CANDIDATE_IP:-}" ]]
unset DIP_TOKEN

#
# Run the real monitor's decisions with a virtual clock, without sleeping.
#
PRIVATEERR_RECOVERY_INTERVAL_SECONDS=1
PRIVATEERR_RECOVERY_FAILURE_SECONDS=2
PRIVATEERR_RECOVERY_COOLDOWN_SECONDS=5
recoveries="${test_root}/recoveries"
: > "${recoveries}"

#
# recover_gluetun: Record recovery attempts without generating credentials.
#
# Parameters: None.
#
# Returns: 1 to exercise retry backoff.
#
recover_gluetun() {
    printf '%s\n' "${SECONDS}" >> "${recoveries}"
    return 1
}

#
# wait_privateerr: Advance a virtual clock and end a bounded monitor scenario.
#
# Parameters: $1 - Requested wait in seconds.
#
# Returns: 0 until the scenario ends, then exits the monitor subshell.
#
wait_privateerr() {
    SECONDS=$((SECONDS + $1))
    (( SECONDS < 20 )) || exit 0

    #
    # Simulate brief stopped states during repeated internal VPN restarts.
    #
    if [[ "${cycling:-false}" == true ]]; then
        api_status=running
        (( SECONDS % 3 != 0 )) || api_status=stopped
    fi

    #
    # Restore health before the sustained-failure threshold in the transient scenario.
    #
    if [[ "${transient:-false}" == true && "${SECONDS}" -gt 3 ]]; then
        tunnel_healthy=true
    fi

}

#
# Run each health, API, and process-state scenario against the real monitor.
#
for scenario in healthy transient stopped unavailable sustained cycling; do
    api_available=true
    api_status=running
    tunnel_healthy=false
    transient=false
    cycling=false

    #
    # Set the condition that distinguishes this scenario from sustained failure.
    #
    case "${scenario}" in
        healthy)
            tunnel_healthy=true
            ;;
        transient)
            transient=true
            ;;
        cycling)
            cycling=true
            ;;
        stopped)
            api_status=stopped
            ;;
        unavailable)
            api_available=false
            ;;
    esac

    : > "${recoveries}"
    ( trap - EXIT; SECONDS=0; monitor_gluetun ) > "${test_root}/monitor.log"

    #
    # Check that only sustained outages recover and that retries respect the cooldown.
    #
    if [[ "${scenario}" == cycling ]]; then
        [[ -s "${recoveries}" ]]
    elif [[ "${scenario}" == sustained ]]; then
        [[ "$(wc -l < "${recoveries}" | tr -d ' ')" == 3 ]]
        awk 'NR == 2 {if ($1 - previous < 5) exit 1} NR == 3 {if ($1 - previous < 10) exit 1} {previous=$1}' "${recoveries}"
    else
        [[ ! -s "${recoveries}" ]]
    fi

done

printf 'Recovery tests passed: validation, publication, reconciliation, region selection, pause and backoff.\n'
