#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# discord-notifier.sh: Render and deliver data-driven image and documentation
#                      notifications to an optional Discord webhook.
#
# Usage: DISCORD_WEBHOOK_URL=<url> discord-notifier.sh \
#            --type <image-start|image-verdict|docs-start|docs-verdict> \
#            --profile <image-primary|image-secondary|docs> \
#            --run-url <url> --repository <owner/repository> \
#            --ref-name <ref> [notification options]
#

#
# Keep only the webhook credential in the environment. All public workflow
# metadata and behavior arrive through documented command-line flags.
#
: "${DISCORD_WEBHOOK_URL:=}"
actor=""
image_name="Privateerr"
publication_status=""
mirror_status=""
failure_stage=""
build_status=""
deploy_status=""
discord_dry_run=false
discord_profile=""
discord_random_value=""
dockerhub_image=""
dockerhub_url=""
ghcr_image=""
ghcr_package_url=""
image_platforms=""
job_status=""
notification_type=""
outcome=""
published_digest=""
published_tags=""
ref_name=""
repository=""
run_url=""
site_url="unavailable"
workflow_name=""

#
# Fail on errors and unset variables.
#
set -eu

#
# Resolve notification assets relative to this script instead of the caller's
# working directory.
#
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
discord_directory=$(CDPATH='' cd -- "${script_directory}/../discord" && pwd)
themes_file="${discord_directory}/themes.jq"

#
# usage: Print common and notification-specific command-line options.
#
# Parameters: None.
#
# Returns: Prints usage text.
#
usage() {
    printf '%s\n' \
        "Usage: $0 --type <type> --profile <profile> --run-url <url>" \
        "          --repository <owner/repository> --ref-name <ref>" \
        "          [notification options]" \
        "" \
        "Notification types:" \
        "  image-start     Announce a container-image build." \
        "  image-verdict   Report a container-image publication result." \
        "  docs-start      Announce a documentation update." \
        "  docs-verdict    Report documentation build and deployment results." \
        "" \
        "Profiles:" \
        "  image-primary    Primary image-build destination." \
        "  image-secondary  Secondary image-build destination." \
        "  docs             Documentation destination." \
        "" \
        "Common options:" \
        "  -k, --type <type>" \
        "  -p, --profile <profile>" \
        "  -u, --run-url <url>" \
        "  -r, --repository <owner/repository>" \
        "  -f, --ref-name <ref>" \
        "  -n, --random-value <integer>" \
        "  -x, --dry-run" \
        "  -h, --help" \
        "" \
        "Image and documentation options:" \
        "  --image-name <name>" \
        "  --workflow-name <name>" \
        "  --actor <actor>" \
        "  --platforms <platforms>" \
        "  --ghcr-image <image>" \
        "  --dockerhub-image <image>" \
        "" \
        "Image-verdict options:" \
        "  --job-status <status>" \
        "  --publication-status <actual-push-outcome>" \
        "  --mirror-status <actual-Docker-Hub-copy-outcome>" \
        "  --failure-stage <stage>" \
        "  --ghcr-image <image>" \
        "  --ghcr-package-url <url>" \
        "  --dockerhub-url <url>" \
        "  --published-tags <tags>" \
        "  --published-digest <digest>" \
        "" \
        "Documentation-verdict options:" \
        "  --build-status <status>" \
        "  --deploy-status <status>" \
        "  --site-url <url>"
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
# random_value: Produce a non-negative integer for message selection.
#
# Parameters: None.
#
# Returns: Prints deterministic test input, operating-system randomness,
#          or a portable timestamp checksum fallback.
#
random_value() {
    if [ -n "${discord_random_value}" ]; then
        case "${discord_random_value}" in
            *[!0-9]*)
                echo "--random-value must be a non-negative integer." >&2
                return 1
                ;;
        esac
        printf '%s\n' "${discord_random_value}"
        return 0
    fi

    if [ -r /dev/urandom ] && command -v od >/dev/null 2>&1; then
        value=$(od -An -N4 -tu4 /dev/urandom | awk 'NF {print $1; exit}')
        if [ -n "${value}" ]; then
            printf '%s\n' "${value}"
            return 0
        fi
    fi

    printf '%s' "$(date +%s)-$$-${notification_type}-${discord_profile}-${outcome}" \
        | cksum \
        | awk '{print $1}'
}

