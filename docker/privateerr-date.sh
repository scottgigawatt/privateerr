#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# privateerr-date.sh: This script provides the small GNU date compatibility
#                     surface needed by the upstream PIA scripts on Alpine.
#
# The script:
#   - Accepts GNU-style '--date=VALUE' and '--date VALUE' arguments.
#   - Supports the PIA token expiration value '1 day'.
#   - Converts common ISO timestamps into a BusyBox date-compatible format.
#   - Delegates every other argument to BusyBox date.
#

set -eu

date_value=""
date_args=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --date=*)
            date_value="${1#--date=}"
            shift
            ;;
        --date)
            shift
            date_value="${1:-}"
            shift
            ;;
        *)
            date_args="${date_args} $(printf '%s\n' "$1" | sed "s/'/'\\\\''/g; s/.*/'&'/")"
            shift
            ;;
    esac
done

if [ -z "${date_value}" ]; then
    # shellcheck disable=SC2086
    eval "exec /bin/date ${date_args}"
fi

case "${date_value}" in
    "1 day")
        date_value="@$(($(/bin/date +%s) + 86400))"
        ;;
    *T*Z)
        date_value="$(printf '%s\n' "${date_value}" | sed 's/T/ /; s/Z$//')"
        ;;
esac

# shellcheck disable=SC2086
eval "exec /bin/date -d '$(printf '%s\n' "${date_value}" | sed "s/'/'\\\\''/g")' ${date_args}"
