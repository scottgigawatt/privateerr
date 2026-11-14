#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# test-compose-nuke.sh: Validate project-scoped destructive cleanup without
#                       contacting the developer's Docker daemon.
#
# Usage: test/helpers/test-compose-nuke.sh
#

#
# Directory for isolated nuke-helper fixtures.
#
test_output=""

#
# Fail on errors and unset variables.
#
set -eu

#
# cleanup: Remove the isolated nuke-helper test directory.
#
# Parameters: None.
#
# Returns: Nothing.
#
cleanup() {
    if [ -n "${test_output}" ] && [ -d "${test_output}" ]; then
        rm -rf "${test_output}"
    fi
}

#
# Create isolated project fixtures and register cleanup on exit.
#
test_output=$(mktemp -d)
trap cleanup 0 1 2 15
stub_path="$(pwd)/test/stubs/docker-nuke-stub.sh"
: >"${test_output}/compose-file.yml"
: >"${test_output}/project.env"
printf '%s\n' 'FROM test/shared-base:1' >"${test_output}/Dockerfile.test"
mkdir -p "${test_output}/config" "${test_output}/backups"
printf '%s\n' 'preserve me' >"${test_output}/project.env.preserved"
printf '%s\n' 'preserve me' >"${test_output}/config/state.db"
printf '%s\n' 'preserve me' >"${test_output}/backups/config.tar.gz"

#
# Reject incomplete arguments before invoking Docker.
#
: >"${test_output}/missing.log"
if NUKE_STUB_LOG="${test_output}/missing.log" \
    sh scripts/compose/nuke.sh --docker-bin "${stub_path}" \
        >"${test_output}/missing.out" 2>&1; then
    echo "Compose nuke helper accepted incomplete arguments." >&2
    exit 1
fi
grep -F -- '--compose-file is required.' "${test_output}/missing.out" >/dev/null
test ! -s "${test_output}/missing.log"

#
# Remove one isolated project while retaining shared base images and host files.
#
: >"${test_output}/nuke.log"
NUKE_STUB_LOG="${test_output}/nuke.log" \
    sh scripts/compose/nuke.sh \
        --docker-bin "${stub_path}" \
        --compose-mode plugin \
        --compose-file "${test_output}/compose-file.yml" \
        --env-file "${test_output}/project.env" \
        --project-name test-project \
        --down-timeout 45 \
        --dockerfile "${test_output}/Dockerfile.test" \
        --base-image-awk scripts/awk/collect-dockerfile-base-images.awk \
        --builder-name test-builder \
        --additional-image test/additional:local \
        >"${test_output}/nuke.out" 2>&1

grep -F "compose --project-name test-project --env-file ${test_output}/project.env --file ${test_output}/compose-file.yml config --quiet" \
    "${test_output}/nuke.log" >/dev/null
grep -F "compose --project-name test-project --env-file ${test_output}/project.env --file ${test_output}/compose-file.yml config --images" \
    "${test_output}/nuke.log" >/dev/null
grep -F "compose --project-name test-project --env-file ${test_output}/project.env --file ${test_output}/compose-file.yml down --timeout 45 --volumes --remove-orphans --rmi all" \
    "${test_output}/nuke.log" >/dev/null
grep -F 'image rm test/service:local' "${test_output}/nuke.log" >/dev/null
grep -F 'image rm test/additional:local' "${test_output}/nuke.log" >/dev/null
grep -F 'image rm test/shared-base:1' "${test_output}/nuke.log" >/dev/null
grep -F "Retaining shared or in-use base image: test/shared-base:1" \
    "${test_output}/nuke.out" >/dev/null
grep -F 'buildx rm --force test-builder' "${test_output}/nuke.log" >/dev/null

test "$(grep -c 'image rm test/service:local' "${test_output}/nuke.log")" -eq 1
if grep -E 'system prune|image prune|volume prune|builder prune|--all-inactive|buildx rm --force unrelated-builder' \
    "${test_output}/nuke.log" >/dev/null; then
    echo "Compose nuke helper invoked a global or unrelated cleanup command." >&2
    exit 1
fi

test -f "${test_output}/project.env"
test -f "${test_output}/project.env.preserved"
test -f "${test_output}/config/state.db"
test -f "${test_output}/backups/config.tar.gz"

# Keep callers that omit a profile limited to the original service inventory.
if grep -E -- '--profile|image rm test/profiled:local' "${test_output}/nuke.log" >/dev/null; then
    echo "Compose nuke helper changed cleanup without an explicit profile." >&2
    exit 1
fi

