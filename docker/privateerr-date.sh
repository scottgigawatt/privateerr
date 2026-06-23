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

#
# Set strict error handling to exit on errors and treat unset variables as errors.
#
set -eu

#
# Initialize variables to hold the date value and additional arguments.
#
date_value=""
date_args=""

#
# Parse command-line arguments to extract the date value and any additional arguments.
#
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

#
# If no date value is provided, delegate to BusyBox date with the accumulated arguments.
#
if [ -z "${date_value}" ]; then
    # shellcheck disable=SC2086
    eval "exec /bin/date ${date_args}"
fi

#
# Handle specific date formats and convert them to a format compatible with BusyBox date.
#
case "${date_value}" in
    "1 day")
        date_value="@$(($(/bin/date +%s) + 86400))"
        ;;
    *T*Z)
        date_value="$(printf '%s\n' "${date_value}" | sed 's/T/ /; s/Z$//')"
        ;;
esac

#
# Finally, execute BusyBox date with the processed date value and any additional arguments.
#
# shellcheck disable=SC2086
eval "exec /bin/date -d '$(printf '%s\n' "${date_value}" | sed "s/'/'\\\\''/g")' ${date_args}"
