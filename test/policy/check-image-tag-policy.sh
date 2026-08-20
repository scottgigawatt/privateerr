#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# check-image-tag-policy.sh: Verify published image tags follow one channel policy.
#
# Usage: test/policy/check-image-tag-policy.sh
#

#
# Fail on errors and unset variables.
#
set -eu

#
# Resolve the workflow and define the canonical shared metadata-action rules.
#
REPOSITORY_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
WORKFLOW_PATH="${REPOSITORY_ROOT}/.github/workflows/build-and-push.yml"
LATEST_RULE='latest=auto'
EDGE_RULE='type=edge,branch=main'
SHA_RULE='type=sha,prefix=sha-'
VERSION_RULE='type=semver,pattern={{version}}'
MINOR_RULE='type=semver,pattern={{major}}.{{minor}}'
MAJOR_RULE="type=semver,pattern={{major}},enable=\${{ !startsWith(github.ref, 'refs/tags/v0.') }}"

#
# Validate every metadata-action block independently. Stable releases publish
# exact, minor, major, and latest aliases; prereleases retain only their exact
# version; main publishes edge; and every build publishes a commit SHA tag.
#
awk \
    -v latest_rule="${LATEST_RULE}" \
    -v edge_rule="${EDGE_RULE}" \
    -v sha_rule="${SHA_RULE}" \
    -v version_rule="${VERSION_RULE}" \
    -v minor_rule="${MINOR_RULE}" \
    -v major_rule="${MAJOR_RULE}" '
    function reset_block() {
        latest_count = 0
        edge_count = 0
        sha_count = 0
        version_count = 0
        minor_count = 0
        major_count = 0
        type_count = 0
        unsafe_count = 0
    }

    function require_single_rule(rule_count, description) {
        if (rule_count != 1) {
            printf "Metadata block %d must contain exactly one %s rule; found %d.\n", \
                block_count, description, rule_count > "/dev/stderr"
            failed = 1
        }
    }

    function validate_block() {
        require_single_rule(latest_count, "stable latest")
        require_single_rule(edge_count, "main edge")
        require_single_rule(sha_count, "commit SHA")
        require_single_rule(version_count, "exact semantic version")
        require_single_rule(minor_count, "stable minor alias")
        require_single_rule(major_count, "stable major alias")

        if (type_count != 5) {
            printf "Metadata block %d contains %d tag rules; expected 5 canonical rules.\n", \
                block_count, type_count > "/dev/stderr"
            failed = 1
        }
        if (unsafe_count != 0) {
            printf "Metadata block %d contains a noncanonical latest, edge, or tag rule.\n", \
                block_count > "/dev/stderr"
            failed = 1
        }
    }

    {
        workflow_rule = $0
        sub(/^[[:space:]]*/, "", workflow_rule)
        sub(/[[:space:]]*$/, "", workflow_rule)

        if (workflow_rule ~ /^uses: docker\/metadata-action@/) {
            if (in_metadata_block) {
                validate_block()
            }
            block_count++
            in_metadata_block = 1
            reset_block()
            next
        }

        if (in_metadata_block && workflow_rule ~ /^- (name|uses|run):/) {
            validate_block()
            in_metadata_block = 0
        }
        if (!in_metadata_block) {
            next
        }

        if (workflow_rule == latest_rule) {
            latest_count++
        } else if (workflow_rule ~ /^latest=/) {
            unsafe_count++
        }

        if (workflow_rule ~ /^type=/) {
            type_count++
            if (workflow_rule == edge_rule) {
                edge_count++
            } else if (workflow_rule == sha_rule) {
                sha_count++
            } else if (workflow_rule == version_rule) {
                version_count++
            } else if (workflow_rule == minor_rule) {
                minor_count++
            } else if (workflow_rule == major_rule) {
                major_count++
            } else {
                unsafe_count++
            }
        }

        if (workflow_rule ~ /is_default_branch/) {
            unsafe_count++
        }
    }

    END {
        if (in_metadata_block) {
            validate_block()
        }
        if (block_count == 0) {
            print "No docker/metadata-action blocks found." > "/dev/stderr"
            failed = 1
        }
        if (failed) {
            exit 1
        }
    }
' "${WORKFLOW_PATH}"

echo "Image tag policy is shipshape."
