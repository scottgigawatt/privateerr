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

set -euo pipefail
umask 077

: "${PIA_BIN_HOME:=/pia}"
: "${PRIVATEERR_BIN_HOME:=$(cd "$(dirname "$0")" && pwd)}"
: "${PIA_CONF_PATH:=/gluetun/wireguard/wg0.conf}"
: "${PREFERRED_REGION:=ca}"
: "${PRIVATEERR_METADATA_PATH:=/gluetun/wireguard/privateerr.env}"
: "${PRIVATEERR_HEALTHCHECK_MARKER:=/healthcheck/privateerr.ready}"
: "${PRIVATEERR_KEEPALIVE:=true}"
: "${PRIVATEERR_LOG_PATH:=/privateerr-config/logs/privateerr.log}"
: "${PRIVATEERR_AUTO_RECOVER:=false}"
: "${PRIVATEERR_GENERATION_TIMEOUT:=180}"
export PIA_BIN_HOME PREFERRED_REGION PRIVATEERR_LOG_PATH

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
    if [[ -n "${privateerr_child_pid}" ]]; then
        kill -TERM -- "-${privateerr_child_pid}" 2>/dev/null || kill "${privateerr_child_pid}" 2>/dev/null || true
        wait "${privateerr_child_pid}" 2>/dev/null || true
    fi
    [[ -z "${privateerr_stage}" ]] || rm -rf -- "${privateerr_stage}"
    rm -rf -- "${privateerr_runtime}"
}
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
    [[ -z "${privateerr_stage}" ]] || rm -rf -- "${privateerr_stage}"
    privateerr_stage="$(mktemp -d "$(dirname "${PIA_CONF_PATH}")/.privateerr-stage.XXXXXX")" || return 1
    PIA_CONF_PATH="${privateerr_stage}/wg0.conf" PRIVATEERR_METADATA_PATH="${privateerr_stage}/privateerr.env" \
        setsid timeout -s TERM -k 5 "${PRIVATEERR_GENERATION_TIMEOUT}" \
        bash "${PRIVATEERR_BIN_HOME}/privateerr-generate.sh" </dev/null &
    privateerr_child_pid=$!
    local result=0
    wait "${privateerr_child_pid}" || result=$?
    privateerr_child_pid=""
    [[ "${result}" == 0 ]] || return 1
    jq -en --rawfile config "${privateerr_stage}/wg0.conf" \
        --rawfile metadata "${privateerr_stage}/privateerr.env" \
        -f "${PRIVATEERR_BIN_HOME}/privateerr-vpn-settings.jq" > "${privateerr_stage}/settings.json"
}

#
# publish_privateerr: Replace complete files, with a replayable journal for interrupted publication.
#
# Parameters: $1 - Directory containing validated wg0.conf and privateerr.env.
#
# Returns: 0 when both files have been replaced.
#
publish_privateerr() {
    local source_dir="$1" journal
    journal="$(dirname "${PIA_CONF_PATH}")/.privateerr-commit"
    if [[ "${source_dir}" != "${journal}" ]]; then
        mkdir -p "${journal}" || return 1
        cp "${source_dir}/wg0.conf" "${journal}/wg0.conf" || return 1
        cp "${source_dir}/privateerr.env" "${journal}/privateerr.env" || return 1
        touch "${journal}/ready" || return 1
    fi
    cp "${journal}/wg0.conf" "${PIA_CONF_PATH}.new" || return 1
    mv -f "${PIA_CONF_PATH}.new" "${PIA_CONF_PATH}" || return 1
    cp "${journal}/privateerr.env" "${PRIVATEERR_METADATA_PATH}.new" || return 1
    mv -f "${PRIVATEERR_METADATA_PATH}.new" "${PRIVATEERR_METADATA_PATH}" || return 1
    rm -rf -- "${journal}"
}

# shellcheck source=docker/privateerr-recovery.sh
source "${PRIVATEERR_BIN_HOME}/privateerr-recovery.sh"

#
# main: Bootstrap configuration before starting optional monitoring or keepalive.
#
# Parameters: None.
#
# Returns: 0 for one-shot success; otherwise runs until shutdown.
#
main() {
    mkdir -p "$(dirname "${PIA_CONF_PATH}")" "$(dirname "${PRIVATEERR_METADATA_PATH}")" \
        "$(dirname "${PRIVATEERR_HEALTHCHECK_MARKER}")" "$(dirname "${PRIVATEERR_LOG_PATH}")"
    rm -f "${PRIVATEERR_HEALTHCHECK_MARKER}"
    touch "${PRIVATEERR_LOG_PATH}"

    if [[ ! "${PRIVATEERR_GENERATION_TIMEOUT}" =~ ^[1-9][0-9]{0,3}$ ]]; then
        log_privateerr "PRIVATEERR_GENERATION_TIMEOUT must be between 1 and 9999 seconds."
        exit 1
    fi
    if [[ "${PRIVATEERR_AUTO_RECOVER}" != true && "${PRIVATEERR_AUTO_RECOVER}" != false ]]; then
        log_privateerr "PRIVATEERR_AUTO_RECOVER must be true or false."
        exit 1
    fi

    if [[ "${PRIVATEERR_AUTO_RECOVER}" == true ]]; then
        configure_recovery
    fi

    # Finish a previously verified publication before allowing Gluetun to start.
    privateerr_journal="$(dirname "${PIA_CONF_PATH}")/.privateerr-commit"
    if [[ -f "${privateerr_journal}/ready" ]]; then
        publish_privateerr "${privateerr_journal}"
    else
        rm -rf -- "${privateerr_journal}"
    fi

    # Recovery restarts reuse valid persisted files; normal one-shot runs still regenerate.
    if [[ "${PRIVATEERR_AUTO_RECOVER}" == true ]] && \
        jq -en --rawfile config "${PIA_CONF_PATH}" --rawfile metadata "${PRIVATEERR_METADATA_PATH}" \
            -f "${PRIVATEERR_BIN_HOME}/privateerr-vpn-settings.jq" > "${privateerr_runtime}/persisted.json" 2>/dev/null; then
        log_privateerr "Reusing validated configuration; Gluetun health will determine whether refresh is needed."
    else
        generate_privateerr
        publish_privateerr "${privateerr_stage}"
    fi
    touch "${PRIVATEERR_HEALTHCHECK_MARKER}"
    log_privateerr "Configuration is ready for Gluetun."

    if [[ "${PRIVATEERR_AUTO_RECOVER}" == true ]]; then
        monitor_gluetun
    elif [[ "${PRIVATEERR_KEEPALIVE}" == true ]]; then
        while true; do
            wait_privateerr 86400
        done
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
