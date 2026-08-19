#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# notify-discord.sh: Send randomized Privateerr build notifications to an
#                    optional Discord webhook without exposing its value.
#
# Usage: DISCORD_WEBHOOK_URL=<url> notify-discord.sh --event <start|verdict> \
#        --template <deck|hades> --run-url <url> \
#        --repository <owner/repository> --ref-name <ref> [event options]
#

: "${DISCORD_WEBHOOK_URL:=}"
actor=""
discord_dry_run=false
discord_event=""
discord_random_value=""
discord_template=""
dockerhub_image=""
dockerhub_url=""
ghcr_image=""
ghcr_package_url=""
image_platforms=""
job_status=""
published_digest=""
published_tags=""
ref_name=""
repository=""
run_url=""
workflow_name=""

discord_color_failure_red=15158332
discord_color_hades_purple=10181046
discord_color_privateerr_blue=3447003
discord_color_success_green=3066993

set -eu

#
# usage: Print command-line options for both build notification events.
#
# Parameters: None.
#
# Returns: Prints usage text.
#
usage() {
    printf '%s\n' \
        "Usage: $0 --event <start|verdict> --template <deck|hades>" \
        "          --run-url <url> --repository <owner/repository>" \
        "          --ref-name <ref> [event options]" \
        "" \
        "Start options:" \
        "  -w, --workflow-name <name>" \
        "  -a, --actor <actor>" \
        "  -p, --platforms <platforms>" \
        "  -g, --ghcr-image <image>" \
        "  -d, --dockerhub-image <image>" \
        "" \
        "Verdict options:" \
        "  -s, --job-status <status>" \
        "  -g, --ghcr-image <image>" \
        "  -c, --ghcr-package-url <url>" \
        "  -b, --dockerhub-url <url>" \
        "  -l, --published-tags <tags>" \
        "  -i, --published-digest <digest>" \
        "" \
        "Common options:" \
        "  -e, --event <start|verdict>" \
        "  -t, --template <deck|hades>" \
        "  -u, --run-url <url>" \
        "  -r, --repository <owner/repository>" \
        "  -f, --ref-name <ref>" \
        "  -n, --random-value <integer>" \
        "  -x, --dry-run" \
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

while [ "$#" -gt 0 ]; do
    case "$1" in
        -e | --event) require_option_argument "$1" "$#"; discord_event=$2; shift 2 ;;
        -t | --template) require_option_argument "$1" "$#"; discord_template=$2; shift 2 ;;
        -u | --run-url) require_option_argument "$1" "$#"; run_url=$2; shift 2 ;;
        -r | --repository) require_option_argument "$1" "$#"; repository=$2; shift 2 ;;
        -f | --ref-name) require_option_argument "$1" "$#"; ref_name=$2; shift 2 ;;
        -w | --workflow-name) require_option_argument "$1" "$#"; workflow_name=$2; shift 2 ;;
        -a | --actor) require_option_argument "$1" "$#"; actor=$2; shift 2 ;;
        -p | --platforms) require_option_argument "$1" "$#"; image_platforms=$2; shift 2 ;;
        -g | --ghcr-image) require_option_argument "$1" "$#"; ghcr_image=$2; shift 2 ;;
        -d | --dockerhub-image) require_option_argument "$1" "$#"; dockerhub_image=$2; shift 2 ;;
        -s | --job-status) require_option_argument "$1" "$#"; job_status=$2; shift 2 ;;
        -c | --ghcr-package-url) require_option_argument "$1" "$#"; ghcr_package_url=$2; shift 2 ;;
        -b | --dockerhub-url) require_option_argument "$1" "$#"; dockerhub_url=$2; shift 2 ;;
        -l | --published-tags) require_option_argument "$1" "$#"; published_tags=$2; shift 2 ;;
        -i | --published-digest) require_option_argument "$1" "$#"; published_digest=$2; shift 2 ;;
        -n | --random-value) require_option_argument "$1" "$#"; discord_random_value=$2; shift 2 ;;
        -x | --dry-run) discord_dry_run=true; shift ;;
        -h | --help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