#
# classify_status: Map a workflow conclusion to an explicit presentation state.
#
# Parameters: $1 - Workflow or job conclusion.
#
# Returns: Prints a supported catalog outcome; unknown conclusions warn.
#
classify_status() {
    case "$1" in
        success) printf '%s\n' success ;;
        failure | timed_out | startup_failure) printf '%s\n' failure ;;
        cancelled) printf '%s\n' cancelled ;;
        skipped) printf '%s\n' skipped ;;
        neutral) printf '%s\n' neutral ;;
        *) printf '%s\n' warning ;;
    esac
}

#
# Parse common and notification-specific command-line arguments.
#
while [ "$#" -gt 0 ]; do
    case "$1" in
        -k | --type)
            require_option_argument "$1" "$#"
            notification_type=$2
            shift 2
            ;;
        -p | --profile)
            require_option_argument "$1" "$#"
            discord_profile=$2
            shift 2
            ;;
        -u | --run-url)
            require_option_argument "$1" "$#"
            run_url=$2
            shift 2
            ;;
        -r | --repository)
            require_option_argument "$1" "$#"
            repository=$2
            shift 2
            ;;
        -f | --ref-name)
            require_option_argument "$1" "$#"
            ref_name=$2
            shift 2
            ;;
        -n | --random-value)
            require_option_argument "$1" "$#"
            discord_random_value=$2
            shift 2
            ;;
        -x | --dry-run)
            discord_dry_run=true
            shift
            ;;
        --image-name)
            require_option_argument "$1" "$#"
            image_name=$2
            shift 2
            ;;
        --publication-status)
            require_option_argument "$1" "$#"
            publication_status=$2
            shift 2
            ;;
        --mirror-status)
            require_option_argument "$1" "$#"
            mirror_status=$2
            shift 2
            ;;
        --failure-stage)
            require_option_argument "$1" "$#"
            failure_stage=$2
            shift 2
            ;;
        --workflow-name)
            require_option_argument "$1" "$#"
            workflow_name=$2
            shift 2
            ;;
        --actor)
            require_option_argument "$1" "$#"
            actor=$2
            shift 2
            ;;
        --platforms)
            require_option_argument "$1" "$#"
            image_platforms=$2
            shift 2
            ;;
        --ghcr-image)
            require_option_argument "$1" "$#"
            ghcr_image=$2
            shift 2
            ;;
        --dockerhub-image)
            require_option_argument "$1" "$#"
            dockerhub_image=$2
            shift 2
            ;;
        --job-status)
            require_option_argument "$1" "$#"
            job_status=$2
            shift 2
            ;;
        --ghcr-package-url)
            require_option_argument "$1" "$#"
            ghcr_package_url=$2
            shift 2
            ;;
        --dockerhub-url)
            require_option_argument "$1" "$#"
            dockerhub_url=$2
            shift 2
            ;;
        --published-tags)
            require_option_argument "$1" "$#"
            published_tags=$2
            shift 2
            ;;
        --published-digest)
            require_option_argument "$1" "$#"
            published_digest=$2
            shift 2
            ;;
        --build-status)
            require_option_argument "$1" "$#"
            build_status=$2
            shift 2
            ;;
        --deploy-status)
            require_option_argument "$1" "$#"
            deploy_status=$2
            shift 2
            ;;
        --site-url)
            require_option_argument "$1" "$#"
            site_url=$2
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
# Skip optional notifications without revealing whether a secret exists.
# Dry runs deliberately continue without a webhook for local payload tests.
#
if [ -z "${DISCORD_WEBHOOK_URL}" ] && [ "${discord_dry_run}" != "true" ]; then
    echo "Discord webhook is not configured; skipping notification."
    exit 0
fi

#
# Validate the metadata shared by every notification.
#
require_value --type       "${notification_type}"
require_value --profile    "${discord_profile}"
require_value --run-url    "${run_url}"
require_value --repository "${repository}"
require_value --ref-name   "${ref_name}"

#
# Validate each notification contract and derive its catalog outcome.
#
case "${notification_type}" in
    image-start)
        require_value --ghcr-image "${ghcr_image}"
        outcome="start"
        ;;
    image-verdict)
        require_value --job-status "${job_status}"
        require_value --ghcr-image "${ghcr_image}"
        outcome=$(classify_status "${job_status}")

        # A successful job without confirmed publication must never announce an image.
        if [ "${outcome}" = "success" ] && { [ "${publication_status}" != "success" ] || [ -z "${published_digest}" ]; }; then
            outcome="warning"
            failure_stage="Publication evidence is incomplete"
        fi
        ;;
    docs-start)
        outcome="start"
        ;;
    docs-verdict)
        require_value --build-status "${build_status}"
        require_value --deploy-status "${deploy_status}"
        outcome=$(classify_status "${build_status}")

        if [ "${build_status}" = "success" ]; then
            outcome=$(classify_status "${deploy_status}")
            failure_stage="Pages deployment"
        else
            failure_stage="Documentation build"
        fi
        ;;
    *)
        echo "--type must be image-start, image-verdict, docs-start, or docs-verdict." >&2
        exit 1
        ;;
