#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# check-pia-credentials.sh: Validate resolved PIA credentials without sourcing
#                           an environment file or printing secret values.
#
# Usage: docker compose config --environment | scripts/compose/check-pia-credentials.sh
#

#
# Fail on errors and unset variables.
#
set -eu

#
# Terminal presentation settings. Color is enabled only when stderr is an
# interactive terminal and the standard NO_COLOR opt-out is not set.
#
color_reset='\033[0m'
color_error='\033[1;31m'
color_warning='\033[1;33m'
color_muted='\033[0;37m'

#
# Validate that the resolved PIA credentials are not empty or still use a
# known example value.
#
pia_user=""
pia_pass=""

#
# print_error: Print the credential-check heading to stderr.
#
# Parameters: $1 - Error heading.
#
# Returns: Nothing.
#
print_error() {
    if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
        printf '\n%b%s%b\n' "${color_error}" "$1" "${color_reset}" >&2
    else
        printf '\n%s\n' "$1" >&2
    fi
}

#
# print_detail: Print an indented credential-check detail to stderr.
#
# Parameters: $1 - Detail color.
#             $2 - Detail message.
#
# Returns: Nothing.
#
print_detail() {
    if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
        printf '    %b%s%b\n' "$1" "$2" "${color_reset}" >&2
    else
        printf '    %s\n' "$2" >&2
    fi
}

#
# report_invalid_credential: Explain an invalid credential and how to fix it.
#
# Parameters: $1 - Environment variable name.
#
# Returns: Nothing.
#
report_invalid_credential() {
    print_error "☠️  This deployment cannot start without valid PIA credentials."
    printf '\n' >&2
    print_detail \
        "${color_warning}" \
        "Credential  $1"
    print_detail \
        "${color_warning}" \
        "Problem     Missing or still using a known example value."
    print_detail \
        "${color_muted}" \
        "Fix         Set $1 in the active deployment's .env file, then rerun the requested Make target."
    printf '\n' >&2
}

#
# credential_is_invalid: Identify an empty credential or known example value.
#
# Parameters: $1 - Resolved credential value.
#             $2... - One or more known example values.
#
# Returns: 0 when invalid; otherwise returns 1.
#
credential_is_invalid() {
    checked_credential=$1
    shift

    if [ -z "${checked_credential}" ]; then
        return 0
    fi

    for known_example_value in "$@"; do
        if [ "${checked_credential}" = "${known_example_value}" ]; then
            return 0
        fi
    done

    return 1
}

#
# Read only the two required values from Docker Compose's resolved environment.
# Values are retained in memory and never written to stdout or stderr.
#
while IFS= read -r environment_line; do
    case "${environment_line}" in
        PIA_USER=*)
            pia_user=${environment_line#PIA_USER=}
            ;;
        PIA_PASS=*)
            pia_pass=${environment_line#PIA_PASS=}
            ;;
    esac
done

#
# Reject missing values and known examples supplied to new operators.
#
if credential_is_invalid "${pia_user}" "p1234567"; then
    report_invalid_credential "PIA_USER"
    exit 1
fi

#
# Reject missing values and known examples supplied to new operators.
#
if credential_is_invalid "${pia_pass}" "abc123" "shiverMeTimbers123"; then
    report_invalid_credential "PIA_PASS"
    exit 1
fi
