#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# privateerr-healthcheck.sh: Report whether Privateerr generated its output successfully.
#

#
# Set the default path for the healthcheck marker file if not already set.
#
: "${PRIVATEERR_HEALTHCHECK_MARKER:=/healthcheck/privateerr.ready}"

#
# Check if the healthcheck marker file exists.
#
test -f "${PRIVATEERR_HEALTHCHECK_MARKER}"
