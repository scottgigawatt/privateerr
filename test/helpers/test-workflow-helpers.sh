#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test-workflow-helpers.sh: Validate release policy, Discord payload generation,
#                           and registry mirroring without external writes.
#
# Usage: test/helpers/test-workflow-helpers.sh
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
SKOPEO_LOG="${TEST_ROOT}/skopeo.log"
RELEASE_REPOSITORY="${TEST_ROOT}/release-repository"

#
# cleanup: Remove all temporary helper-test state.
#
# Parameters: None.
#
# Returns: Always returns 0 so cleanup cannot hide the original result.
#
cleanup() {
    rm -rf "${TEST_ROOT}"
}

#
# Set up cleanup on exit, hangup, interrupt, or termination.
#
trap cleanup EXIT HUP INT TERM

#
# assert_json_value: Require a JSON expression to evaluate successfully.
#
# Parameters: $1 - JSON document path.
#             $2 - jq assertion expression.
#
# Returns: 0 when the expression succeeds; otherwise returns nonzero.
#
assert_json_value() {
    jq -e "$2" "$1" >/dev/null
}

#
# run_release_helper: Invoke the release helper inside the isolated repository.
#
# Parameters: $@ - Release-helper flags.
#
# Returns: The release helper's exit status.
#
run_release_helper() {
    (
        cd "${RELEASE_REPOSITORY}"
        sh "${REPOSITORY_ROOT}/.github/scripts/validate-release-tag.sh" "$@"
    )
}

#
# Build a local release repository with an annotated semantic-version tag on
# main. Its bare origin exercises the helper's real fetch and ancestry checks.
#
git init --quiet --bare "${TEST_ROOT}/origin.git"
git init --quiet --initial-branch=main "${RELEASE_REPOSITORY}"
git -C "${RELEASE_REPOSITORY}" config user.email test@example.invalid
git -C "${RELEASE_REPOSITORY}" config user.name "Privateerr Tests"
printf '%s\n' 'release fixture' > "${RELEASE_REPOSITORY}/release.txt"
git -C "${RELEASE_REPOSITORY}" add release.txt
git -C "${RELEASE_REPOSITORY}" commit --quiet -m "Add release fixture"
main_sha=$(git -C "${RELEASE_REPOSITORY}" rev-parse HEAD)
git -C "${RELEASE_REPOSITORY}" tag --annotate v1.2.3 \
    --message "Test release"
git -C "${RELEASE_REPOSITORY}" remote add origin "${TEST_ROOT}/origin.git"
git -C "${RELEASE_REPOSITORY}" push --quiet origin main refs/tags/v1.2.3

#
# Accept an annotated semantic-version tag whose commit belongs to main.
#
run_release_helper \
    --release-tag v1.2.3 \
    --release-sha "${main_sha}" \
    > "${TEST_ROOT}/release-valid.out"
grep -F 'Release tag v1.2.3 is annotated and points to a commit on main.' \
    "${TEST_ROOT}/release-valid.out" >/dev/null

#
# Accept SemVer prerelease identifiers and build metadata without weakening the
# leading-zero rules enforced for the core version.
#
git -C "${RELEASE_REPOSITORY}" tag --annotate v1.2.3-rc.1+build.7 \
    --message "Test prerelease"
run_release_helper \
    --release-tag v1.2.3-rc.1+build.7 \
    --release-sha "${main_sha}" \
    > "${TEST_ROOT}/release-prerelease.out"
grep -F 'Release tag v1.2.3-rc.1+build.7 is annotated and points to a commit on main.' \
    "${TEST_ROOT}/release-prerelease.out" >/dev/null

#
# Reject malformed semantic versions before consulting repository state.
#
if run_release_helper \
    --release-tag v01.2.3 \
    --release-sha "${main_sha}" \
    > "${TEST_ROOT}/release-semver.out" 2>&1; then
    echo "Release helper accepted an invalid semantic version." >&2
    exit 1
fi
grep -F 'Release tag v01.2.3 is not valid semantic versioning.' \
    "${TEST_ROOT}/release-semver.out" >/dev/null

#
# Reject lightweight tags even when their commit belongs to main.
#
git -C "${RELEASE_REPOSITORY}" tag v1.2.4
if run_release_helper \
    --release-tag v1.2.4 \
    --release-sha "${main_sha}" \
    > "${TEST_ROOT}/release-annotated.out" 2>&1; then
    echo "Release helper accepted a lightweight tag." >&2
    exit 1
fi
grep -F 'Release tag v1.2.4 must be annotated.' \
    "${TEST_ROOT}/release-annotated.out" >/dev/null

