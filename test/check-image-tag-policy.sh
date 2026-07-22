#!/usr/bin/env bash

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# check-image-tag-policy.sh: Verify published image tags follow the release channel policy.
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
# Count exact metadata-action rules without treating punctuation as expressions.
#
count_rule() {
    local rule="$1"

    grep -Fxc "${rule}" "${workflow_path}" || true
}

#
# Require the same release channel rule in both image metadata blocks.
#
require_rule() {
    local rule="$1"
    local description="$2"
    local rule_count

    rule_count="$(count_rule "                      ${rule}")"
    if [[ "${rule_count}" -ne "${expected_rule_count}" ]]; then
        echo "Expected ${expected_rule_count} ${description} rules, found ${rule_count}."
        exit 1
    fi
}

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
