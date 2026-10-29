#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# list-pia-regions.sh: Display all public PIA regions and port-forwarding support.
#
# Usage: scripts/compose/list-pia-regions.sh
#
# Requires curl and jq. Terminal output uses color unless NO_COLOR is nonempty.
# Reads only the public catalog; no account credentials or deployment files are needed.
#

set -eu

# Check host tools before making a public request.
for dependency in curl jq; do
    if ! command -v "${dependency}" >/dev/null 2>&1; then
        printf 'Required command not found: %s. Install it and retry.\n' "${dependency}" >&2
        exit 1
    fi
done

# Keep partial downloads and formatting failures out of the displayed table.
work_directory=$(mktemp -d "${TMPDIR:-/tmp}/privateerr-regions.XXXXXX")

#
# cleanup: Remove only this lookup's temporary public catalog files.
#
# Parameters: None.
#
# Returns: The cleanup command's exit status.
#
cleanup() {
    rm -rf "${work_directory}"
}

trap cleanup 0
trap 'exit 1' 1 2 15

# Stage each step separately so a failed request or parse cannot become a successful empty table.
curl --fail --silent --show-error --location --max-time 30 \
    --output "${work_directory}/catalog" \
    https://serverlist.piaservers.net/vpninfo/servers/v6
sed -n '1p' "${work_directory}/catalog" >"${work_directory}/catalog.json"

# Detect the caller's terminal before jq writes to a staging file.
color=false

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    color=true
fi

# Pad visible text before adding ANSI colors; the signed response's first line contains JSON.
jq --exit-status --raw-output --argjson color "${color}" '
  def pad($width): . + (" " * ($width - length));
  .regions
  | if type == "array" and length > 0 and all(.[];
      (.name | type) == "string" and (.id | type) == "string"
      and (.port_forward | type) == "boolean")
    then . else error("The PIA catalog has no valid region list.") end
  | [["LOCATION", "REGION ID", "PORT FORWARDING"]]
    + (sort_by(.name) | map([.name, .id, (if .port_forward then "Yes" else "No" end)]))
  | (map(.[0] | length) | max) as $name_width
  | (map(.[1] | length) | max) as $id_width
  | to_entries[]
  | .key as $index | .value as $row
  | (if $color and $index > 0 then
      (if $row[2] == "Yes" then "\u001b[32m" else "\u001b[31m" end)
      + $row[2] + "\u001b[0m"
    else $row[2] end) as $status
  | ($row[0] | pad($name_width)) + "  "
    + ($row[1] | pad($id_width)) + "  " + $status
  | if $color and $index == 0 then "\u001b[1;36m" + . + "\u001b[0m" else . end
' "${work_directory}/catalog.json" >"${work_directory}/table"
cat "${work_directory}/table"
