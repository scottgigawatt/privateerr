#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test-workflow-helpers.sh: Validate Discord payload generation and registry
#                           mirroring without messages or registry writes.
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
