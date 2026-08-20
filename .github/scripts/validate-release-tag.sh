#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# validate-release-tag.sh: Validate that a release tag uses semantic
#                          versioning, is annotated, and belongs to main.
#
# Usage: validate-release-tag.sh --release-tag <tag> --release-sha <sha>
#

#
# Release metadata supplied explicitly by the calling workflow.
#
release_sha=""
release_tag=""

#
# Repository policy for published releases.
#
main_branch="main"
remote_name="origin"
semver_pattern='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*)|([0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))(\.((0|[1-9][0-9]*)|([0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)))*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'

#
# Fail on errors and unset variables.
#
set -eu

#
# usage: Print the supported release metadata flags.
#
# Parameters: None.
#
# Returns: Prints usage text.
#
usage() {
    printf '%s\n' \
        "Usage: $0 --release-tag <tag> --release-sha <sha>" \
        "" \
        "Options:" \
        "  -t, --release-tag <tag>" \
        "  -s, --release-sha <sha>" \
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
# require_value: Reject missing release metadata with a useful field name.
#
# Parameters: $1 - Input name.
#             $2 - Input value.
#
# Returns: 0 when present; otherwise returns 1.
#
require_value() {
    if [ -z "$2" ]; then
        printf '%s is required.\n' "$1" >&2
        return 1
    fi
}

#
# validate_semver: Require a v-prefixed semantic-version release tag.
#
# Parameters: $1 - Release tag to validate.
#
# Returns: 0 for valid semantic versioning; otherwise returns 1.
#
validate_semver() {
    if ! printf '%s\n' "$1" | grep -Eq "${semver_pattern}"; then
        printf 'Release tag %s is not valid semantic versioning.\n' "$1" >&2
        return 1
    fi
}

#
# validate_annotated_tag: Require the release reference to be an annotated tag.
#
# Parameters: $1 - Release tag to inspect.
#
# Returns: 0 for an annotated tag; otherwise returns 1.
#
validate_annotated_tag() {
    tag_ref="refs/tags/$1"

    if ! tag_type=$(git cat-file -t "${tag_ref}" 2>/dev/null); then
        printf 'Release tag %s does not exist in the checkout.\n' "$1" >&2
        return 1
    fi

    if [ "${tag_type}" != "tag" ]; then
        printf 'Release tag %s must be annotated.\n' "$1" >&2
        return 1
    fi
}

#
# validate_main_ancestry: Require the release commit to belong to remote main.
#
# Parameters: $1 - Release tag used in diagnostics.
#             $2 - Release commit SHA to inspect.
#
# Returns: 0 when the commit belongs to main; otherwise returns 1.
#
validate_main_ancestry() {
    if ! git fetch --quiet --no-tags "${remote_name}" "${main_branch}"; then
        printf 'Unable to fetch %s from %s for release validation.\n' \
            "${main_branch}" "${remote_name}" >&2
        return 1
    fi

    if ! git merge-base --is-ancestor "$2" "${remote_name}/${main_branch}"; then
        printf 'Release tag %s does not point to a commit on %s.\n' \
            "$1" "${main_branch}" >&2
        return 1
    fi
}

#
# Parse command-line flags and arguments.
#
while [ "$#" -gt 0 ]; do
    case "$1" in
        -t | --release-tag)
            require_option_argument "$1" "$#"
            release_tag=$2
            shift 2
            ;;
        -s | --release-sha)
            require_option_argument "$1" "$#"
            release_sha=$2
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
# Validate required metadata before consulting Git.
#
require_value --release-tag "${release_tag}"
require_value --release-sha "${release_sha}"

#
# Enforce every release policy before image publication begins.
#
validate_semver "${release_tag}"
validate_annotated_tag "${release_tag}"
validate_main_ancestry "${release_tag}" "${release_sha}"

printf 'Release tag %s is annotated and points to a commit on %s.\n' \
    "${release_tag}" "${main_branch}"
