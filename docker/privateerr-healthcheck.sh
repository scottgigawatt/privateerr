#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# privateerr-healthcheck.sh: Report whether Privateerr generated its output successfully.
#

: "${PRIVATEERR_HEALTHCHECK_MARKER:=/healthcheck/privateerr.ready}"

test -f "${PRIVATEERR_HEALTHCHECK_MARKER}"
