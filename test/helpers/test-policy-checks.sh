#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test-policy-checks.sh: Exercise shared build-pin and image-tag policy checks.
#
# Usage: test/helpers/test-policy-checks.sh
#

#
# Fail on errors and unset variables.
#
set -eu

#
# Resolve the repository root and isolate every generated test artifact.
#
REPOSITORY_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
TEST_ROOT=$(mktemp -d)
FIXTURE_ROOT="${TEST_ROOT}/policy-repository"

#
# cleanup: Remove all temporary policy-test state.
#
# Parameters: None.
#
# Returns: Always returns 0 so cleanup cannot hide the original result.
#
cleanup() {
    rm -rf "${TEST_ROOT}"
}

#
# run_policy: Invoke one copied policy script inside the fixture repository.
#
# Parameters: $1 - Policy script filename under test/policy.
#
# Returns: The policy script's exit status.
#
run_policy() {
    (
        cd "${FIXTURE_ROOT}"
        sh "test/policy/$1"
    )
}

#
# write_valid_environment: Restore synchronized build dependency pins.
#
# Parameters: None.
#
# Returns: Writes the fixture example environment file and returns 0.
#
write_valid_environment() {
    cat > "${FIXTURE_ROOT}/example.env" <<'EOF'
ALPINE_TAG="${ALPINE_TAG:-3.24@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}"
TOOL_TAG="${TOOL_TAG:-v1.2.3@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb}"
EOF
}

#
# write_valid_workflow: Restore two canonical image metadata blocks and pins.
#
# Parameters: None.
#
# Returns: Writes the fixture build workflow and returns 0.
#
write_valid_workflow() {
    cat > "${FIXTURE_ROOT}/.github/workflows/build-and-push.yml" <<'EOF'
jobs:
  build:
    steps:
      - name: Build first image
        with:
          build-args: |
            ALPINE_TAG=3.24@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
            TOOL_TAG=v1.2.3@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
      - name: Chart first image
        uses: docker/metadata-action@0000000000000000000000000000000000000000
        with:
          flavor: |
            latest=auto
          tags: |
            type=edge,branch=main
            type=sha,prefix=sha-
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}
      - name: Chart second image
        uses: docker/metadata-action@0000000000000000000000000000000000000000
        with:
          flavor: |
            latest=auto
          tags: |
            type=edge,branch=main
            type=sha,prefix=sha-
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}
EOF
}

#
# Set up cleanup and create a minimal repository containing both policy scripts.
#
trap cleanup EXIT HUP INT TERM
mkdir -p \
    "${FIXTURE_ROOT}/.github/workflows" \
    "${FIXTURE_ROOT}/docker" \
    "${FIXTURE_ROOT}/test/policy"
cp "${REPOSITORY_ROOT}/test/policy/check-build-pin-policy.sh" \
    "${REPOSITORY_ROOT}/test/policy/check-image-tag-policy.sh" \
    "${FIXTURE_ROOT}/test/policy/"

cat > "${FIXTURE_ROOT}/docker/Dockerfile" <<'EOF'
ARG ALPINE_TAG=3.24@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
ARG TOOL_TAG=v1.2.3@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
EOF
write_valid_environment
write_valid_workflow

#
# Accept synchronized dependency pins and canonical tag blocks.
#
run_policy check-build-pin-policy.sh > "${TEST_ROOT}/build-valid.out"
grep -F 'Build dependency tag policy is shipshape.' \
    "${TEST_ROOT}/build-valid.out" >/dev/null
run_policy check-image-tag-policy.sh > "${TEST_ROOT}/image-valid.out"
grep -F 'Image tag policy is shipshape.' "${TEST_ROOT}/image-valid.out" >/dev/null

#
# Reject one dependency pin that drifts from the Dockerfile and workflow value.
#
cat > "${FIXTURE_ROOT}/example.env" <<'EOF'
ALPINE_TAG="${ALPINE_TAG:-3.24@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}"
TOOL_TAG="${TOOL_TAG:-v1.2.3@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc}"
EOF
if run_policy check-build-pin-policy.sh > "${TEST_ROOT}/build-mismatch.out" 2>&1; then
    echo "Build pin policy accepted mismatched dependency values." >&2
    exit 1
fi
grep -F 'Mismatched pinned TOOL_TAG values found:' \
    "${TEST_ROOT}/build-mismatch.out" >/dev/null
write_valid_environment

#
# Reject a metadata block missing the stable major alias rule.
#
awk '
    /type=semver,pattern={{major}},enable=/ {
        major_rule_count++
        if (major_rule_count == 2) {
            next
        }
    }
    { print }
' "${FIXTURE_ROOT}/.github/workflows/build-and-push.yml" \
    > "${TEST_ROOT}/missing-major.yml"
mv "${TEST_ROOT}/missing-major.yml" \
    "${FIXTURE_ROOT}/.github/workflows/build-and-push.yml"
if run_policy check-image-tag-policy.sh > "${TEST_ROOT}/image-missing.out" 2>&1; then
    echo "Image tag policy accepted a metadata block without a major alias." >&2
    exit 1
fi
grep -F 'Metadata block 2 must contain exactly one stable major alias rule; found 0.' \
    "${TEST_ROOT}/image-missing.out" >/dev/null
write_valid_workflow

#
# Reject an extra raw latest rule that could bypass stable SemVer ownership.
#
awk '
    { print }
    !inserted && /type=sha,prefix=sha-/ {
        print "            type=raw,value=latest"
        inserted = 1
    }
' "${FIXTURE_ROOT}/.github/workflows/build-and-push.yml" \
    > "${TEST_ROOT}/raw-latest.yml"
mv "${TEST_ROOT}/raw-latest.yml" \
    "${FIXTURE_ROOT}/.github/workflows/build-and-push.yml"
if run_policy check-image-tag-policy.sh > "${TEST_ROOT}/image-raw.out" 2>&1; then
    echo "Image tag policy accepted a raw latest rule." >&2
    exit 1
fi
grep -F 'Metadata block 1 contains a noncanonical latest, edge, or tag rule.' \
    "${TEST_ROOT}/image-raw.out" >/dev/null

echo "Shared policy checks passed."
