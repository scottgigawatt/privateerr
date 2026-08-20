#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# check-build-pin-policy.sh: Verify digest-pinned build tags stay synchronized.
#
# Usage: test/policy/check-build-pin-policy.sh
#

#
# Fail on errors and unset variables.
#
set -eu

#
# Resolve the repository root so the policy works from any directory.
#
REPOSITORY_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
PIN_COLLECTOR="${REPOSITORY_ROOT}/test/policy/awk/collect-build-pins.awk"
cd "${REPOSITORY_ROOT}"

#
# Discover the three repository surfaces that declare build dependency tags.
#
DOCKERFILE_PATHS=$(find docker test -type f -name Dockerfile -print 2>/dev/null | sort)
ENVIRONMENT_PATHS=$(
    find . -type f -name 'example*.env' -print \
        | awk 'index(substr($0, 3), "/") == 0' \
        | sort
)
WORKFLOW_PATHS=.github/workflows/build-and-push.yml

#
# collect_pins: Extract digest-pinned *_TAG assignments from one file surface.
#
# Parameters: $1 - Surface name recorded with each discovered pin.
#             $2 - Newline-delimited paths to scan.
#             $3 - Optional space-delimited pin names to include.
#
# Returns: Prints surface, pin name, and value records; exits nonzero for an
#          invalid assignment or an empty surface.
#
collect_pins() {
    policy_surface=$1
    policy_paths=$2
    policy_expected_pins=${3-}

    if [ -z "${policy_paths}" ]; then
        echo "No ${policy_surface} files found for build pin validation." >&2
        return 1
    fi

    while IFS= read -r policy_path; do
        [ -n "${policy_path}" ] || continue

        awk \
            -v surface="${policy_surface}" \
            -v expected_pins="${policy_expected_pins}" \
            -f "${PIN_COLLECTOR}" \
            "${policy_path}"
    done <<EOF
${policy_paths}
EOF
}

#
# Discover build pin names from Dockerfiles, then require only those names in
# the example environment and workflow. Runtime image selectors remain outside
# this build-input policy.
#
dockerfile_records=$(collect_pins dockerfile "${DOCKERFILE_PATHS}" '')
pin_names=$(printf '%s\n' "${dockerfile_records}" \
    | awk -F '|' 'NF == 3 { print $2 }' \
    | sort -u \
    | tr '\n' ' ' \
    | sed 's/[[:space:]]*$//')
environment_records=$(collect_pins environment "${ENVIRONMENT_PATHS}" "${pin_names}")
workflow_records=$(collect_pins workflow "${WORKFLOW_PATHS}" "${pin_names}")
pin_records=$(printf '%s\n%s\n%s\n' \
    "${dockerfile_records}" \
    "${environment_records}" \
    "${workflow_records}")

#
# Require at least one build dependency tag and validate every discovered name.
#
if [ -z "${pin_names}" ]; then
    echo "No digest-pinned build dependency tags were found." >&2
    exit 1
fi

for pin_name in ${pin_names}; do
    pin_values=$(printf '%s\n' "${pin_records}" \
        | awk -F '|' -v expected_pin="${pin_name}" '$2 == expected_pin { print $3 }' \
        | sort -u)
    pin_value_count=$(printf '%s\n' "${pin_values}" | sed '/^$/d' | wc -l | tr -d '[:space:]')

    if [ "${pin_value_count}" -ne 1 ]; then
        echo "Mismatched pinned ${pin_name} values found:" >&2
        printf '%s\n' "${pin_values}" | sed 's/^/  /' >&2
        exit 1
    fi

    for policy_surface in dockerfile environment workflow; do
        surface_count=$(printf '%s\n' "${pin_records}" \
            | awk -F '|' \
                -v expected_pin="${pin_name}" \
                -v expected_surface="${policy_surface}" \
                '$1 == expected_surface && $2 == expected_pin { count++ } END { print count + 0 }')

        if [ "${surface_count}" -eq 0 ]; then
            echo "Missing ${pin_name} pin from ${policy_surface} files." >&2
            exit 1
        fi
    done
done

echo "Build dependency tag policy is shipshape."
