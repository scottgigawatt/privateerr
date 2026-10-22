#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# startup-docker-stub.sh: Record startup and teardown recipe calls without
#                         contacting Docker or a VPN provider.
#
# Usage: STARTUP_STUB_LOG=<path> startup-docker-stub.sh <arguments>
#

#
# Reject missing fixture settings and stop on failed assertions.
#
set -eu
: "${STARTUP_STUB_LOG:?STARTUP_STUB_LOG is required}"

#
# Intercept restoration copies so a parallel cleanup cannot overwrite active state.
#
if [ "${0##*/}" = cp ]; then
    printf 'copy %s\n' "$*" >>"${STARTUP_STUB_LOG}"
    : "${STARTUP_STUB_ROOT:?STARTUP_STUB_ROOT is required}"
    : "${STARTUP_STUB_DOWN_DONE:?STARTUP_STUB_DOWN_DONE is required}"
    test -f "${STARTUP_STUB_DOWN_DONE}"
    test "$#" -eq 2

    # Every intercepted destination must stay inside the disposable fixture tree.

    case "$2" in
        "${STARTUP_STUB_ROOT}/"*) exec /bin/cp "$@" ;;
        *) echo "Startup copy stub rejected a destination outside its fixtures." >&2; exit 49 ;;
    esac
fi

#
# Availability checks are not deployment actions and do not enter the action log.
#
if [ "$#" -ge 2 ] && [ "$1" = compose ] && [ "$2" = version ]; then
    echo "Docker Compose startup test stub"
    exit 0
fi

#
# Log actions before returning deterministic preflight, builder, and lifecycle results.
#
printf '%s\n' "$*" >>"${STARTUP_STUB_LOG}"

case " $* " in
    *" config --environment ")
        if [ "${STARTUP_STUB_FAIL:-}" = credentials ]; then
            printf '%s\n' 'PIA_USER=' 'PIA_PASS='
        else
            printf '%s\n' 'PIA_USER=p7654321' 'PIA_PASS=not-a-real-secret'
        fi
        ;;
    " buildx inspect "*)
        if [ "${STARTUP_STUB_BUILDER_MISSING:-false}" = true ]; then
            exit 40
        fi
        ;;
    " buildx create "*)
        if [ "${STARTUP_STUB_FAIL:-}" = builder-create ]; then
            exit 41
        fi
        ;;
    *" pull "*)
        if [ "${STARTUP_STUB_FAIL:-}" = pull ]; then
            exit 42
        fi
        ;;
    *" build "*)
        if [ "${STARTUP_STUB_FAIL:-}" = build ]; then
            exit 43
        fi
        ;;
    *" up "*)
        if [ "${STARTUP_STUB_FAIL:-}" = up ]; then
            exit 44
        fi
        ;;
    *" down "*)
        # A delay exposes restoration scheduled beside down under parallel Make.

        if [ -n "${STARTUP_STUB_DOWN_DELAY:-}" ]; then
            sleep "${STARTUP_STUB_DOWN_DELAY}"
        fi

        if [ "${STARTUP_STUB_FAIL:-}" = down ]; then
            exit 45
        fi

        if [ -n "${STARTUP_STUB_DOWN_DONE:-}" ]; then
            : >"${STARTUP_STUB_DOWN_DONE}"
        fi
        ;;
    *)
        echo "Unexpected startup Docker stub invocation: $*" >&2
        exit 99
        ;;
esac
