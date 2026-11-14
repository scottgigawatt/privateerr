#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# docker-nuke-stub.sh: Record Compose nuke-helper commands and return
#                      deterministic Docker, Compose, and Buildx responses.
#
# Usage: NUKE_STUB_LOG=<path> test/stubs/docker-nuke-stub.sh <arguments>
#

#
# Fail on errors and unset variables.
#
set -eu

#
# Require an isolated invocation log.
#
: "${NUKE_STUB_LOG:?NUKE_STUB_LOG is required}"

#
# Record every call without interpreting its arguments.
#
printf '%s\n' "$*" >>"${NUKE_STUB_LOG}"

# Retain argument boundaries for paths with spaces in layered Compose fixtures.
if [ -n "${NUKE_STUB_ARGUMENT_LOG:-}" ]; then
    printf '%s\n' '--call--' >>"${NUKE_STUB_ARGUMENT_LOG}"
    printf '<%s>\n' "$@" >>"${NUKE_STUB_ARGUMENT_LOG}"
fi

#
# Report plugin or standalone Compose availability.
#
if [ "$#" -ge 1 ] && { [ "$1" = "version" ] || { [ "$1" = "compose" ] && [ "${2:-}" = "version" ]; }; }; then
    echo "Docker Compose test stub"
    exit 0
fi

case " $* " in
    *" config --quiet "*)
        if [ "${NUKE_STUB_FAIL_COMPOSE:-}" = "config" ]; then
            exit 41
        fi
        exit 0
        ;;
    *" config --images "*)
        if [ "${NUKE_STUB_FAIL_DISCOVERY:-}" = "images" ]; then
            exit 46
        fi

        printf '%s\n' \
            "${NUKE_STUB_MODEL_IMAGE:-test/service:local}" \
            'test/absent:latest' \
            "${NUKE_STUB_MODEL_IMAGE:-test/service:local}"

        # Expose the test-only image only when its profile is part of the model.
        if [ "${NUKE_STUB_REQUIRE_PROFILE:-false}" = "true" ]; then
            case " $* " in
                *" --profile test "*) printf '%s\n' 'test/profiled:local' ;;
            esac
        fi

        exit 0
        ;;
    *" ps --all --quiet "*)
        if [ "${NUKE_STUB_FAIL_DISCOVERY:-}" = "ps" ]; then
            exit 44
        fi

        if [ -n "${NUKE_STUB_RUNTIME_IMAGE:-}" ]; then
            printf '%s\n' "${NUKE_STUB_CONTAINER_ID:-0123456789ab}"
        fi

        exit 0
        ;;
    *" container inspect --format "*)
        if [ "${NUKE_STUB_FAIL_DISCOVERY:-}" = "inspect" ]; then
            exit 45
        fi

        printf '%s\n' "${NUKE_STUB_RUNTIME_IMAGE:?Runtime image fixture is required}"
        exit 0
        ;;
    *" down --timeout "*)
        if [ "${NUKE_STUB_FAIL_COMPOSE:-}" = "down" ]; then
            exit 42
        fi
        exit 0
        ;;
    *" image ls --quiet --no-trunc "*)
        image_reference=""
        for argument in "$@"; do
            image_reference=${argument}
        done
        case "${image_reference}" in
            *absent*) exit 0 ;;
            *) echo "sha256:test-image-id" ;;
        esac
        exit 0
        ;;
    *" image rm "*)
        if [ -n "${NUKE_STUB_SHARED_IMAGE:-}" ] && [ "${3:-}" = "${NUKE_STUB_SHARED_IMAGE}" ]; then
            exit 47
        fi

        case " $* " in
            *" test/shared-base:1 "*) exit 43 ;;
            *) exit 0 ;;
        esac
        ;;
    *" buildx ls --format "*)
        printf '%s\n' 'test-builder' 'unrelated-builder'
        exit 0
        ;;
    *" buildx rm --force test-builder "*)
        exit 0
        ;;
esac

echo "Unexpected Docker nuke stub invocation: $*" >&2
exit 99