#
# Include the selected profile in every Compose operation with either frontend
# and with either explicit or environment-derived project selection.
#
for compose_mode in plugin standalone; do
    for project_selection in named environment; do
        profile_log="${test_output}/profile-${compose_mode}-${project_selection}.log"
        : >"${profile_log}"
        set -- \
            --docker-bin "${stub_path}" \
            --compose-bin "${stub_path}" \
            --compose-mode "${compose_mode}" \
            --compose-file "${test_output}/compose-file.yml" \
            --env-file "${test_output}/project.env" \
            --profile test \
            --down-timeout 45
        compose_prefix=""

        if [ "${compose_mode}" = "plugin" ]; then
            compose_prefix="compose "
        fi

        if [ "${project_selection}" = "named" ]; then
            set -- "$@" --project-name test-project
            compose_prefix="${compose_prefix}--project-name test-project "
        fi

        compose_prefix="${compose_prefix}--env-file ${test_output}/project.env --file ${test_output}/compose-file.yml --profile test"
        NUKE_STUB_LOG="${profile_log}" NUKE_STUB_REQUIRE_PROFILE=true \
            sh scripts/compose/nuke.sh "$@" \
                >"${test_output}/profile-${compose_mode}-${project_selection}.out" 2>&1

        grep -F -x -- "${compose_prefix} config --quiet" "${profile_log}" >/dev/null
        grep -F -x -- "${compose_prefix} config --images" "${profile_log}" >/dev/null
        grep -F -x -- "${compose_prefix} down --timeout 45 --volumes --remove-orphans --rmi all" \
            "${profile_log}" >/dev/null
        grep -F -x 'image rm test/profiled:local' "${profile_log}" >/dev/null
    done

done

#
# Stop after an unexpected Compose failure without removing images or builders.
#
: >"${test_output}/failure.log"
if NUKE_STUB_LOG="${test_output}/failure.log" NUKE_STUB_FAIL_COMPOSE=down \
    sh scripts/compose/nuke.sh \
        --docker-bin "${stub_path}" \
        --compose-mode plugin \
        --compose-file "${test_output}/compose-file.yml" \
        --env-file "${test_output}/project.env" \
        --project-name test-project \
        --profile test \
        --down-timeout 45 \
        --builder-name test-builder \
        >"${test_output}/failure.out" 2>&1; then
    echo "Compose nuke helper hid an unexpected teardown failure." >&2
    exit 1
fi
grep -F 'Docker Compose could not remove test-project.' \
    "${test_output}/failure.out" >/dev/null
if grep -E 'image rm|buildx rm' "${test_output}/failure.log" >/dev/null; then
    echo "Compose nuke helper continued after a teardown failure." >&2
    exit 1
fi

#
# Preserve ordered Compose layers and each argument boundary through both command forms.
#
mkdir -p "${test_output}/layered checkout"
: >"${test_output}/layered checkout/base.yml"
: >"${test_output}/layered checkout/build.yml"
: >"${test_output}/layered checkout/test.yml"

for compose_mode in plugin standalone; do
    layer_log="${test_output}/layers-${compose_mode}.log"
    argument_log="${test_output}/arguments-${compose_mode}.log"
    : >"${layer_log}"
    : >"${argument_log}"
    NUKE_STUB_LOG="${layer_log}" NUKE_STUB_ARGUMENT_LOG="${argument_log}" \
        sh scripts/compose/nuke.sh \
            --docker-bin "${stub_path}" --compose-bin "${stub_path}" \
            --compose-mode "${compose_mode}" \
            --compose-file "${test_output}/layered checkout/base.yml" \
            --compose-file "${test_output}/layered checkout/build.yml" \
            --compose-file "${test_output}/layered checkout/test.yml" \
            --env-file "${test_output}/project.env" --down-timeout 45 \
            >"${test_output}/layers-${compose_mode}.out" 2>&1
    layers="--file ${test_output}/layered checkout/base.yml --file ${test_output}/layered checkout/build.yml --file ${test_output}/layered checkout/test.yml"

    for operation in 'config --quiet' 'config --images' 'ps --all --quiet' 'down --timeout 45 --volumes --remove-orphans --rmi all'; do
        grep -F -- "${layers} ${operation}" "${layer_log}" >/dev/null
    done

    # A flattened command log alone would hide accidental word splitting of these paths.
    for layer in base build test; do
        test "$(grep -F -x -c "<${test_output}/layered checkout/${layer}.yml>" "${argument_log}")" -eq 4
    done

done

#
# Reject malformed repeated list arguments and nonexistent extra layers before any Docker call.
#
for option in --compose-file --dockerfile --additional-image; do
    for invalid_kind in empty newline carriage-return; do
        invalid_value=""

        case "${invalid_kind}" in
            newline) invalid_value=$(printf 'first\nsecond') ;;
            carriage-return) invalid_value=$(printf 'first\rsecond') ;;
        esac

        invalid_log="${test_output}/invalid-${option#--}-${invalid_kind}.log"
        : >"${invalid_log}"

        if NUKE_STUB_LOG="${invalid_log}" sh scripts/compose/nuke.sh \
            --docker-bin "${stub_path}" --compose-mode plugin \
            --compose-file "${test_output}/compose-file.yml" \
            --env-file "${test_output}/project.env" --down-timeout 45 \
            "${option}" "${invalid_value}" \
            >"${test_output}/invalid.out" 2>&1; then
            echo "Cleanup accepted malformed ${option} (${invalid_kind})." >&2
            exit 1
        fi

        test ! -s "${invalid_log}"
        grep -F -- 'must be non-empty and contain no line breaks.' "${test_output}/invalid.out" >/dev/null
    done

