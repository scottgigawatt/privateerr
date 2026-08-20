#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# compose-docker-stub.sh: Stand in for the Docker CLI during Compose helper
#                         tests without contacting a Docker daemon.
#
# Usage: COMPOSE_TEST_LOG=<path> test/stubs/compose-docker-stub.sh compose <args>
#

#
# Fail on errors and unset variables.
#
set -eu

#
# Ensure that the COMPOSE_TEST_LOG environment variable is set.
#
: "${COMPOSE_TEST_LOG:?COMPOSE_TEST_LOG is required}"

#
# Report Docker Compose availability without contacting a daemon.
#
if [ "$#" -ge 2 ] && [ "$1" = "compose" ] && [ "$2" = "version" ]; then
    echo "Docker Compose test stub"
    exit 0
fi

#
# Record the invocation and return stable tab-separated Compose status rows.
#
printf '%s\n' "$*" >"${COMPOSE_TEST_LOG}"
printf '%s\t%s\t%s\t%s\n' \
    "test-idle-latest" \
    "idle" \
    "Exited (0)" \
    "" \
    "test-gluetun-latest" \
    "gluetun" \
    "Up 1 minute (healthy)" \
    "0.0.0.0:6881->6881/tcp, [::]:6881->6881/tcp, 0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp, 0.0.0.0:6881->6881/udp, [::]:6881->6881/udp" \
    "test-service-latest" \
    "service" \
    "Up 1 minute (healthy)" \
    "0.0.0.0:9696->9696/tcp, [::]:9696->9696/tcp"
