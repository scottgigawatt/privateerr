#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# ps.sh: Display the Privateerr Compose project's containers in a compact table.
#
# Usage: scripts/compose/ps.sh --env-file <path> --compose-file <path> [options]
#

#
# Variables for the Compose project and its environment.
#
compose_file=""
docker_bin="docker"
env_file=""

#
# Fail on errors and unset variables.
#
set -eu

#
# usage: Print the supported command-line options.
#
# Parameters: None.
#
# Returns: Prints usage text.
#
usage() {
    printf '%s\n' \
        "Usage: $0 --env-file <path> --compose-file <path> [options]" \
        "" \
        "Options:" \
        "  -e, --env-file <path>" \
        "  -f, --compose-file <path>" \
        "  -d, --docker-bin <command>" \
        "  -h, --help"
}

#
# require_option_argument: Reject a flag whose value is missing.
#
# Parameters: $1 - Option name.
#             $2 - Number of remaining command-line arguments.
#
# Returns: 0 when a value follows; otherwise exits with status 2.
#
require_option_argument() {
    if [ "$2" -lt 2 ]; then
        printf '%s requires a value.\n' "$1" >&2
        exit 2
    fi
}

#
# format_status_table: Align status rows and stack concise published port lists.
#
# Parameters: None. Reads tab-separated Compose status rows from standard input.
#
# Returns: Prints a compact status table.
#
format_status_table() {
    awk -F '\t' '
        BEGIN {
            name_width = length("NAME")
            service_width = length("SERVICE")
            status_width = length("STATUS")
            stack_threshold = 1
        }

        {
            row_count++
            names[row_count] = $1
            services[row_count] = $2
            statuses[row_count] = $3
            raw_port_count = split($4, raw_ports, /,[[:space:]]*/)
            port_lists[row_count] = ""
            for (raw_port = 1; raw_port <= raw_port_count; raw_port++) {
                normalized_port = raw_ports[raw_port]
                sub(/^0\.0\.0\.0:/, "", normalized_port)
                sub(/^\[::\]:/, "", normalized_port)
                port_key = row_count SUBSEP normalized_port
                if (normalized_port == "" || seen_ports[port_key]++) {
                    continue
                }
                if (port_lists[row_count] != "") {
                    port_lists[row_count] = port_lists[row_count] ", "
                }
                port_lists[row_count] = port_lists[row_count] normalized_port
            }

            if (length($1) > name_width) {
                name_width = length($1)
            }
            if (length($2) > service_width) {
                service_width = length($2)
            }
            if (length($3) > status_width) {
                status_width = length($3)
            }
        }

        END {
            row_format = "%-" name_width "s  %-" service_width "s  %-" status_width "s  %s\n"
            printf row_format, "NAME", "SERVICE", "STATUS", "PORTS"

            for (row = 1; row <= row_count; row++) {
                port_count = split(port_lists[row], ports, /,[[:space:]]*/)
                if (port_lists[row] == "") {
                    port_count = 0
                }

                if (port_count <= stack_threshold) {
                    printf row_format, names[row], services[row], statuses[row], port_lists[row]
                    continue
                }

                printf row_format, names[row], services[row], statuses[row], ports[1]
                for (port = 2; port <= port_count; port++) {
                    printf row_format, "", "", "", ports[port]
                }
            }
        }
    '
}

#
# Parse command-line flags and arguments.
#
while [ "$#" -gt 0 ]; do
    case "$1" in
        -e | --env-file)
            require_option_argument "$1" "$#"
            env_file=$2
            shift 2
            ;;
        -f | --compose-file)
            require_option_argument "$1" "$#"
            compose_file=$2
            shift 2
            ;;
        -d | --docker-bin)
            require_option_argument "$1" "$#"
            docker_bin=$2
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

#
# Validate that the required paths were provided.
#
if [ ! -f "${env_file}" ]; then
    printf 'Environment file not found: %s\n' "${env_file}" >&2
    exit 1
fi

#
# Validate required paths before asking Compose to inspect the project.
#
if [ ! -f "${compose_file}" ]; then
    printf 'Compose file not found: %s\n' "${compose_file}" >&2
    exit 1
fi

#
# Prefer Docker Compose v2 and retain support for a standalone v1 installation.
# Compose owns project-name resolution, so repository .env defaults remain correct.
#
if "${docker_bin}" compose version >/dev/null 2>&1; then
    compose_status=$("${docker_bin}" compose \
        --env-file "${env_file}" \
        -f "${compose_file}" \
        ps \
        --format '{{.Name}}\t{{.Service}}\t{{.Status}}\t{{.Ports}}')
    printf '%s' "${compose_status}" | format_status_table
elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose \
        --env-file "${env_file}" \
        -f "${compose_file}" \
        ps
else
    echo "Neither 'docker compose' nor 'docker-compose' is available." >&2
    exit 1
fi
