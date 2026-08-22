#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
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
        printf '%s\n' \
            'test/service:local' \
            'test/absent:latest' \
            'test/service:local'
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