esac

#
# Require the project-owned theme catalog before resolving a destination.
#
if [ ! -f "${themes_file}" ]; then
    printf 'Discord theme catalog was not found: %s\n' "${themes_file}" >&2
    exit 1
fi

#
# Resolve presentation metadata and one deterministic message from the stable
# destination profile. Theme names remain private to the structured data file.
#
selection=$(random_value)
if ! notification=$(jq \
    --null-input \
    --compact-output \
    --arg     image_name        "${image_name}" \
    --arg     notification_type "${notification_type}" \
    --arg     profile           "${discord_profile}" \
    --arg     outcome           "${outcome}" \
    --argjson selection         "${selection}" \
    --from-file                 "${themes_file}"); then
    printf 'No Discord definition for %s/%s/%s.\n' \
        "${notification_type}" "${discord_profile}" "${outcome}" >&2
    exit 1
fi

#
# Determine the external jq payload template for the selected notification type.
#
payload_path="${discord_directory}/payloads/${notification_type}.jq"

#
# Check that the selected payload template exists before attempting to render it.
#
if [ ! -f "${payload_path}" ]; then
    printf 'Discord payload template was not found: %s\n' "${payload_path}" >&2
    exit 1
fi

#
# Only confirmed pushes may expose tags as published metadata. Metadata actions
# can calculate tags before publication, and failed pushes may be incomplete.
#
if [ "${publication_status}" != "success" ] || [ -z "${published_digest}" ]; then
    published_tags=""
    published_digest=""
fi
formatted_tags=""

if [ "${notification_type}" = "image-verdict" ]; then
    formatted_tags=$(sh "${script_directory}/notification-tags.sh" \
        --image "${ghcr_image}" --tags "${published_tags}")
fi
digest_short=${published_digest:-unconfirmed}

#
# Render the selected external jq payload with workflow metadata passed only as
# data, never as executable shell or jq source.
#
payload=$(jq \
    --null-input \
    --argjson notification     "${notification}" \
    --arg     image_name       "${image_name}" \
    --arg     outcome          "${outcome}" \
    --arg     publication_status "${publication_status}" \
    --arg     mirror_status    "${mirror_status}" \
    --arg     failure_stage    "${failure_stage}" \
    --arg     workflow_name    "${workflow_name}" \
    --arg     notification_type "${notification_type}" \
    --arg     url              "${run_url}" \
    --arg     repository       "${repository}" \
    --arg     ref              "${ref_name}" \
    --arg     actor            "${actor}" \
    --arg     platforms        "${image_platforms}" \
    --arg     ghcr_image       "${ghcr_image}" \
    --arg     dockerhub_image  "${dockerhub_image}" \
    --arg     tags             "${formatted_tags}" \
    --arg     digest           "${digest_short}" \
    --arg     ghcr_url         "${ghcr_package_url:-unavailable}" \
    --arg     dockerhub_url    "${dockerhub_url:-unavailable}" \
    --arg     build_status     "${build_status}" \
    --arg     deploy_status    "${deploy_status}" \
    --arg     site_url         "${site_url}" \
    -L                         "${discord_directory}/payloads" \
    --from-file                "${payload_path}")

#
# Dry runs expose only the public payload for deterministic local tests.
#
if [ "${discord_dry_run}" = "true" ]; then
    printf '%s\n' "${payload}"
    exit 0
fi

#
# Capture only the numeric HTTP status. Suppress response bodies and raw curl
# errors so credentials, request payloads, headers, and URLs cannot reach logs.
#
if http_status=$(curl \
    --fail \
    --silent \
    --output /dev/null \
    --write-out '%{http_code}' \
    --connect-timeout 10 \
    --max-time 30 \
    --header "Content-Type: application/json" \
    --data "${payload}" \
    "${DISCORD_WEBHOOK_URL}" 2>/dev/null); then
    curl_exit=0
else
    curl_exit=$?
fi

#
# Only a three-digit status may enter the fixed diagnostic line. Preserve curl's
# exit behavior, including its existing handling of redirects and HTTP failures.
#
case "${http_status}" in
    [0-9][0-9][0-9]) ;;
    *) http_status=000 ;;
esac
printf 'Discord notification request finished: HTTP %s; curl exit %s.\n' \
    "${http_status}" "${curl_exit}"
exit "${curl_exit}"
