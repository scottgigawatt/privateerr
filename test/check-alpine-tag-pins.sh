#!/usr/bin/env bash

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# check-alpine-tag-pins.sh: Verify every pinned Alpine build arg sails in formation.
#

#
# Fail on any error, unset variable, or failed pipe command.
#
set -euo pipefail

#
# Shared Alpine build arg values must stay identical across Dockerfiles and
# workflow build args so Renovate cannot leave one hull behind.
#
alpine_tag_values="$(
    find .github/workflows docker test -type f \
        \( -name '*.yml' -o -name '*.yaml' -o -name 'Dockerfile' \) \
        -exec grep -Eh 'ALPINE_TAG[=:][[:space:]]*[^[:space:]]+@sha256:[a-f0-9]+' {} + \
        | sed -E 's/.*ALPINE_TAG[=:][[:space:]]*//g' \
        | sort -u
)"
alpine_tag_count="$(printf '%s\n' "${alpine_tag_values}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"

if [[ "${alpine_tag_count}" -eq 0 ]]; then
    echo "No pinned ALPINE_TAG values found. The cargo hold is suspiciously empty."
    exit 1
fi

if [[ "${alpine_tag_count}" -ne 1 ]]; then
    echo "Mismatched pinned ALPINE_TAG values found:"
    printf '%s\n' "${alpine_tag_values}" | sed 's/^/  /'
    exit 1
fi
