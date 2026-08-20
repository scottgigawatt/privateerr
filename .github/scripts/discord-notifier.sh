#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# discord-notifier.sh: Render and deliver data-driven image and documentation
#                      notifications to an optional Discord webhook.
#
# Usage: DISCORD_WEBHOOK_URL=<url> discord-notifier.sh \
#            --type <image-start|image-verdict|docs-verdict> \
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
        "Image-start options:" \
        "  --workflow-name <name>" \
        "  --actor <actor>" \
        "  --platforms <platforms>" \
        "  --ghcr-image <image>" \
        "  --dockerhub-image <image>" \
        "" \
        "Image-verdict options:" \
        "  --job-status <status>" \
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
# expand_message: Replace supported literal tokens without evaluating content.
#
# Parameters: $1 - Selected message text.
#
# Returns: Prints the message with public workflow values substituted safely.
#
expand_message() {
    jq \
        --null-input \
        --raw-output \
        --arg message       "$1" \
        --arg workflow_name "${workflow_name}" \
        --arg job_status    "${job_status}" \
        --arg build_status  "${build_status}" \
        --arg deploy_status "${deploy_status}" \
        '
            def replace($token; $value): split($token) | join($value);
            $message
            | replace("{{workflow_name}}"; $workflow_name)
            | replace("{{job_status}}"; $job_status)
            | replace("{{build_status}}"; $build_status)
            | replace("{{deploy_status}}"; $deploy_status)
        '
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
        require_value --workflow-name   "${workflow_name}"
        require_value --actor           "${actor}"
        require_value --platforms       "${image_platforms}"
        require_value --ghcr-image      "${ghcr_image}"
        require_value --dockerhub-image "${dockerhub_image}"
        outcome="start"
        ;;
    image-verdict)
        require_value --job-status "${job_status}"
        require_value --ghcr-image "${ghcr_image}"
        if [ "${job_status}" = "success" ]; then
            outcome="success"
        else
            outcome="failure"
        fi
        ;;
    docs-verdict)
        require_value --build-status  "${build_status}"
        require_value --deploy-status "${deploy_status}"
        if [ "${build_status}" = "success" ] \
            && [ "${deploy_status}" = "success" ]; then
            outcome="success"
        else
            outcome="failure"
        fi
        [ -n "${site_url}" ] || site_url="unavailable"
        ;;
    *)
        echo "--type must be image-start, image-verdict, or docs-verdict." >&2
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
# Safely expand the message selected by the structured theme catalog.
#
selected_message=$(printf '%s\n' "${notification}" | jq --raw-output '.message')
description=$(expand_message "${selected_message}")

#
# Normalize optional publication metadata for the verdict payload.
#
formatted_tags=$(printf '%s\n' "${published_tags:-none}" \
    | sed '/^$/d; s#^'"${ghcr_image}"':##; s/^/• /')
[ -n "${formatted_tags}" ] || formatted_tags="none"
digest_short=$(printf '%s' "${published_digest:-unavailable}" \
    | sed -E 's/^(sha256:[0-9a-f]{12}).*/\1/')

#
# Render the selected external jq payload with workflow metadata passed only as
# data, never as executable shell or jq source.
#
payload=$(jq \
    --null-input \
    --argjson notification     "${notification}" \
    --arg     description      "${description}" \
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
    --from-file                "${payload_path}")

#
# Dry runs expose only the public payload for deterministic local tests.
#
if [ "${discord_dry_run}" = "true" ]; then
    printf '%s\n' "${payload}"
    exit 0
fi

#
# Deliver the payload without logging the webhook URL or JSON body.
#
curl \
    --fail \
    --silent \
    --show-error \
    --header "Content-Type: application/json" \
    --data "${payload}" \
    "${DISCORD_WEBHOOK_URL}"
