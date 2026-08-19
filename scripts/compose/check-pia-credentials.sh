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

set -eu

#
# Terminal presentation settings. Color is enabled only when stderr is an
# interactive terminal and the standard NO_COLOR opt-out is not set.
#
color_reset='\033[0m'
color_error='\033[1;31m'
color_warning='\033[1;33m'
color_muted='\033[0;37m'
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
    print_error "☠️  Privateerr cannot sail without valid PIA credentials."
    printf '\n' >&2
    print_detail "${color_warning}" "Credential  $1"
    print_detail \
        "${color_warning}" \
        "Problem     Missing or still using the documented example value."
    print_detail \
        "${color_muted}" \
        "Fix         Set $1 in .env, then rerun the requested Make target."
    printf '\n' >&2
}

#
# credential_is_invalid: Identify an empty or documented example credential.
#
# Parameters: $1 - Resolved credential value.
#             $2 - Documented example value.
#
# Returns: 0 when invalid; otherwise returns 1.
#
credential_is_invalid() {
    [ -z "$1" ] || [ "$1" = "$2" ]
}

#
# Read only the required values from Compose's resolved environment. Values
# remain in memory and are never written to standard output or standard error.
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
# Reject missing values and the examples supplied to new operators.
#
if credential_is_invalid "${pia_user}" "p1234567"; then
    report_invalid_credential "PIA_USER"
    exit 1
fi

if credential_is_invalid "${pia_pass}" "shiverMeTimbers123"; then
    report_invalid_credential "PIA_PASS"
    exit 1
fi
