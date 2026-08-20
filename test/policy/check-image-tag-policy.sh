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
TAG_POLICY_AWK="${REPOSITORY_ROOT}/test/policy/awk/check-image-tags.awk"
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
    -v major_rule="${MAJOR_RULE}" \
    -f "${TAG_POLICY_AWK}" \
    "${WORKFLOW_PATH}"

echo "Image tag policy is shipshape."
