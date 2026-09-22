#!/usr/bin/env bash

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# privateerr-entrypoint.sh: Generate PIA configuration and optionally recover Gluetun.
#
# Usage: docker/privateerr-entrypoint.sh
#
# The script:
#   - Runs unmodified upstream PIA scripts with a generation deadline.
#   - Validates WireGuard configuration and matching Gluetun metadata before saving them.
#   - Keeps temporary copies so an interrupted save can finish on the next start.
#   - Reports configuration readiness independently of tunnel health.
#   - Optionally monitors Gluetun and refreshes settings after sustained tunnel failure.
#   - Otherwise exits after generation or stays alive, according to PRIVATEERR_KEEPALIVE.
#

#
# Fail on command errors, unset variables, and failures within pipelines.
#
set -euo pipefail

#
# Restrict newly created secret files and directories to their owner.
#
umask 077

#
# Supply defaults for deployments that omit optional environment settings.
#
: "${PIA_BIN_HOME:=/pia}"
: "${PRIVATEERR_BIN_HOME:=$(cd "$(dirname "$0")" && pwd)}"
: "${PIA_CONF_PATH:=/gluetun/wireguard/wg0.conf}"
: "${PREFERRED_REGION:=ca}"
: "${PRIVATEERR_METADATA_PATH:=/gluetun/wireguard/privateerr.env}"
: "${PRIVATEERR_HEALTHCHECK_MARKER:=/healthcheck/privateerr.ready}"
: "${PRIVATEERR_KEEPALIVE:=true}"
: "${PRIVATEERR_LOG_PATH:=/privateerr-config/logs/privateerr.log}"
: "${PRIVATEERR_AUTO_RECOVER:=false}"
: "${PRIVATEERR_GENERATION_TIMEOUT_SECONDS:=180}"
export PIA_BIN_HOME PREFERRED_REGION PRIVATEERR_LOG_PATH

#
# Track the active child and temporary files for shutdown cleanup.
#
privateerr_child_pid=""
privateerr_stage=""
privateerr_runtime="$(mktemp -d /tmp/privateerr.XXXXXX)"

#
# log_privateerr: Write a timestamped diagnostic without configuration or credentials.
#
# Parameters: $* - Public diagnostic message.
#
# Returns: tee's exit status.
#
log_privateerr() {
    printf '[privateerr-entrypoint.sh] %s %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a "${PRIVATEERR_LOG_PATH}"
}

#
# cleanup_privateerr: Stop the active child group and remove temporary secret files.
#
# Parameters: None.
#
# Returns: 0.
#
cleanup_privateerr() {

    #
    # Stop an active generation or sleep before removing temporary files.
    #
    if [[ -n "${privateerr_child_pid}" ]]; then
        kill -TERM -- "-${privateerr_child_pid}" 2>/dev/null || kill "${privateerr_child_pid}" 2>/dev/null || true
        wait "${privateerr_child_pid}" 2>/dev/null || true
    fi

    #
    # Remove only the temporary generation directory owned by this process.
    #
    [[ -z "${privateerr_stage}" ]] || rm -rf -- "${privateerr_stage}"
    rm -rf -- "${privateerr_runtime}"
}

#
# Clean up temporary secrets on exit and handle container shutdown signals.
#
trap cleanup_privateerr EXIT
trap 'exit 0' TERM INT

#
# wait_privateerr: Sleep in an interruptible child so PID 1 handles Docker stop promptly.
#
# Parameters: $1 - Number of seconds to wait.
#
# Returns: 0 after the wait.
#
wait_privateerr() {

    #
    # A background sleep lets Bash handle termination while it waits.
    #
    sleep "$1" &
    privateerr_child_pid=$!
    wait "${privateerr_child_pid}" || true
    privateerr_child_pid=""
}

#
# generate_privateerr: Run upstream generation into fresh files with a wall-clock deadline.
#
# Parameters: None. Candidate endpoint variables optionally select an upstream registration.
#
# Returns: 0 for a validated pair; nonzero without modifying the active configuration.
#
generate_privateerr() {

    #
    # Remove only the temporary generation directory owned by this process.
    #
    [[ -z "${privateerr_stage}" ]] || rm -rf -- "${privateerr_stage}"
    privateerr_stage="$(mktemp -d "$(dirname "${PIA_CONF_PATH}")/.privateerr-stage.XXXXXX")" || return 1

    #
    # Isolate upstream processes so a timeout or shutdown stops the whole generation.
    #
    PIA_CONF_PATH="${privateerr_stage}/wg0.conf" PRIVATEERR_METADATA_PATH="${privateerr_stage}/privateerr.env" \
        setsid timeout -s TERM -k 5 "${PRIVATEERR_GENERATION_TIMEOUT_SECONDS}" \
        bash "${PRIVATEERR_BIN_HOME}/privateerr-generate.sh" </dev/null &
    privateerr_child_pid=$!
    local result=0
    wait "${privateerr_child_pid}" || result=$?
    privateerr_child_pid=""
    [[ "${result}" == 0 ]] || return 1

    #
    # Reject incomplete or mismatched files before they can replace saved settings.
    #
    jq -en --rawfile config "${privateerr_stage}/wg0.conf" \
        --rawfile metadata "${privateerr_stage}/privateerr.env" \
        -f "${PRIVATEERR_BIN_HOME}/privateerr-vpn-settings.jq" > "${privateerr_stage}/settings.json"
}

