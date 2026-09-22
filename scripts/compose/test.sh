#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test.sh: Build Buccaneerr and run checks without installing tools on the host.
#
# Usage: scripts/compose/test.sh [all|python|helpers|workflows|lint|format|runtime|live|smoke|precommit|spellcheck]
#
# Offline suites mount source read-only without networking or Docker access.
# Runtime suites use isolated, labeled resources and a shared temporary directory.
#

#
# Stop when a build or suite fails and reject unset variables.
#
set -eu

#
# Resolve the repository path consistently for nested Docker bind mounts.
#
repository_root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
suite=${1:-all}
: "${BUCCANEERR_TEST_IMAGE:=privateerr-buccaneerr:test}"
: "${PRIVATEERR_TEST_IMAGE:=privateerr:recovery-review}"
: "${DOCKER_BIN:=docker}"

#
# Reuse installed tools when a pre-commit hook already runs inside Buccaneerr.
#
if [ -n "${BUCCANEERR_BIN_HOME:-}" ] && [ -f "${BUCCANEERR_BIN_HOME}/checks.sh" ]; then
    cd "${repository_root}"
    exec sh "${BUCCANEERR_BIN_HOME}/checks.sh" "${suite}"
fi

#
# Build with Docker's cache so changed test tooling is never silently skipped.
#
"${DOCKER_BIN}" build --quiet --tag "${BUCCANEERR_TEST_IMAGE}" "${repository_root}/test" >/dev/null
set -- --rm --init --network none --volume "${repository_root}:${repository_root}:ro" --workdir "${repository_root}"

#
# Only explicit format, hook, and Docker acceptance runs need broader access.
#
case "${suite}" in
    format)
        set -- --rm --init --network none --volume "${repository_root}:${repository_root}" --workdir "${repository_root}"
        ;;
    runtime|live|smoke|precommit)
        test_root=$(mktemp -d "${TMPDIR:-/tmp}/privateerr-checks.XXXXXX")
        trap 'rm -rf "${test_root}"' EXIT HUP INT TERM
        docker_socket=$("${DOCKER_BIN}" context inspect --format '{{.Endpoints.docker.Host}}')

        #
        # Nested test containers must use the same daemon and host-visible temporary paths.
        #
        case "${docker_socket}" in
            unix://*) docker_socket=${docker_socket#unix://} ;;
            *) printf '%s\n' 'Runtime checks require a local Unix Docker socket.' >&2; exit 1 ;;
        esac

        set -- --rm --init \
            --volume "${repository_root}:${repository_root}" \
            --volume "${test_root}:${test_root}" \
            --volume "${docker_socket}:/var/run/docker.sock" \
            --workdir "${repository_root}" \
            --env "TMPDIR=${test_root}" \
            --env "PRIVATEERR_TEST_IMAGE=${PRIVATEERR_TEST_IMAGE}" \
            --env "BUCCANEERR_TEST_IMAGE=${BUCCANEERR_TEST_IMAGE}" \
            --env GLUETUN_TEST_IMAGE \
            --env QBITTORRENT_TEST_IMAGE \
            --env "PRIVATEERR_TEST_ENV_FILE=${PRIVATEERR_TEST_ENV_FILE:-.env}"
        ;;
esac

#
# Execute every check inside Buccaneerr; the host only launches Docker.
#
"${DOCKER_BIN}" run "$@" --entrypoint sh "${BUCCANEERR_TEST_IMAGE}" /buccaneerr/checks.sh "${suite}"
