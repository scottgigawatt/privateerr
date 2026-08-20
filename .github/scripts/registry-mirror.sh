#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# registry-mirror.sh: Mirror published container-image tags from GHCR to Docker
#                     Hub and verify that both registries expose matching digests.
#
# Usage: GHCR_TOKEN=<token> DOCKERHUB_TOKEN=<token> registry-mirror.sh \
#            <--mirror|--verify> --ghcr-image <image> --dockerhub-image <image> \
#            --ghcr-username <name> --dockerhub-username <name> \
#            --published-tags <tags>
#

#
# Keep only registry credentials in the environment. All public workflow
# metadata and behavior arrive through documented command-line flags.
#
: "${DOCKERHUB_TOKEN:=}"
: "${GHCR_TOKEN:=}"
dockerhub_image=""
dockerhub_username=""
ghcr_image=""
ghcr_username=""
operation=""
published_tags=""
skopeo_bin="skopeo"

#
# Fail on errors and unset variables.
#
set -eu

#
# usage: Print the supported registry operation and metadata flags.
#
# Parameters: None.
#
# Returns: Prints usage text.
#
usage() {
    printf '%s\n' \
        "Usage: $0 <--mirror|--verify> --ghcr-image <image>" \
        "          --dockerhub-image <image> --ghcr-username <name>" \
        "          --dockerhub-username <name> --published-tags <tags>" \
        "" \
        "Options:" \
        "  -m, --mirror" \
        "  -v, --verify" \
        "  -g, --ghcr-image <image>" \
        "  -d, --dockerhub-image <image>" \
        "  -u, --ghcr-username <name>" \
        "  -U, --dockerhub-username <name>" \
        "  -t, --published-tags <tags>" \
        "  -s, --skopeo-bin <path>" \
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
# require_value: Reject a missing workflow input with a useful field name.
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
# dockerhub_tag_for: Translate one GHCR tag into its Docker Hub counterpart.
#
# Parameters: $1 - Fully qualified GHCR tag.
#
# Returns: Prints the equivalent Docker Hub tag.
#
dockerhub_tag_for() {
    case "$1" in
        "${ghcr_image}":*)
            printf '%s%s\n' "${dockerhub_image}" "${1#"${ghcr_image}"}"
            ;;
        *)
            printf 'Published tag is outside GHCR_IMAGE: %s\n' "$1" >&2
            return 1
            ;;
    esac
}

#
# mirror_tags: Copy every published multi-architecture tag to Docker Hub.
#
# Parameters: None.
#
# Returns: 0 when every copy succeeds; otherwise returns nonzero.
#
mirror_tags() {
    printf '%s\n' "${published_tags}" \
        | while IFS= read -r ghcr_tag; do
            [ -n "${ghcr_tag}" ] || continue
            dockerhub_tag=$(dockerhub_tag_for "${ghcr_tag}")
            "${skopeo_bin}" copy \
                --all \
                --preserve-digests \
                --src-creds "${ghcr_username}:${GHCR_TOKEN}" \
                --dest-creds "${dockerhub_username}:${DOCKERHUB_TOKEN}" \
                "docker://${ghcr_tag}" \
                "docker://${dockerhub_tag}"
        done
}

#
# verify_mirrors: Compare every published tag across both registries.
#
# Parameters: None.
#
# Returns: 0 when every pair of digests matches; otherwise returns nonzero.
#
verify_mirrors() {
    printf '%s\n' "${published_tags}" \
        | while IFS= read -r ghcr_tag; do
            [ -n "${ghcr_tag}" ] || continue
            dockerhub_tag=$(dockerhub_tag_for "${ghcr_tag}")

            # Inspect both registry tags to get their digests.
            ghcr_digest=$("${skopeo_bin}" inspect \
                --creds "${ghcr_username}:${GHCR_TOKEN}" \
                --format '{{.Digest}}' \
                "docker://${ghcr_tag}")
            dockerhub_digest=$("${skopeo_bin}" inspect \
                --creds "${dockerhub_username}:${DOCKERHUB_TOKEN}" \
                --format '{{.Digest}}' \
                "docker://${dockerhub_tag}")

            # Report the exact tag pair when registry content differs.
            if [ "${ghcr_digest}" != "${dockerhub_digest}" ]; then
                printf 'Registry digest mismatch for %s: GHCR=%s DockerHub=%s\n' \
                    "${ghcr_tag}" "${ghcr_digest}" "${dockerhub_digest}" >&2
                return 1
            fi

            printf 'Registry manifests match for %s at %s.\n' \
                "${ghcr_tag}" "${ghcr_digest}"
        done
}

#
# Parse command-line flags and arguments.
#
while [ "$#" -gt 0 ]; do
    case "$1" in
        -m | --mirror)
            operation=mirror
            shift
            ;;
        -v | --verify)
            operation=verify
            shift
            ;;
        -g | --ghcr-image)
            require_option_argument "$1" "$#"
            ghcr_image=$2
            shift 2
            ;;
        -d | --dockerhub-image)
            require_option_argument "$1" "$#"
            dockerhub_image=$2
            shift 2
            ;;
        -u | --ghcr-username)
            require_option_argument "$1" "$#"
            ghcr_username=$2
            shift 2
            ;;
        -U | --dockerhub-username)
            require_option_argument "$1" "$#"
            dockerhub_username=$2
            shift 2
            ;;
        -t | --published-tags)
            require_option_argument "$1" "$#"
            published_tags=$2
            shift 2
            ;;
        -s | --skopeo-bin)
            require_option_argument "$1" "$#"
            skopeo_bin=$2
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
# Validate that all required inputs are present.
#
require_value --operation "${operation}"
require_value --ghcr-image "${ghcr_image}"
require_value --dockerhub-image "${dockerhub_image}"
require_value --ghcr-username "${ghcr_username}"
require_value GHCR_TOKEN "${GHCR_TOKEN}"
require_value --dockerhub-username "${dockerhub_username}"
require_value DOCKERHUB_TOKEN "${DOCKERHUB_TOKEN}"
require_value --published-tags "${published_tags}"

#
# Dispatch the requested operation.
#
case "${operation}" in
    mirror)
        mirror_tags
        ;;
    verify)
        verify_mirrors
        ;;
esac
