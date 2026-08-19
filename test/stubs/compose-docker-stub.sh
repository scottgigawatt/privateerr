#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# compose-docker-stub.sh: Stand in for the Docker CLI during Compose helper
#                         tests without contacting a Docker daemon.
#
# Usage: PRIVATEERR_TEST_LOG=<path> test/stubs/compose-docker-stub.sh compose <args>
#

#
# Fail on errors and unset variables.
#
set -eu

#
# Ensure that the PRIVATEERR_TEST_LOG environment variable is set.
#
: "${PRIVATEERR_TEST_LOG:?PRIVATEERR_TEST_LOG is required}"

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
printf '%s\n' "$*" >"${PRIVATEERR_TEST_LOG}"
printf '%s\t%s\t%s\t%s\n' \
    "privateerr-latest" \
    "privateerr" \
    "Exited (0)" \
    "" \
    "gluetun-latest" \
    "gluetun" \
    "Up 1 minute (healthy)" \
    "0.0.0.0:9999->9999/tcp, [::]:9999->9999/tcp"
