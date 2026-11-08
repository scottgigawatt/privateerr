#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# test-discord-notifier.sh: Exercise notification states, publication evidence,
#                          metadata boundaries, and isolated delivery failures.
#
# Usage: test/helpers/test-discord-notifier.sh
#

#
# Keep fixtures isolated and remove only resources created by this suite.
#
set -eu
REPOSITORY_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "${TEST_ROOT}"' EXIT HUP INT TERM
NOTIFIER="${REPOSITORY_ROOT}/.github/scripts/discord-notifier.sh"

#
# render: Render deterministic synthetic metadata without contacting Discord.
#
# Parameters: $@ - Notification-specific arguments and overrides.
#
# Returns: Prints JSON on success; propagates renderer failures.
#
render() {
    sh "${NOTIFIER}" \
        --run-url https://example.invalid/run \
        --repository test/repository \
        --ref-name test-ref \
        --ghcr-image ghcr.io/test/image \
        --workflow-name 'A funny workflow title' \
        --actor test-contributor \
        --platforms linux/amd64,linux/arm64 \
        --dry-run "$@"
}

#
# assert_payload: Check Discord size limits, explicit status, and mention policy.
#
# Parameters: $1 - Expected embed color as a decimal integer.
#
# Returns: Nonzero if a rendered payload violates the contract.
#
assert_payload() {
    jq --exit-status --argjson color "$1" '
        .allowed_mentions.parse == []
        and (.username | length <= 80)
        and (.embeds[0] | .color == $color
          and (.title | length <= 256)
          and (.description | length <= 4096)
          and ([.fields[] | (.name | length <= 256) and (.value | length > 0 and length <= 1024)] | all)
          and (([.title, .description, .footer.text, (.fields[] | .name, .value)] | map(length) | add) <= 6000)
          and (.description | contains("A funny workflow title") | not))
    ' "${TEST_ROOT}/payload.json" >/dev/null
}

#
# Each maintained image has one started color for both destinations and every joke.
#
image_definitions='Privateerr:49919 Buccaneerr:16732120'
docs_color=49919

for definition in ${image_definitions}; do
    image_name=${definition%:*}
    start_color=${definition#*:}

    for profile in image-primary image-secondary; do
        for selection in 0 1 2; do
            render --type image-start --image-name "${image_name}" --profile "${profile}" \
                --random-value "${selection}" > "${TEST_ROOT}/payload.json"
            assert_payload "${start_color}"

            for state in success failure cancelled skipped neutral timed_out startup_failure action_required unknown; do
                case "${state}" in
                    success) color=5763719 ;;
                    failure | timed_out | startup_failure) color=15548997 ;;
                    cancelled | skipped | neutral) color=10070709 ;;
                    *) color=16705372 ;;
                esac

                render --type image-verdict --image-name "${image_name}" --profile "${profile}" \
                    --job-status "${state}" --publication-status success \
                    --published-tags ghcr.io/test/image:edge --published-digest sha256:0123456789abcdef \
                    --random-value "${selection}" > "${TEST_ROOT}/payload.json"
                assert_payload "${color}"
            done
        done
    done
done

#
# Documentation notices share started/status colors but distinguish failed stages.
#
for selection in 0 1; do
    render --type docs-start --profile docs --random-value "${selection}" > "${TEST_ROOT}/payload.json"
    assert_payload "${docs_color}"

    for state in success failure cancelled skipped neutral unknown; do
        case "${state}" in
            success) color=5763719 ;;
            failure) color=15548997 ;;
            cancelled | skipped | neutral) color=10070709 ;;
            *) color=16705372 ;;
        esac

        render --type docs-verdict --profile docs --build-status success --deploy-status "${state}" \
            --random-value "${selection}" > "${TEST_ROOT}/payload.json"
        assert_payload "${color}"
    done
done
render --type docs-verdict --profile docs --build-status failure --deploy-status skipped \
    > "${TEST_ROOT}/payload.json"
jq -e '.embeds[0].description | contains("documentation build")' "${TEST_ROOT}/payload.json" >/dev/null

