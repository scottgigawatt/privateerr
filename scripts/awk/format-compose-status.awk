#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# format-compose-status.awk: Align tab-separated Docker Compose status rows,
#                            deduplicate bindings, and stack published ports.
#
# Usage: awk -F '\t' -f scripts/awk/format-compose-status.awk
#

#
# Seed column widths from the table headings and stack every row containing
# more than one distinct published port.
#
BEGIN {
  name_width      = length("NAME")
  service_width   = length("SERVICE")
  status_width    = length("STATUS")
  stack_threshold = 1
}

#
# Preserve each status row, normalize wildcard host bindings, remove duplicate
# IPv4 and IPv6 publications, and track the widest visible column values.
#
{
  row_count++

  names[row_count]      = $1
  services[row_count]   = $2
  statuses[row_count]   = $3
  port_lists[row_count] = ""
  raw_port_count        = split($4, raw_ports, /,[[:space:]]*/)

  #
  # Collapse equivalent wildcard bindings while preserving distinct protocols
  # and published-to-container port mappings in their original order.
  #
  for (raw_port = 1; raw_port <= raw_port_count; raw_port++) {
    normalized_port = raw_ports[raw_port]

    sub(/^0\.0\.0\.0:/, "", normalized_port)
    sub(/^\[::\]:/, "", normalized_port)

    port_key = row_count SUBSEP normalized_port

    # Ignore empty and previously recorded bindings for this container.
    if (normalized_port == "" || seen_ports[port_key]++) {
      continue
    }

    # Separate each retained binding with one readable comma-space pair.
    if (port_lists[row_count] != "") {
      port_lists[row_count] = port_lists[row_count] ", "
    }

    port_lists[row_count] = port_lists[row_count] normalized_port
  }

  #
  # Expand only the fixed-width columns; the final ports column remains free
  # to use one continuation row per additional publication.
  #
  # Expand the name column for the longest container name.
  if (length(names[row_count]) > name_width) {
    name_width = length($1)
  }

  # Expand the service column for the longest Compose service name.
  if (length(services[row_count]) > service_width) {
    service_width = length($2)
  }

  # Expand the status column for the longest container status.
  if (length(statuses[row_count]) > status_width) {
    status_width = length($3)
  }
}

#
# Print the aligned heading and each stored row, stacking additional ports
# beneath blank identity columns for terminal-friendly scanning.
#
END {
  row_format = "%-" name_width "s  %-" service_width "s  %-" status_width "s  %s\n"

  printf row_format, "NAME", "SERVICE", "STATUS", "PORTS"

  for (row = 1; row <= row_count; row++) {
    port_count = split(port_lists[row], ports, /,[[:space:]]*/)

    # Treat an empty port list as zero ports instead of one empty field.
    if (port_lists[row] == "") {
      port_count = 0
    }

    # Keep rows with zero or one port on a single output line.
    if (port_count <= stack_threshold) {
      printf row_format, names[row], services[row], statuses[row], port_lists[row]
      continue
    }

    printf row_format, names[row], services[row], statuses[row], ports[1]

    # Stack remaining bindings beneath blank identity columns.
    for (port = 2; port <= port_count; port++) {
      printf row_format, "", "", "", ports[port]
    }
  }
}
