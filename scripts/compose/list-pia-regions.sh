#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# list-pia-regions.sh: Display all public PIA regions and port-forwarding support.
#
# Purpose: Help operators choose a region from PIA's current public catalog.
#
# Usage: scripts/compose/list-pia-regions.sh
#
# - Requires host curl and jq and access to PIA's public region catalog.
# - Stages public data in an isolated temporary directory and removes it on exit.
# - Colors terminal output unless NO_COLOR is nonempty; redirected output stays plain.
#

#
# Fail on errors and unset variables.
#
set -eu

#
# Check both host tools before creating temporary files or requesting the catalog.
#
for dependency in curl jq; do

    if ! command -v "${dependency}" >/dev/null 2>&1; then
        printf 'Required command not found: %s. Install it and retry.\n' "${dependency}" >&2
        exit 1
    fi

done

#
# Give each lookup its own temporary files so concurrent requests cannot overwrite each other.
#
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

#
# Route interruption through exit so cleanup also runs after a signal.
#
trap cleanup 0
trap 'exit 1' 1 2 15

#
# Finish the download before parsing so transport errors cannot produce a partial table.
#
curl --fail --silent --show-error --location --max-time 30 \
    --output "${work_directory}/catalog" \
    https://serverlist.piaservers.net/vpninfo/servers/v6

#
# PIA's signed response puts JSON on the first line and the signature on subsequent lines.
#
sed -n '1p' "${work_directory}/catalog" >"${work_directory}/catalog.json"

#
# Detect the caller's terminal before jq redirects its rendered output to a staging file.
#
color=false

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    color=true
fi

#
# Render the complete table before displaying it so validation errors leave stdout empty.
#
jq --exit-status --raw-output --argjson color "${color}" '
  #
  # pad: Pad a plain-text field before terminal color codes are added.
  #
  # Parameters: $width - Minimum field length in characters.
  #
  # Returns: The input string with trailing spaces to reach the requested length.
  #
  def pad($width):
    . + (" " * ($width - length));

  #
  # Validate every catalog row before constructing the headings or data rows.
  #
  .regions
  | if type == "array" and length > 0 and all(.[];
      (.name | type) == "string" and (.id | type) == "string"
      and (.port_forward | type) == "boolean")
    then
      .
    else
      error("The PIA catalog has no valid region list.")
    end

  #
  # Keep every region and sort by location; forwarding support changes the label, not membership.
  #
  | [["LOCATION", "REGION ID", "PORT FORWARDING"]]
    + (
      sort_by(.name)
      | map([
          .name,
          .id,

          (if .port_forward then
            "Yes"
          else
            "No"
          end)

        ])
    )

  #
  # Size columns from both headings and data before introducing ANSI escape sequences.
  #
  | (map(.[0] | length) | max) as $name_width
  | (map(.[1] | length) | max) as $id_width
  | to_entries[]
  | .key as $index | .value as $row

  #
  # Retain readable Yes/No labels when color is unavailable or explicitly disabled.
  #
  | (
      if $color and $index > 0 then

        (
          if $row[2] == "Yes" then
            "\u001b[32m"
          else
            "\u001b[31m"
          end
        )
        + $row[2] + "\u001b[0m"

      else
        $row[2]
      end
    ) as $status

  | ($row[0] | pad($name_width)) + "  "
    + ($row[1] | pad($id_width)) + "  " + $status

  | if $color and $index == 0 then
      "\u001b[1;36m" + . + "\u001b[0m"
    else
      .
    end
' "${work_directory}/catalog.json" >"${work_directory}/table"

cat "${work_directory}/table"