#
# Reject an annotated release whose commit has not reached main.
#
git -C "${RELEASE_REPOSITORY}" switch --quiet --create release-only
printf '%s\n' 'release-only commit' >> "${RELEASE_REPOSITORY}/release.txt"
git -C "${RELEASE_REPOSITORY}" commit --quiet --all \
    --message "Add release-only fixture"
release_only_sha=$(git -C "${RELEASE_REPOSITORY}" rev-parse HEAD)
git -C "${RELEASE_REPOSITORY}" tag --annotate v1.2.5 \
    --message "Invalid test release"
if run_release_helper \
    --release-tag v1.2.5 \
    --release-sha "${release_only_sha}" \
    > "${TEST_ROOT}/release-ancestry.out" 2>&1; then
    echo "Release helper accepted a commit outside main." >&2
    exit 1
fi
grep -F 'Release tag v1.2.5 does not point to a commit on main.' \
    "${TEST_ROOT}/release-ancestry.out" >/dev/null

#
# Render deterministic start and verdict payloads through long and short flags.
#
sh "${REPOSITORY_ROOT}/.github/scripts/notify-discord.sh" \
    --event start \
    --template deck \
    --run-url https://example.invalid/run \
    --repository test/privateerr \
    --ref-name test-ref \
    --workflow-name test-build \
    --actor test-captain \
    --platforms linux/amd64 \
    --ghcr-image ghcr.io/test/privateerr \
    --dockerhub-image docker.io/test/privateerr \
    --random-value 2 \
    --dry-run \
    > "${TEST_ROOT}/build-start.json"

assert_json_value "${TEST_ROOT}/build-start.json" \
    '.username == "Privateerr Deck Crew" and .embeds[0].color == 3447003'

sh "${REPOSITORY_ROOT}/.github/scripts/notify-discord.sh" \
    -e verdict \
    -t hades \
    -u https://example.invalid/run \
    -r test/privateerr \
    -f test-ref \
    -s failure \
    -g ghcr.io/test/privateerr \
    -c https://example.invalid/ghcr \
    -b https://example.invalid/dockerhub \
    -l ghcr.io/test/privateerr:test \
    -i sha256:0123456789abcdef \
    -n 3 \
    -x \
    > "${TEST_ROOT}/build-verdict.json"

assert_json_value "${TEST_ROOT}/build-verdict.json" \
    '.username == "Hades Build Bureau" and .embeds[0].color == 15158332'

#
# Replace Skopeo with a deterministic recorder for copy and digest operations.
#
mkdir -p "${TEST_ROOT}/bin"
sed "s|@SKOPEO_LOG@|${SKOPEO_LOG}|g" \
    "${REPOSITORY_ROOT}/test/stubs/workflow-skopeo-stub.sh" \
    > "${TEST_ROOT}/bin/skopeo"
chmod +x "${TEST_ROOT}/bin/skopeo"

#
# run_registry_helper: Invoke the registry helper with safe test credentials.
#
# Parameters: $@ - Registry-helper flags.
#
# Returns: The registry helper's exit status.
#
run_registry_helper() {
    GHCR_TOKEN=test-token \
    DOCKERHUB_TOKEN=test-token \
        sh "${REPOSITORY_ROOT}/.github/scripts/registry-mirror.sh" \
        --ghcr-image ghcr.io/test/privateerr \
        --dockerhub-image docker.io/test/privateerr \
        --ghcr-username test-user \
        --dockerhub-username test-user \
        --published-tags "ghcr.io/test/privateerr:edge
ghcr.io/test/privateerr:sha-test" \
        --skopeo-bin "${TEST_ROOT}/bin/skopeo" \
        "$@"
}

#
# Run the registry helper to mirror and verify the test Privateerr image without
# writing to any registry.
#
run_registry_helper --mirror
run_registry_helper -v

#
# Validate that the Skopeo recorder logged the expected copy and digest operations.
#
grep -F -- 'copy --all --preserve-digests' "${SKOPEO_LOG}" >/dev/null
grep -F -- 'docker://docker.io/test/privateerr:sha-test' "${SKOPEO_LOG}" >/dev/null
grep -F -- 'inspect --creds test-user:test-token --format {{.Digest}} docker://ghcr.io/test/privateerr:edge' "${SKOPEO_LOG}" >/dev/null
grep -F -- 'inspect --creds test-user:test-token --format {{.Digest}} docker://docker.io/test/privateerr:edge' "${SKOPEO_LOG}" >/dev/null
grep -F -- 'inspect --creds test-user:test-token --format {{.Digest}} docker://ghcr.io/test/privateerr:sha-test' "${SKOPEO_LOG}" >/dev/null
grep -F -- 'inspect --creds test-user:test-token --format {{.Digest}} docker://docker.io/test/privateerr:sha-test' "${SKOPEO_LOG}" >/dev/null

echo "Workflow helper tests passed."
