#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# test-notification-tags.sh: Validate notification tag boundaries and the actual
#                            workflow output step without registry operations.
#
# Usage: test/helpers/test-notification-tags.sh
#

#
# Isolate all synthetic inputs and generated workflow outputs from deployments.
#
set -eu
REPOSITORY_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "${TEST_ROOT}"' EXIT HUP INT TERM
HELPER="${REPOSITORY_ROOT}/.github/scripts/notification-tags.sh"
image_keys='privateerr buccaneerr'

#
# normalize: Run the tag validator with one expected public image reference.
#
# Parameters: $1 - Newline-separated full references or short tags.
#
# Returns: Prints the complete validated short list or fails without partial output.
#
normalize() {
    sh "${HELPER}" --image ghcr.io/owner-canary/image --tags "$1"
}

#
# Preserve order, case, punctuation, and already-short tags, including boundaries.
#
actual=$(normalize 'ghcr.io/owner-canary/image:edge
Version_1.2-RC
_sha-ABC123
0')
expected=$(printf '%s\n' edge Version_1.2-RC _sha-ABC123 0)
test "${actual}" = "${expected}"
test -z "$(normalize '')"
test -z "$(normalize '
')"
tag128=$(awk 'BEGIN { for (i = 0; i < 128; i++) printf "A" }')
test "$(normalize "${tag128}")" = "${tag128}"
test "$(sh "${HELPER}" --image registry.example:5000/team/image --tags registry.example:5000/team/image:edge)" = edge

#
# An invalid later line must reject the whole list without leaking its contents.
#
for invalid in ghcr.io/other/image:edge ghcr.io/owner-canary/other:edge \
    canary-invalid:edge edge@sha256:abc 'two words' ' edge' edge/other .edge -edge \
    "${tag128}A" "$(printf 'edge\r')" ':notification-tags:'; do
    if normalize "$(printf 'valid-first\n%s' "${invalid}")" \
        > "${TEST_ROOT}/invalid.out" 2> "${TEST_ROOT}/invalid.err"; then
        echo 'Notification tag validator accepted malformed or mismatched metadata.' >&2
        exit 1
    fi

    test ! -s "${TEST_ROOT}/invalid.out"
    test "$(cat "${TEST_ROOT}/invalid.err")" = 'Notification tags must be short Docker tags or references to the expected image.'
done

#
# Exercise the actual workflow producer before GitHub's cross-job output boundary.
# The owner canary models the reported collision without accessing real secrets.
#
workflow="${REPOSITORY_ROOT}/.github/workflows/build-and-push.yml"
awk '
    $0 == "        id: notification-tags" { selected = 1 }
    selected && $0 == "        run: |" { body = 1; next }
    body && /^          / { print substr($0, 11); next }
    body && /^[[:space:]]*$/ { print ""; next }
    body { exit }
' "${workflow}" > "${TEST_ROOT}/producer.sh"
test -s "${TEST_ROOT}/producer.sh"
(
    cd "${REPOSITORY_ROOT}"
    PRIVATEERR_IMAGE_REF=ghcr.io/owner-canary/privateerr \
    BUCCANEERR_IMAGE_REF=ghcr.io/owner-canary/buccaneerr \
    PRIVATEERR_TAGS="$(printf '%s\n' ghcr.io/owner-canary/privateerr:edge Version_1.2-RC)" \
    BUCCANEERR_TAGS="$(printf '%s\n' ghcr.io/owner-canary/buccaneerr:edge Version_1.2-RC)" \
    GITHUB_OUTPUT="${TEST_ROOT}/github-output" sh -eu "${TEST_ROOT}/producer.sh"
)

if grep -E 'owner-canary|ghcr[.]io' "${TEST_ROOT}/github-output" >/dev/null; then
    echo 'Notification outputs retained an unnecessary image prefix.' >&2
    exit 1
fi

for image in ${image_keys}; do
    grep -F "${image}-tags: \${{ steps.notification-tags.outputs.${image}-tags }}" "${workflow}" >/dev/null
    actual=$(awk -v key="${image}-tags<<:notification-tags:" '
        $0 == key { selected = 1; next }
        selected && $0 == ":notification-tags:" { exit }
        selected { print }
    ' "${TEST_ROOT}/github-output")
    test "${actual}" = "$(printf '%s\n' edge Version_1.2-RC)"
done
printf '%s\n' 'Notification tag tests passed.'