done

: >"${test_output}/missing-layer.log"
if NUKE_STUB_LOG="${test_output}/missing-layer.log" sh scripts/compose/nuke.sh \
    --docker-bin "${stub_path}" --compose-mode plugin \
    --compose-file "${test_output}/compose-file.yml" \
    --compose-file "${test_output}/not-present.yml" \
    --env-file "${test_output}/project.env" --down-timeout 45 \
    >"${test_output}/missing-layer.out" 2>&1; then
    echo "Cleanup accepted a nonexistent additional Compose layer." >&2
    exit 1
fi
test ! -s "${test_output}/missing-layer.log"

#
# Remove the actual published image reference even when the current model selects a local build.
#
: >"${test_output}/runtime-image.log"
NUKE_STUB_LOG="${test_output}/runtime-image.log" \
    NUKE_STUB_MODEL_IMAGE=privateerr:local \
    NUKE_STUB_RUNTIME_IMAGE=ghcr.io/scottgigawatt/privateerr:latest \
    sh scripts/compose/nuke.sh \
        --docker-bin "${stub_path}" --compose-mode plugin \
        --compose-file "${test_output}/compose-file.yml" \
        --env-file "${test_output}/project.env" --down-timeout 45 \
        >"${test_output}/runtime-image.out" 2>&1
for image in privateerr:local ghcr.io/scottgigawatt/privateerr:latest; do
    test "$(grep -F -x -c "image rm ${image}" "${test_output}/runtime-image.log")" -eq 1
done
awk '
    /container inspect/ { inspected = NR }
    / down --timeout / { if (!inspected || inspected >= NR) exit 1; removed = NR }
    /^image rm / { if (!removed || removed >= NR) exit 1 }
' "${test_output}/runtime-image.log"

#
# Discovery failures and invalid inspect output must never reach teardown or image removal.
#
for discovery_failure in images ps inspect invalid-container invalid-image short-image-id full-image-id; do
    discovery_log="${test_output}/discovery-${discovery_failure}.log"
    : >"${discovery_log}"
    failure_mode="${discovery_failure}"
    container_id=0123456789ab
    runtime_image=ghcr.io/scottgigawatt/privateerr:latest

    case "${discovery_failure}" in
        invalid-container) failure_mode=""; container_id=not-a-container ;;
        invalid-image) failure_mode=""; runtime_image=sha256:0123456789abcdef ;;
        short-image-id) failure_mode=""; runtime_image=0123456789ab ;;
        full-image-id) failure_mode=""; runtime_image=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef ;;
    esac

    if NUKE_STUB_LOG="${discovery_log}" \
        NUKE_STUB_FAIL_DISCOVERY="${failure_mode}" \
        NUKE_STUB_CONTAINER_ID="${container_id}" NUKE_STUB_RUNTIME_IMAGE="${runtime_image}" \
        sh scripts/compose/nuke.sh \
            --docker-bin "${stub_path}" --compose-mode plugin \
            --compose-file "${test_output}/compose-file.yml" \
            --env-file "${test_output}/project.env" --down-timeout 45 \
            >"${test_output}/discovery-${discovery_failure}.out" 2>&1; then
        echo "Cleanup continued with failed or invalid discovery: ${discovery_failure}." >&2
        exit 1
    fi

    if grep -E ' down --timeout |image rm|buildx rm' "${discovery_log}" >/dev/null; then
        echo "Cleanup mutated Docker resources after incomplete image discovery." >&2
        exit 1
    fi

done

#
# Docker may retain a shared service image; report the failure without forcing or pruning it.
#
: >"${test_output}/shared-image.log"
if NUKE_STUB_LOG="${test_output}/shared-image.log" \
    NUKE_STUB_RUNTIME_IMAGE=ghcr.io/scottgigawatt/privateerr:latest \
    NUKE_STUB_SHARED_IMAGE=ghcr.io/scottgigawatt/privateerr:latest \
    sh scripts/compose/nuke.sh \
        --docker-bin "${stub_path}" --compose-mode plugin \
        --compose-file "${test_output}/compose-file.yml" \
        --env-file "${test_output}/project.env" --down-timeout 45 \
        --builder-name test-builder >"${test_output}/shared-image.out" 2>&1; then
    echo "Cleanup hid Docker's refusal to remove a shared service image." >&2
    exit 1
fi
grep -F 'Could not remove project image reference: ghcr.io/scottgigawatt/privateerr:latest' \
    "${test_output}/shared-image.out" >/dev/null
if grep -E 'image rm (--force|-f)|prune|buildx rm' "${test_output}/shared-image.log" >/dev/null; then
    echo "Cleanup forced shared-image removal or continued after its failure." >&2
    exit 1
fi

echo "Compose nuke helper tests passed."
