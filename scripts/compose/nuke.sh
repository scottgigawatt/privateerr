#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# nuke.sh: Remove Docker resources attributable to one Compose project while
#          leaving repository files, bind-mounted config, and backups intact.
#
# Usage: scripts/compose/nuke.sh --docker-bin <path> --compose-mode <mode>
#        --compose-file <path> --env-file <path> --down-timeout <seconds>
#        [--compose-bin <path>] [--project-name <name>]
#        [--dockerfile <path> ...] [--base-image-awk <path>]
#        [--builder-name <name>] [--additional-image <reference> ...]
#

#
# Parsed command options.
#
docker_bin="docker"
compose_bin=""
compose_mode=""
compose_file=""
env_file=""
project_name=""
down_timeout=""
base_image_awk=""
builder_name=""
dockerfiles=""
additional_images=""
temporary_directory=""

#
# Fail on errors and unset variables.
#
set -eu

#
# cleanup: Remove the helper's temporary working directory.
#
# Parameters: None.
#
# Returns: Nothing.
#
cleanup() {
    if [ -n "${temporary_directory}" ] && [ -d "${temporary_directory}" ]; then
        rm -rf "${temporary_directory}"
    fi
}

#
# fail: Print a diagnostic and stop before further cleanup.
#
# Parameters: $1 - Diagnostic message.
#
# Returns: Exits with a failure status.
#
fail() {
    echo "ERROR: $1" >&2
    exit 1
}

#
# append_value: Add one value to a newline-delimited option list.
#
# Parameters: $1 - Existing list.
#             $2 - Value to append.
#
# Returns: Prints the updated list.
#
append_value() {
    if [ -n "$1" ]; then
        printf '%s\n%s' "$1" "$2"
    else
        printf '%s' "$2"
    fi
}

