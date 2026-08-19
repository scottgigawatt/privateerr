#!/usr/bin/env bash

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# check-image-tag-policy.sh: Verify published image tags follow the release channel policy.
#
# Usage: test/policy/check-image-tag-policy.sh
#

#
# Fail on any error, unset variable, or failed pipe command.
#
set -euo pipefail

#
# Workflow path and expected rule counts for the Privateerr and Buccaneerr images.
#
workflow_path=".github/workflows/build-and-push.yml"
expected_rule_count=2

#
# count_rule: Count one metadata-action rule without coupling policy to YAML indentation.
#
# Parameters: $1 - Exact metadata-action rule without leading whitespace.
#
# Returns: Prints the number of matches.
#
count_rule() {
    local rule="$1"

    # Trim surrounding whitespace before comparing each workflow line.
    awk -v expected_rule="${rule}" '
        {
            workflow_rule = $0
            sub(/^[[:space:]]*/, "", workflow_rule)
            sub(/[[:space:]]*$/, "", workflow_rule)
            if (workflow_rule == expected_rule) {
                rule_count++
            }
        }
        END { print rule_count + 0 }
    ' "${workflow_path}"
}

#
# require_rule: Require one release rule in both image metadata blocks.
#
# Parameters: $1 - Unindented metadata-action rule.
#             $2 - Human-readable rule description.
#
# Returns: 0 when both blocks contain the rule; exits nonzero otherwise.
#
require_rule() {
    local rule="$1"
    local description="$2"
    local rule_count

    # Count the number of exact rule matches regardless of YAML indentation.
    rule_count="$(count_rule "${rule}")"
    if [[ "${rule_count}" -ne "${expected_rule_count}" ]]; then
        echo "Expected ${expected_rule_count} ${description} rules, found ${rule_count}."
        exit 1
    fi
}

#
# Require each expected rule to be present in both image metadata blocks.
#
require_rule "latest=auto" "stable latest"
require_rule "type=edge,branch=main" "main edge"
require_rule "type=sha,prefix=sha-" "commit SHA"
require_rule "type=semver,pattern={{version}}" "semantic version"

#
# The latest tag must never be assigned directly from a branch or broad tag match.
#
if grep -Eq 'type=raw,value=latest|is_default_branch' "${workflow_path}"; then
    echo "Raw latest rules are not allowed. Stable semantic versions own latest."
    exit 1
fi

echo "Image tag policy is shipshape."