#
# publish_privateerr: Save both files while retaining copies until both replacements finish.
#
# Parameters: $1 - Directory containing validated wg0.conf and privateerr.env.
#
# Returns: 0 when both files have been replaced; nonzero leaves copies for startup to retry.
#
publish_privateerr() {
    local source_dir="$1" journal
    journal="$(dirname "${PIA_CONF_PATH}")/.privateerr-commit"

    #
    # Keep complete source copies and mark them ready before replacing either destination.
    #
    if [[ "${source_dir}" != "${journal}" ]]; then
        mkdir -p "${journal}" || return 1
        cp "${source_dir}/wg0.conf" "${journal}/wg0.conf" || return 1
        cp "${source_dir}/privateerr.env" "${journal}/privateerr.env" || return 1
        touch "${journal}/ready" || return 1
    fi

    #
    # Rename each complete file into place; retain both source copies until the pair is saved.
    #
    cp "${journal}/wg0.conf" "${PIA_CONF_PATH}.new" || return 1
    mv -f "${PIA_CONF_PATH}.new" "${PIA_CONF_PATH}" || return 1
    cp "${journal}/privateerr.env" "${PRIVATEERR_METADATA_PATH}.new" || return 1
    mv -f "${PRIVATEERR_METADATA_PATH}.new" "${PRIVATEERR_METADATA_PATH}" || return 1
    rm -rf -- "${journal}"
}

#
# Load recovery functions without starting the monitor.
#
# shellcheck source=privateerr-recovery.sh
source "${PRIVATEERR_BIN_HOME}/privateerr-recovery.sh"

#
# main: Bootstrap configuration before starting optional monitoring or keepalive.
#
# Parameters: None.
#
# Returns: 0 for one-shot success; otherwise runs until shutdown.
#
main() {

    #
    # Prepare output paths and clear readiness left over from an earlier process.
    #
    mkdir -p "$(dirname "${PIA_CONF_PATH}")" "$(dirname "${PRIVATEERR_METADATA_PATH}")" \
        "$(dirname "${PRIVATEERR_HEALTHCHECK_MARKER}")" "$(dirname "${PRIVATEERR_LOG_PATH}")"
    rm -f "${PRIVATEERR_HEALTHCHECK_MARKER}"
    touch "${PRIVATEERR_LOG_PATH}"

    #
    # Reject invalid generation deadlines before invoking the timeout command.
    #
    if [[ ! "${PRIVATEERR_GENERATION_TIMEOUT_SECONDS}" =~ ^[1-9][0-9]{0,3}$ ]]; then
        log_privateerr "PRIVATEERR_GENERATION_TIMEOUT_SECONDS must be between 1 and 9999 seconds."
        exit 1
    fi

    #
    # Require an explicit boolean value for the recovery switch.
    #
    if [[ "${PRIVATEERR_AUTO_RECOVER}" != true && "${PRIVATEERR_AUTO_RECOVER}" != false ]]; then
        log_privateerr "PRIVATEERR_AUTO_RECOVER must be true or false."
        exit 1
    fi

    #
    # Enable recovery only when explicitly requested.
    #
    if [[ "${PRIVATEERR_AUTO_RECOVER}" == true ]]; then
        configure_recovery
    fi

    #
    # Locate copies retained when the previous process stopped partway through saving.
    #
    privateerr_journal="$(dirname "${PIA_CONF_PATH}")/.privateerr-commit"

    #
    # Finish an interrupted save only when both retained source files were marked ready.
    #
    if [[ -f "${privateerr_journal}/ready" ]]; then
        publish_privateerr "${privateerr_journal}"
    else
        rm -rf -- "${privateerr_journal}"
    fi

    #
    # Recovery restarts reuse valid persisted files; normal one-shot runs still regenerate.
    #
    if [[ "${PRIVATEERR_AUTO_RECOVER}" == true ]] && \
        jq -en --rawfile config "${PIA_CONF_PATH}" --rawfile metadata "${PRIVATEERR_METADATA_PATH}" \
            -f "${PRIVATEERR_BIN_HOME}/privateerr-vpn-settings.jq" > "${privateerr_runtime}/persisted.json" 2>/dev/null; then
        log_privateerr "Reusing validated configuration; Gluetun health will determine whether refresh is needed."
    else
        generate_privateerr
        publish_privateerr "${privateerr_stage}"
    fi

    #
    # Report readiness only after a complete configuration pair is available.
    #
    touch "${PRIVATEERR_HEALTHCHECK_MARKER}"
    log_privateerr "Configuration is ready for Gluetun."

    #
    # Enable recovery only when explicitly requested.
    #
    if [[ "${PRIVATEERR_AUTO_RECOVER}" == true ]]; then
        monitor_gluetun
    elif [[ "${PRIVATEERR_KEEPALIVE}" == true ]]; then

        #
        # Keep the process alive until shutdown while performing the configured wait or probe.
        #
        while true; do
            wait_privateerr 86400
        done

    fi

}

#
# Run startup only when executed directly; tests may source the functions.
#
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
