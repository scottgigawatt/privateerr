#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# backup.sh: Archive one generated preset's complete config directory with a
#            collision-safe timestamped filename.
#
# Usage: scripts/compose/backup.sh <config-path> <backup-path> <preset>
#

#
# Fail on errors and unset variables.
#
set -eu

#
# Require the config path, backup path, and preset name.
#
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <config-path> <backup-path> <preset>" >&2
    exit 2
fi

config_path="$1"
backup_path="$2"
preset="$3"

#
# Reject a missing config directory before creating a backup destination.
#
if [ ! -d "${config_path}" ]; then
    echo "No ${config_path} directory found to archive." >&2
    exit 1
fi

#
# Create the preset's backup directory when it does not already exist.
#
mkdir -p "${backup_path}"

#
# Select a timestamped archive name without replacing an existing backup.
#
timestamp=$(date +%Y%m%d-%H%M%S)
archive="${backup_path}/${preset}-config-${timestamp}.tar.gz"
suffix=0

while [ -e "${archive}" ]; do
    suffix=$((suffix + 1))
    archive="${backup_path}/${preset}-config-${timestamp}-${suffix}.tar.gz"
done

#
# Archive the complete config path and report the recoverable artifact.
#
tar -czf "${archive}" "${config_path}"
printf 'Config cargo archived at %s. 📦\n' "${archive}"
