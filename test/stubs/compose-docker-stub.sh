#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# compose-docker-stub.sh: Stand in for Docker during Compose helper tests.
#
# Usage: PRIVATEERR_TEST_LOG=<path> compose-docker-stub.sh compose <args>
#

set -eu

: "${PRIVATEERR_TEST_LOG:?PRIVATEERR_TEST_LOG is required}"

if [ "$#" -ge 2 ] && [ "$1" = "compose" ] && [ "$2" = "version" ]; then
    echo "Docker Compose test stub"
    exit 0
fi

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