#
# random_value: Produce a non-negative integer for message selection.
#
# Parameters: None.
#
# Returns: Prints deterministic test input, OS randomness, or a checksum fallback.
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

    printf '%s' "$(date +%s)-$$-${discord_template}-${discord_event}" \
        | cksum \
        | awk '{print $1}'
}

#
# choose_message: Select one supplied message without evaluating its contents.
#
# Parameters: $@ - One or more complete message strings.
#
# Returns: Prints exactly one selected message.
#
choose_message() {
    if [ "$#" -eq 0 ]; then
        echo "choose_message requires at least one message." >&2
        return 1
    fi

    value=$(random_value)
    choice=$((value % $# + 1))
    while [ "${choice}" -gt 1 ]; do
        shift
        choice=$((choice - 1))
    done
    printf '%s\n' "$1"
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

if [ -z "${DISCORD_WEBHOOK_URL}" ] && [ "${discord_dry_run}" != "true" ]; then
    echo "Discord webhook is not configured; skipping notification."
    exit 0
fi

require_value --event "${discord_event}"
require_value --template "${discord_template}"
require_value --run-url "${run_url}"
require_value --repository "${repository}"
require_value --ref-name "${ref_name}"

case "${discord_template}" in
    deck)
        username="Privateerr Deck Crew"
        repository_label="🗺️ Repository"
        actor_label="🧑‍✈️ Captain"
        ;;
    hades)
        username="Hades Build Bureau"
        repository_label="🏛️ Repository"
        actor_label="🔥 Summoner"
        ;;
    *)
        echo "--template must be deck or hades." >&2
        exit 1
        ;;
esac

case "${discord_event}" in
    start)
        require_value --workflow-name "${workflow_name}"
        require_value --actor "${actor}"
        require_value --platforms "${image_platforms}"
        require_value --ghcr-image "${ghcr_image}"
        require_value --dockerhub-image "${dockerhub_image}"

        if [ "${discord_template}" = "deck" ]; then
            title="🏴‍☠️ Privateerr entered the shipyard"
            description=$(choose_message \
                "${workflow_name} is forging VPN paperwork for three architectures and at least one suspicious parrot." \
                "Privateerr is packing WireGuard charts. Gluetun is outside revving the tunnel." \
                "The build cannons are loaded with Alpine, provenance, and legally distinct optimism." \
                "The release bell rang. Every container put on a tiny captain's hat.")
            footer="Privateerr Deck Crew • generates maps, not tunnels"
            color=${discord_color_privateerr_blue}
        else
            title="🔥 The build crossed the gates"
            description=$(choose_message \
                "${workflow_name} entered Hades carrying source code and a surprisingly detailed risk assessment." \
                "The furnace is compiling. Cerberus checked all three architecture passports." \
                "Privateerr descended for a registry blessing and some tasteful smoke effects." \
                "The underworld build bureau stamped the YAML and misplaced the stapler.")
            footer="Hades Build Bureau • fire in, containers out"
            color=${discord_color_hades_purple}
        fi
        ;;
    verdict)
        require_value --job-status "${job_status}"
        require_value --ghcr-image "${ghcr_image}"

        if [ "${job_status}" = "success" ]; then
            color=${discord_color_success_green}
            if [ "${discord_template}" = "deck" ]; then
                title="✅ Images survived the voyage"
                description=$(choose_message \
                    "Both registries agree. The WireGuard cartography department may now exhale." \
                    "Privateerr reached the registries with provenance receipts and no loose credentials." \
                    "The manifests match and the tiny captain hats have been promoted to production." \
                    "The release sailed cleanly. Gluetun still does the actual tunneling, as union rules require.")
                footer="Privateerr Deck Crew • technically seaworthy"
            else
                title="😈 Furnace says done"
                description=$(choose_message \
                    "Images escaped the underworld. Docker Hub accepted the paperwork." \
                    "Cerberus inspected the manifests and found all three heads in agreement." \
                    "The build returned from Hades with matching digests and excellent cheekbones." \
                    "Privateerr survived the furnace. The logs have been released on good behavior.")
                footer="Hades Build Bureau • infernally reproducible"
            fi
        else
            color=${discord_color_failure_red}
            if [ "${discord_template}" = "deck" ]; then
                title="💥 Build hit a reef"
                description=$(choose_message \
                    "Privateerr ended ${job_status}. The logs have assumed command." \
                    "A dependency sneezed and the registry paperwork caught fire." \
                    "The build produced a breathtaking quantity of actionable regret." \
                    "The voyage stopped early. No credentials were harmed, but morale filed a ticket.")
                footer="Privateerr Deck Crew • the logs know what they did"
            else
                title="🔥 Furnace rejected the offering"
                description=$(choose_message \
                    "Publication ended ${job_status}. Cerberus is pointing at three different logs." \
                    "The underworld returned the build marked insufficiently cursed." \
                    "The manifest took a wrong turn near the river Styx." \
                    "Hades declined the release and attached diagnostics in triplicate.")
                footer="Hades Build Bureau • accountability remains underground"
            fi
        fi
        ;;
    *)
        echo "--event must be start or verdict." >&2
        exit 1
        ;;
