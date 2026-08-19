#!/usr/bin/env bash

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# check-alpine-tag-pins.sh: Verify every pinned Alpine build arg sails in formation.
#
# Usage: test/policy/check-alpine-tag-pins.sh
#

#
# Fail on any error, unset variable, or failed pipe command.
#
set -euo pipefail

#
# Shared Alpine build arg values must stay identical across Dockerfiles,
# workflow build args, and example env defaults so Renovate cannot leave one
# hull behind.
#
alpine_tag_values="$(
    find .github/workflows docker test . -type f \
        \( -name '*.yml' -o -name '*.yaml' -o -name 'Dockerfile' -o -name 'example.env' \) \
        -exec grep -Eh 'ALPINE_TAG[=:][[:space:]]*[^[:space:]]+@sha256:[a-f0-9]+' {} + \
        | sed -E 's/.*ALPINE_TAG[=:][[:space:]]*"?(\$\{ALPINE_TAG:-)?//g; s/\}"?$//g' \
        | sort -u
)"

#
# Count the number of unique pinned ALPINE_TAG values found.
#
alpine_tag_count="$(printf '%s\n' "${alpine_tag_values}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"

#
# Fail if no pinned ALPINE_TAG values were found.
#
if [[ "${alpine_tag_count}" -eq 0 ]]; then
    echo "No pinned ALPINE_TAG values found. The cargo hold is suspiciously empty."
    exit 1
fi

#
# Verify all pinned ALPINE_TAG values are identical.
#
if [[ "${alpine_tag_count}" -ne 1 ]]; then
    echo "Mismatched pinned ALPINE_TAG values found:"
    printf '%s\n' "${alpine_tag_values}" | sed 's/^/  /'
    exit 1
fi
