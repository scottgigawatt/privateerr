#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# privateerr-entrypoint.sh: Start the Python supervisor at the existing entrypoint path.
#
# Usage: docker/privateerr-entrypoint.sh
#
# The supervisor generates and validates PIA configuration, reports readiness,
# and optionally recovers Gluetun after sustained tunnel failure.
#

#
# Exit on command errors and reject unset variables.
#
set -eu

#
# Locate the package beside this script without changing the upstream working directory.
#
: "${PRIVATEERR_BIN_HOME:=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)}"
export PRIVATEERR_BIN_HOME
export PYTHONPATH="${PRIVATEERR_BIN_HOME}"
export PYTHONDONTWRITEBYTECODE=1

#
# Replace the wrapper so the supervisor receives container shutdown signals directly.
#
exec python3 -m privateerr