esac

if [ "${discord_event}" = "start" ]; then
    payload=$(jq -n \
        --arg username "${username}" \
        --arg title "${title}" \
        --arg description "${description}" \
        --arg url "${run_url}" \
        --arg repository "${repository}" \
        --arg ref "${ref_name}" \
        --arg actor "${actor}" \
        --arg platforms "${image_platforms}" \
        --arg ghcr "${ghcr_image}" \
        --arg dockerhub "${dockerhub_image}" \
        --arg footer "${footer}" \
        --arg repository_label "${repository_label}" \
        --arg actor_label "${actor_label}" \
        --argjson color "${color}" \
        '{
            username: $username,
            embeds: [{
                title: $title, description: $description, url: $url, color: $color,
                fields: [
                    {name: $repository_label, value: $repository, inline: true},
                    {name: "🌿 Ref", value: $ref, inline: true},
                    {name: $actor_label, value: $actor, inline: true},
                    {name: "🧱 Platforms", value: $platforms, inline: false},
                    {name: "📦 GHCR", value: $ghcr, inline: false},
                    {name: "🐳 Docker Hub", value: $dockerhub, inline: false}
                ],
                footer: {text: $footer}, timestamp: now | todate
            }]
        }')
else
    formatted_tags=$(printf '%s\n' "${published_tags:-none}" \
        | sed '/^$/d; s#^'"${ghcr_image}"':##; s/^/• /')
    [ -n "${formatted_tags}" ] || formatted_tags="none"
    digest_short=$(printf '%s' "${published_digest:-unavailable}" \
        | sed -E 's/^(sha256:[0-9a-f]{12}).*/\1/')

    payload=$(jq -n \
        --arg username "${username}" \
        --arg title "${title}" \
        --arg description "${description}" \
        --arg url "${run_url}" \
        --arg repository "${repository}" \
        --arg ref "${ref_name}" \
        --arg tags "${formatted_tags}" \
        --arg digest "${digest_short}" \
        --arg ghcr_url "${ghcr_package_url:-unavailable}" \
        --arg dockerhub_url "${dockerhub_url:-unavailable}" \
        --arg footer "${footer}" \
        --arg repository_label "${repository_label}" \
        --argjson color "${color}" \
        '{
            username: $username,
            embeds: [{
                title: $title, description: $description, url: $url, color: $color,
                fields: [
                    {name: $repository_label, value: $repository, inline: true},
                    {name: "🌿 Ref", value: $ref, inline: true},
                    {name: "🏷️ Tags", value: $tags, inline: false},
                    {name: "🧾 Digest", value: $digest, inline: false},
                    {name: "📦 GHCR", value: $ghcr_url, inline: false},
                    {name: "🐳 Docker Hub", value: $dockerhub_url, inline: false}
                ],
                footer: {text: $footer}, timestamp: now | todate
            }]
        }')
fi

if [ "${discord_dry_run}" = "true" ]; then
    printf '%s\n' "${payload}"
    exit 0
fi

curl \
    --fail \
    --silent \
    --show-error \
    --header "Content-Type: application/json" \
    --data "${payload}" \
    "${DISCORD_WEBHOOK_URL}"