#
# require_command: Confirm a command name or executable path is available.
#
# Parameters: $1 - Command name or path.
#
# Returns: Exits with a diagnostic when the command is unavailable.
#
require_command() {
    case "$1" in
        */*)
            [ -x "$1" ] || fail "Required command is not executable: $1"
            ;;
        *)
            command -v "$1" >/dev/null 2>&1 \
                || fail "Required command was not found: $1"
            ;;
    esac
}

#
# compose_project: Run Docker Compose for the explicitly selected project.
#
# Parameters: $@ - Docker Compose subcommand and arguments.
#
# Returns: The Docker Compose exit status.
#
compose_project() {
    if [ "${compose_mode}" = "plugin" ]; then
        if [ -n "${project_name}" ]; then
            "${docker_bin}" compose \
                --project-name "${project_name}" \
                --env-file "${env_file}" \
                --file "${compose_file}" \
                "$@"
        else
            "${docker_bin}" compose \
                --env-file "${env_file}" \
                --file "${compose_file}" \
                "$@"
        fi
    else
        if [ -n "${project_name}" ]; then
            "${compose_bin}" \
                --project-name "${project_name}" \
                --env-file "${env_file}" \
                --file "${compose_file}" \
                "$@"
        else
            "${compose_bin}" \
                --env-file "${env_file}" \
                --file "${compose_file}" \
                "$@"
        fi
    fi
}

#
# image_ids: List local image IDs matching one reference.
#
# Parameters: $1 - Image reference.
#
# Returns: Prints matching image IDs or returns a Docker failure.
#
image_ids() {
    "${docker_bin}" image ls --quiet --no-trunc "$1"
}

#
# remove_owned_image: Remove a present service or explicitly owned local image.
#
# Parameters: $1 - Image reference.
#
# Returns: Succeeds when absent or removed; propagates real Docker failures.
#
remove_owned_image() {
    owned_image_ids=$(image_ids "$1") \
        || fail "Could not inspect local image reference: $1"
    if [ -z "${owned_image_ids}" ]; then
        return 0
    fi

    "${docker_bin}" image rm "$1" \
        || fail "Could not remove project image reference: $1"
}

#
# remove_base_image: Try to remove a declared base image without forcing it.
#
# Parameters: $1 - Base-image reference.
#
# Returns: Succeeds when absent or removed and warns when Docker retains it.
#
remove_base_image() {
    base_image_ids=$(image_ids "$1") \
        || fail "Could not inspect local base-image reference: $1"
    if [ -z "${base_image_ids}" ]; then
        return 0
    fi

    if ! "${docker_bin}" image rm "$1"; then
        echo "Retaining shared or in-use base image: $1" >&2
    fi
}

#
# Parse named options without evaluating shell command strings.
#
while [ "$#" -gt 0 ]; do
    case "$1" in
        --docker-bin)
            [ "$#" -ge 2 ] || fail "Missing value for --docker-bin."
            docker_bin=$2
            shift 2
            ;;
        --compose-bin)
            [ "$#" -ge 2 ] || fail "Missing value for --compose-bin."
            compose_bin=$2
            shift 2
            ;;
        --compose-mode)
            [ "$#" -ge 2 ] || fail "Missing value for --compose-mode."
            compose_mode=$2
            shift 2
            ;;
        --compose-file)
            [ "$#" -ge 2 ] || fail "Missing value for --compose-file."
            compose_file=$2
            shift 2
            ;;
        --env-file)
            [ "$#" -ge 2 ] || fail "Missing value for --env-file."
            env_file=$2
            shift 2
            ;;
        --project-name)
            [ "$#" -ge 2 ] || fail "Missing value for --project-name."
            project_name=$2
            shift 2
            ;;
        --down-timeout)
            [ "$#" -ge 2 ] || fail "Missing value for --down-timeout."
            down_timeout=$2
            shift 2
            ;;
        --dockerfile)
            [ "$#" -ge 2 ] || fail "Missing value for --dockerfile."
            dockerfiles=$(append_value "${dockerfiles}" "$2")
            shift 2
            ;;
        --base-image-awk)
            [ "$#" -ge 2 ] || fail "Missing value for --base-image-awk."
            base_image_awk=$2
            shift 2
            ;;
        --builder-name)
            [ "$#" -ge 2 ] || fail "Missing value for --builder-name."
            builder_name=$2
            shift 2
            ;;
        --additional-image)
            [ "$#" -ge 2 ] || fail "Missing value for --additional-image."
            additional_images=$(append_value "${additional_images}" "$2")
            shift 2
            ;;
        *)
            fail "Unknown option: $1"
            ;;
    esac
done

#
# Validate every input before issuing a destructive command.
#
[ -n "${compose_file}" ] || fail "--compose-file is required."
[ -n "${env_file}" ] || fail "--env-file is required."
[ -n "${down_timeout}" ] || fail "--down-timeout is required."
case "${down_timeout}" in
    *[!0-9]*) fail "--down-timeout must be a non-negative integer." ;;
esac
[ -f "${compose_file}" ] || fail "Compose file does not exist: ${compose_file}"
[ -f "${env_file}" ] || fail "Environment file does not exist: ${env_file}"
require_command "${docker_bin}"
require_command awk
require_command grep
require_command mktemp
require_command sort

case "${compose_mode}" in
    plugin)
        "${docker_bin}" compose version >/dev/null 2>&1 \
            || fail "Docker Compose plugin is unavailable through ${docker_bin}."
        ;;
    standalone)
        [ -n "${compose_bin}" ] || compose_bin="docker-compose"
        require_command "${compose_bin}"
        "${compose_bin}" version >/dev/null 2>&1 \
            || fail "Standalone Docker Compose is unavailable through ${compose_bin}."
        ;;
    "")
        if "${docker_bin}" compose version >/dev/null 2>&1; then
            compose_mode="plugin"
        elif command -v docker-compose >/dev/null 2>&1; then
            compose_mode="standalone"
            compose_bin="docker-compose"
        else
            fail "Neither the Docker Compose plugin nor docker-compose is available."
        fi
        ;;
    *)
        fail "--compose-mode must be plugin or standalone."
        ;;
esac

if [ -n "${dockerfiles}" ]; then
    [ -n "${base_image_awk}" ] \
        || fail "--base-image-awk is required when --dockerfile is used."
    [ -f "${base_image_awk}" ] \
        || fail "Base-image AWK program does not exist: ${base_image_awk}"

    while IFS= read -r dockerfile; do
        [ -n "${dockerfile}" ] || continue
        [ -f "${dockerfile}" ] || fail "Dockerfile does not exist: ${dockerfile}"
    done <<EOF
${dockerfiles}
EOF
fi

#
# Capture the resolved project model and every removal candidate before teardown.
#
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/compose-nuke.XXXXXX")
trap cleanup 0 1 2 15
: >"${temporary_directory}/base-images.raw"
project_description=${project_name:-selected environment project}

compose_project config --quiet \
    || fail "Docker Compose could not resolve ${project_description}."
compose_project config --images \
    >"${temporary_directory}/service-images.raw" \
    || fail "Docker Compose could not list images for ${project_description}."
sort -u "${temporary_directory}/service-images.raw" \
    >"${temporary_directory}/service-images"

if [ -n "${dockerfiles}" ]; then
    while IFS= read -r dockerfile; do
        [ -n "${dockerfile}" ] || continue
        awk -f "${base_image_awk}" "${dockerfile}" \
            >>"${temporary_directory}/base-images.raw"
    done <<EOF
${dockerfiles}
EOF
fi
sort -u "${temporary_directory}/base-images.raw" \
    >"${temporary_directory}/base-images"

#
# Remove the selected Compose project and its directly attributable resources.
#
compose_project down \
    --timeout "${down_timeout}" \
    --volumes \
    --remove-orphans \
    --rmi all \
    || fail "Docker Compose could not remove ${project_description}."

while IFS= read -r image_reference; do
    [ -n "${image_reference}" ] || continue
    remove_owned_image "${image_reference}"
done <"${temporary_directory}/service-images"

if [ -n "${additional_images}" ]; then
    while IFS= read -r image_reference; do
        [ -n "${image_reference}" ] || continue
        remove_owned_image "${image_reference}"
    done <<EOF
${additional_images}
EOF
fi

while IFS= read -r image_reference; do
    [ -n "${image_reference}" ] || continue
    remove_base_image "${image_reference}"
done <"${temporary_directory}/base-images"

if [ -n "${builder_name}" ]; then
    "${docker_bin}" buildx ls --format '{{.Name}}' \
        >"${temporary_directory}/builders" \
        || fail "Could not list Docker Buildx builders."
    if grep -F -x "${builder_name}" "${temporary_directory}/builders" >/dev/null; then
        "${docker_bin}" buildx rm --force "${builder_name}" \
            || fail "Could not remove Docker Buildx builder: ${builder_name}"
    fi
fi

echo "Removed Docker resources for ${project_description}."
