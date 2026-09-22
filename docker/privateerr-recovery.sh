#!/usr/bin/env bash

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# privateerr-recovery.sh: Monitor Gluetun and replace stale PIA settings through its API.
#
# Usage: Sourced by privateerr-entrypoint.sh; requires its logging and generation helpers.
#
# The script:
#   - Validates recovery settings and prepares authenticated Gluetun API requests.
#   - Waits for sustained tunnel failure before generating a replacement registration.
#   - Respects region preferences and dedicated IP configuration when choosing endpoints.
#   - Confirms uncertain API updates before saving the matching configuration pair.
#   - Pauses for stopped VPNs and backs off after failed recovery attempts.
#

#
# configure_recovery: Validate opt-in configuration and prepare private API authentication.
#
# Parameters: None.
#
# Returns: 0 for valid settings; exits with an actionable error otherwise.
#
configure_recovery() {

    #
    # Supply monitoring defaults without requiring changes to existing environment files.
    #
    : "${PRIVATEERR_GLUETUN_URL:=http://gluetun:8000}"
    : "${PRIVATEERR_GLUETUN_HEALTH_URL:=http://gluetun:9999}"
    : "${PRIVATEERR_RECOVERY_INTERVAL:=30}"
    : "${PRIVATEERR_RECOVERY_FAILURE_SECONDS:=120}"
    : "${PRIVATEERR_RECOVERY_COOLDOWN:=300}"
    : "${PRIVATEERR_SERVERLIST_URL:=https://serverlist.piaservers.net/vpninfo/servers/v6}"

    #
    # Require generation-only WireGuard mode and a persistent monitor process.
    #
    if [[ "${PRIVATEERR_KEEPALIVE}" != true || "${PIA_CONNECT:-false}" != false || "${VPN_PROTOCOL:-wireguard}" != wireguard ]]; then
        log_privateerr "Recovery requires PRIVATEERR_KEEPALIVE=true, PIA_CONNECT=false and VPN_PROTOCOL=wireguard."
        exit 1
    fi

    #
    # Reject missing or malformed shared API keys before making requests.
    #
    if [[ ! "${PRIVATEERR_GLUETUN_API_KEY:-}" =~ ^[A-Za-z0-9]{20,128}$ ]]; then
        log_privateerr "Set PRIVATEERR_GLUETUN_API_KEY to a shared 20-128 character alphanumeric API key."
        exit 1
    fi

    local setting

    #
    # Validate each recovery timing value as a positive number of seconds.
    #
    for setting in PRIVATEERR_RECOVERY_INTERVAL PRIVATEERR_RECOVERY_FAILURE_SECONDS PRIVATEERR_RECOVERY_COOLDOWN; do

        #
        # Reject zero, negative, or excessively large timing values.
        #
        if [[ ! "${!setting}" =~ ^[1-9][0-9]{0,3}$ ]]; then
            log_privateerr "${setting} must be between 1 and 9999 seconds."
            exit 1
        fi

    done

    #
    # Validate control and health URLs before passing them to curl.
    #
    for setting in PRIVATEERR_GLUETUN_URL PRIVATEERR_GLUETUN_HEALTH_URL; do

        #
        # Allow only an HTTP(S) hostname and port without embedded credentials or paths.
        #
        if [[ ! "${!setting}" =~ ^https?://[A-Za-z0-9.-]+:[0-9]+/?$ ]]; then
            log_privateerr "${setting} must be an HTTP(S) host and port without credentials or a path."
            exit 1
        fi

    done

    #
    # Require both recovery files to share the directory used for pending updates.
    #
    if [[ "$(dirname "${PIA_CONF_PATH}")" != "$(dirname "${PRIVATEERR_METADATA_PATH}")" ]]; then
        log_privateerr "Recovery requires the WireGuard configuration and metadata in the same mounted directory."
        exit 1
    fi

    #
    # Keep the API key in a private curl config instead of command-line arguments.
    #
    PRIVATEERR_GLUETUN_URL="${PRIVATEERR_GLUETUN_URL%/}"
    # shellcheck disable=SC2154 # privateerr_runtime is created by the sourcing entrypoint.
    printf 'header = "X-API-Key: %s"\n' "${PRIVATEERR_GLUETUN_API_KEY}" > "${privateerr_runtime}/curl-auth"

    #
    # Track an unconfirmed update on disk and failed endpoints for this process.
    #
    privateerr_pending="$(dirname "${PIA_CONF_PATH}")/.privateerr-pending"
    privateerr_failed_ips="${privateerr_runtime}/failed-ips"
    touch "${privateerr_failed_ips}"
    privateerr_last_message=""
}

#
# recovery_status: Log only state transitions to avoid repeating unavailable-service warnings.
#
# Parameters: $* - Public status message.
#
# Returns: 0.
#
recovery_status() {

    #
    # Write a diagnostic only when the monitor status changes.
    #
    if [[ "$*" != "${privateerr_last_message}" ]]; then
        log_privateerr "$*"
        privateerr_last_message="$*"
    fi

}

#
# gluetun_api: Make a bounded authenticated request without exposing its body in logs.
#
# Parameters: $1 - HTTP method.
#             $2 - API route.
#             $3 - Destination file for the response.
#             $4 - Optional JSON request file.
#
# Returns: 0 for HTTP 200; nonzero for transport or HTTP errors.
#
gluetun_api() {
    local method="$1" route="$2" output="$3" code
    local -a body=()
    [[ -z "${4:-}" ]] || body=(--header 'Content-Type: application/json' --data-binary "@$4")

    #
    # Bound both connection setup and the complete request.
    #
    code="$(curl --silent --connect-timeout 5 --max-time 30 \
        --config "${privateerr_runtime}/curl-auth" --request "${method}" \
        ${body[@]+"${body[@]}"} --output "${output}" --write-out '%{http_code}' \
        "${PRIVATEERR_GLUETUN_URL}${route}")" || return 1
    [[ "${code}" == 200 ]]
}

#
# gluetun_healthy: Query the tunnel health server rather than the VPN process status.
#
# Parameters: None.
#
# Returns: 0 only for HTTP 200.
#
gluetun_healthy() {
    local code

    #
    # Bound both connection setup and the complete request.
    #
    code="$(curl --silent --connect-timeout 5 --max-time 10 --output /dev/null \
        --write-out '%{http_code}' "${PRIVATEERR_GLUETUN_HEALTH_URL}")" || return 1
    [[ "${code}" == 200 ]]
}

#
# resolve_pending: Reconcile a possibly timed-out settings update before attempting another.
#
# Parameters: None.
#
# Returns: 0 when resolved or absent; 1 when the API is unavailable; 2 while the candidate is unhealthy.
#
resolve_pending() {

    #
    # No reconciliation is needed when no candidate was submitted.
    #
    [[ -d "${privateerr_pending}" ]] || return 0

    #
    # Discard a candidate that was interrupted before all of its files were copied.
    #
    if [[ ! -f "${privateerr_pending}/ready" ]]; then
        rm -rf -- "${privateerr_pending}"
        return 0
    fi

    #
    # Read the actual settings before deciding whether to keep or replace a candidate.
    #
    gluetun_api GET /v1/vpn/settings "${privateerr_runtime}/active.json" || return 1

    #
    # Keep saved files unchanged when Gluetun did not apply the pending candidate.
    #
    if ! jq -e --slurpfile candidate "${privateerr_pending}/settings.json" \
        'contains($candidate[0])' "${privateerr_runtime}/active.json" >/dev/null; then
        recovery_status "Gluetun did not retain the pending settings; keeping the last saved configuration."
        rm -rf -- "${privateerr_pending}"
        return 0
    fi

    #
    # Save the candidate only after the API settings match and the tunnel is healthy.
    #
    gluetun_healthy || return 2
    publish_privateerr "${privateerr_pending}" || return 1
    rm -rf -- "${privateerr_pending}"
    : > "${privateerr_failed_ips}"
    log_privateerr "Gluetun tunnel recovered; saved the matching WireGuard configuration and PIA metadata."

    #
    # Report forwarding separately so it cannot trigger rotation of a healthy tunnel.
    #
    if [[ "${PIA_PF:-false}" == true ]]; then

        #
        # Check whether Gluetun has already obtained a forwarded port.
        #
        if gluetun_api GET /v1/portforward "${privateerr_runtime}/port.json" && \
            jq -e '.port > 0' "${privateerr_runtime}/port.json" >/dev/null; then
            log_privateerr "Gluetun reports an assigned forwarded port."
        else
            log_privateerr "Tunnel is healthy; Gluetun is still responsible for restoring port forwarding."
        fi

    fi

}

#
# select_recovery_endpoint: Prefer unused endpoints in the current or explicitly selected region.
#
# Parameters: None. Reads the confirmed active Gluetun settings.
#
# Returns: 0 after exporting the selected endpoint; nonzero if discovery fails.
#
select_recovery_endpoint() {
    unset PRIVATEERR_CANDIDATE_IP PRIVATEERR_CANDIDATE_NAME

    #
    # Dedicated IP registration must remain in upstream setup and retain the user's token.
    #
    case "${DIP_TOKEN:-no}" in
        n*|N*|"")
            ;;
        *)
            return 0
            ;;
    esac

    local current_ip region selected

    #
    # Record the failing endpoint so selection prefers an untried server.
    #
    current_ip="$(jq -er '.provider.server_selection.wireguard.endpoint_ip' "${privateerr_runtime}/active.json")" || return 1
    printf '%s\n' "${current_ip}" >> "${privateerr_failed_ips}"

    #
    # Fetch the current catalog; its first line contains the server JSON.
    #
    curl --silent --fail --connect-timeout 5 --max-time 20 "${PRIVATEERR_SERVERLIST_URL}" \
        > "${privateerr_runtime}/catalog" || return 1
    head -n 1 "${privateerr_runtime}/catalog" > "${privateerr_runtime}/catalog.json"

    #
    # Prefer the last saved region unless the operator has pinned another one.
    #
    region="$(awk -F= '$1 == "PIA_REGION_ID" {print $2; exit}' "${PRIVATEERR_METADATA_PATH}")"
    [[ "${AUTOCONNECT:-true}" != false ]] || region="${PREFERRED_REGION}"

    #
    # Filter by region and forwarding support, then prefer unused endpoints.
    #
    selected="$(jq -er --arg current "${current_ip}" --arg region "${region}" \
        --arg auto "${AUTOCONNECT:-true}" --arg pf "${PIA_PF:-false}" \
        --rawfile failed "${privateerr_failed_ips}" '
        ($failed | split("\n")) as $excluded
        | [.regions[] | select($pf != "true" or .port_forward == true)
            | select($auto != "false" or .id == $region)
            | . as $regionData | .servers.wg[]
            | select(.ip | test("^[0-9.]+$"))
            | select(.cn | test("^[A-Za-z0-9][A-Za-z0-9.-]*$"))
            | {ip, cn, priority: (if $regionData.id == $region then 0 else 1 end)}]
        | sort_by(.priority) as $all
        | ([$all[] | select(.ip as $ip | $excluded | index($ip) | not)][0]
            // [$all[] | select(.ip == $current)][0])
        | if . == null then error("No permitted endpoint") else [.ip, .cn] | @tsv end
    ' "${privateerr_runtime}/catalog.json" 2>/dev/null)" || return 1
    IFS=$'\t' read -r PRIVATEERR_CANDIDATE_IP PRIVATEERR_CANDIDATE_NAME <<< "${selected}"
    export PRIVATEERR_CANDIDATE_IP PRIVATEERR_CANDIDATE_NAME
}

#
# recover_gluetun: Stage one replacement and submit all connection fields in one update.
#
# Parameters: None.
#
# Returns: 0 once submitted; nonzero when preparation fails. Pending state handles ambiguous responses.
#
recover_gluetun() {

    #
    # Read the actual settings before deciding whether to keep or replace a candidate.
    #
    gluetun_api GET /v1/vpn/settings "${privateerr_runtime}/active.json" || return 1

    #
    # Limit recovery updates to the custom WireGuard provider.
    #
    if ! jq -e '.type == "wireguard" and .provider.name == "custom"' \
        "${privateerr_runtime}/active.json" >/dev/null; then
        recovery_status "Recovery requires Gluetun's custom WireGuard provider; leaving its settings unchanged."
        return 1
    fi

    select_recovery_endpoint || return 1
    log_privateerr "Sustained tunnel failure; generating a fresh PIA registration."
    generate_privateerr || return 1

    #
    # A tunnel may recover or be deliberately stopped while PIA generation is in progress.
    #
    gluetun_api GET /v1/vpn/status "${privateerr_runtime}/status.json" || return 1
    [[ "$(jq -r '.status' "${privateerr_runtime}/status.json")" != stopped ]] || return 1

    #
    # Leave the running tunnel unchanged if it recovered during generation.
    #
    if gluetun_healthy; then
        log_privateerr "Gluetun recovered during generation; leaving the running tunnel unchanged."
        return 0
    fi

    #
    # Retain the full candidate before submitting it so a timeout can be reconciled.
    #
    rm -rf -- "${privateerr_pending}"
    mkdir "${privateerr_pending}" || return 1
    # shellcheck disable=SC2154 # generate_privateerr assigns privateerr_stage in the entrypoint.
    cp "${privateerr_stage}/wg0.conf" "${privateerr_stage}/privateerr.env" \
        "${privateerr_stage}/settings.json" "${privateerr_pending}/" || return 1
    touch "${privateerr_pending}/ready" || return 1

    #
    # A failed response may still mean Gluetun accepted the update; read it back next time.
    #
    gluetun_api PUT /v1/vpn/settings "${privateerr_runtime}/response" \
        "${privateerr_pending}/settings.json" || \
        log_privateerr "Settings update was not confirmed; checking Gluetun before retrying."
}

#
# monitor_gluetun: Give ordinary reconnection time, then retry with a bounded cooldown.
#
# Parameters: None.
#
# Returns: Runs until shutdown; generation/API failures do not terminate the monitor.
#
monitor_gluetun() {
    local failed_since=-1 next_attempt=0 delay="${PRIVATEERR_RECOVERY_COOLDOWN}" pending_result status

    #
    # Allow Gluetun to start before counting any failed health probes.
    #
    log_privateerr "Automatic recovery enabled; allowing ${PRIVATEERR_RECOVERY_FAILURE_SECONDS}s for startup."
    wait_privateerr "${PRIVATEERR_RECOVERY_FAILURE_SECONDS}"

    #
    # Probe Gluetun until shutdown, keeping generation failures inside the retry loop.
    #
    while true; do
        pending_result=0

        #
        # Read process state before making any recovery decision.
        #
        if gluetun_api GET /v1/vpn/status "${privateerr_runtime}/status.json"; then
            status="$(jq -r '.status // "unknown"' "${privateerr_runtime}/status.json" 2>/dev/null || true)"

            #
            # Pause for manual stops and reconcile candidates only in a stable process state.
            #
            if [[ "${status}" == stopped ]]; then
                #
                # Preserve the outage timer because internal restarts can briefly report stopped.
                #
                recovery_status "Gluetun VPN is stopped; automatic recovery is paused."
            elif [[ "${status}" == running || "${status}" == crashed ]]; then
                resolve_pending || pending_result=$?

                #
                # Wait for uncertain updates, reset healthy state, or continue counting the outage.
                #
                if [[ "${pending_result}" == 1 ]]; then
                    recovery_status "Cannot reconcile pending settings; check Gluetun API connectivity and permissions."
                elif gluetun_healthy; then
                    recovery_status "Gluetun tunnel is healthy."
                    failed_since=-1
                    delay="${PRIVATEERR_RECOVERY_COOLDOWN}"
                    : > "${privateerr_failed_ips}"
                else
                    [[ "${failed_since}" != -1 ]] || failed_since=${SECONDS}
                    recovery_status "Gluetun tunnel is unhealthy; waiting for the failure threshold before refreshing."

                    #
                    # Attempt one refresh only after both the failure threshold and cooldown have elapsed.
                    #
                    if (( SECONDS - failed_since >= PRIVATEERR_RECOVERY_FAILURE_SECONDS && SECONDS >= next_attempt )); then
                        recover_gluetun || log_privateerr "Recovery preparation failed; retained saved configuration and will retry after cooldown."

                        #
                        # Increase the retry delay, capped at one hour.
                        #
                        next_attempt=$((SECONDS + delay))
                        delay=$((delay * 2))
                        (( delay <= 3600 )) || delay=3600
                        failed_since=${SECONDS}
                    fi

                fi

            elif [[ "${status}" == starting || "${status}" == stopping ]]; then
                recovery_status "Gluetun is changing tunnel state; waiting for the transition to finish."
            else
                recovery_status "Gluetun returned an unknown VPN status; check the supported Gluetun version."
                failed_since=-1
            fi

        else
            recovery_status "Cannot access Gluetun control API; check its address, API key and route permissions."
            failed_since=-1
        fi

        wait_privateerr "${PRIVATEERR_RECOVERY_INTERVAL}"
    done

}