#
# Metadata generated before a failed push is not advertised as published tags.
#
render --type image-verdict --profile image-primary --job-status failure --publication-status failure \
    --published-tags ghcr.io/test/image:never-published --published-digest sha256:unconfirmed \
    > "${TEST_ROOT}/payload.json"
jq -e '[.embeds[0].fields[].name] | index("🏷️ Published tags") == null' "${TEST_ROOT}/payload.json" >/dev/null
render --type image-verdict --profile image-primary --job-status success --publication-status success \
    --published-tags ghcr.io/test/image:never-confirmed > "${TEST_ROOT}/payload.json"
assert_payload 16705372
jq -e '[.embeds[0].fields[].name] | index("🏷️ Published tags") == null' "${TEST_ROOT}/payload.json" >/dev/null
render --type image-verdict --profile image-primary --job-status failure --publication-status success \
    --published-digest sha256:0123456789abcdef --failure-stage 'Registry verification' > "${TEST_ROOT}/payload.json"
jq -e '.embeds[0].description | contains("GHCR publication completed")' "${TEST_ROOT}/payload.json" >/dev/null

#
# Simultaneously large inputs exercise the aggregate budget and literal escaping.
#
long_value=$(awk 'BEGIN {for (i = 0; i < 1200; i++) printf "word "; print "@everyone \"quoted\""}')
render --type image-verdict --profile image-primary --job-status failure --publication-status success \
    --published-digest "${long_value}" --published-tags "${long_value}" \
    --ghcr-package-url "${long_value}" --dockerhub-url "${long_value}" \
    --failure-stage "${long_value}" --repository "${long_value}" --ref-name "${long_value}" \
    --workflow-name "${long_value}" --actor "${long_value}" --platforms "${long_value}" \
    > "${TEST_ROOT}/payload.json"
assert_payload 15548997
# The fixture must retain literal shell syntax instead of expanding it.
# shellcheck disable=SC2016
injection_value='$(touch never-created) `printf unsafe` "quoted"'
render --type image-start --profile image-primary --workflow-name "${injection_value}" \
    > "${TEST_ROOT}/payload.json"
jq -e --arg value "${injection_value}" '[.embeds[0].fields[] | select(.name == "⚙️ Workflow")][0].value == $value' \
    "${TEST_ROOT}/payload.json" >/dev/null

#
# Unknown destinations fail rather than selecting an unrelated server identity.
#
if render --type image-start --profile legacy > "${TEST_ROOT}/rejected.log" 2>&1; then
    echo "Unknown Discord profile was accepted." >&2
    exit 1
fi

#
# Stub delivery proves missing hooks skip, failures stay failures, and a later
# destination can still be attempted without any real network activity.
#
mkdir "${TEST_ROOT}/bin"
cat > "${TEST_ROOT}/bin/curl" <<'STUB'
#!/bin/sh
exit "${STUB_CURL_STATUS:-0}"
STUB
chmod +x "${TEST_ROOT}/bin/curl"
DISCORD_WEBHOOK_URL='' sh "${NOTIFIER}" > "${TEST_ROOT}/missing-hook.log"
if PATH="${TEST_ROOT}/bin:${PATH}" STUB_CURL_STATUS=22 DISCORD_WEBHOOK_URL=https://example.invalid/private-hook \
    sh "${NOTIFIER}" --type image-start --profile image-primary \
    --run-url https://example.invalid/run --repository test/repo --ref-name main \
    --ghcr-image ghcr.io/test/image > "${TEST_ROOT}/delivery.log" 2>&1; then
    echo "Discord delivery failure was hidden." >&2
    exit 1
fi
if grep -F 'private-hook' "${TEST_ROOT}/delivery.log" >/dev/null; then
    echo "Discord delivery exposed its webhook URL." >&2
    exit 1
fi
PATH="${TEST_ROOT}/bin:${PATH}" STUB_CURL_STATUS=0 DISCORD_WEBHOOK_URL=https://example.invalid/secondary-hook \
    sh "${NOTIFIER}" --type image-start --profile image-secondary \
    --run-url https://example.invalid/run --repository test/repo --ref-name main \
    --ghcr-image ghcr.io/test/image
printf '%s\n' 'Discord notifier tests passed.'
