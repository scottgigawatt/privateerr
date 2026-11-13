#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# test-compose-exception-policy.sh: Reject changes that outgrow the temporary
#                                  Compose exception and its binary evidence.
#
# Usage: test/helpers/test-compose-exception-policy.sh
#

#
# Keep all rejected-input fixtures outside the checkout and operator state.
#
set -eu
REPOSITORY_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "${TEST_ROOT}"' EXIT HUP INT TERM
POLICY="${REPOSITORY_ROOT}/test/policy/check-compose-exception-policy.sh"
mkdir -p "${TEST_ROOT}/docker" "${TEST_ROOT}/test"

#
# reset_fixture: Restore the exact reviewed policy inputs in the fixture.
#
# Parameters: None.
#
# Returns: 0 after copying the public exception and donor declaration.
#
reset_fixture() {
    cp "${REPOSITORY_ROOT}/.trivyignore.yaml" "${TEST_ROOT}/.trivyignore.yaml"
    cp "${REPOSITORY_ROOT}/test/Dockerfile" "${TEST_ROOT}/test/Dockerfile"
}

#
# require_rejection: Require a boundary violation to fail closed.
#
# Parameters: $1 - Scenario name used in a failure diagnostic.
#
# Returns: 0 when rejected; otherwise exits with status 1.
#
require_rejection() {
    if sh "${POLICY}" "${TEST_ROOT}" > "${TEST_ROOT}/policy.log" 2>&1; then
        printf 'Compose exception policy accepted %s.\n' "$1" >&2
        exit 1
    fi
}

#
# A renamed checkout with the exact reviewed inputs remains valid.
#
reset_fixture
sh "${POLICY}" "${TEST_ROOT}" >/dev/null

#
# A new donor needs new package/symbol evidence rather than a stale exception.
#
sed 's/v5.7.1@sha256:/v5.7.2@sha256:/' "${TEST_ROOT}/test/Dockerfile" > "${TEST_ROOT}/changed"
mv "${TEST_ROOT}/changed" "${TEST_ROOT}/test/Dockerfile"
require_rejection 'a changed donor'
reset_fixture

#
# Do not silently expand the reviewed CVE, binary path, expiry, or entry count.
#
for replacement in 's/CVE-2026-78661/CVE-2026-97045/' 's#usr/local/lib/docker/cli-plugins/docker-compose#usr/local/bin/other-tool#' 's/expired_at: 2026-11-22/expired_at: 2026-11-23/'; do
    sed "${replacement}" "${REPOSITORY_ROOT}/.trivyignore.yaml" > "${TEST_ROOT}/.trivyignore.yaml"
    require_rejection 'an expanded identifier, path, or expiry'
done
reset_fixture
printf '%s\n' '  - id: CVE-2026-97045' >> "${TEST_ROOT}/.trivyignore.yaml"
require_rejection 'an additional advisory'
printf '%s\n' 'Compose exception rejection fixtures passed.'
