#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test-make-helpers.sh: Validate Make's AWK, backup, credential, and Compose
#                       status helpers without mutating a deployment.
#
# Usage: test/helpers/test-make-helpers.sh
#

#
# Directory for test output.
#
test_output=""

#
# Fail on errors and unset variables.
#
set -eu

#
# cleanup: Remove the isolated helper-test directory.
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
# Create a temporary directory for test output and register cleanup on exit.
#
test_output=$(mktemp -d)
trap cleanup 0 1 2 15

#
# Preserve resolved Compose values while restoring selected environment order.
#
printf '%s\n' \
    'THIRD=resolved-third' \
    'FIRST=resolved-first' \
    'IGNORED=resolved-ignored' \
    'SECOND=resolved-second' \
    >"${test_output}/resolved.env"
printf '%s\n' \
    '# Selected environment order.' \
    'FIRST=generated-first' \
    'SECOND=generated-second' \
    'THIRD=generated-third' \
    >"${test_output}/selected.env"
printf '%s\n' \
    'FIRST=resolved-first' \
    'SECOND=resolved-second' \
    'THIRD=resolved-third' \
    >"${test_output}/ordered.expected"

awk -F = -f scripts/awk/order-environment.awk \
    - "${test_output}/selected.env" \
    <"${test_output}/resolved.env" \
    >"${test_output}/ordered.actual"
cmp "${test_output}/ordered.expected" "${test_output}/ordered.actual"

#
# Resolve Dockerfile ARG defaults used by base-image instructions.
#
printf '%s\n' \
    'ARG ALPINE_IMAGE=alpine:3.23.3' \
    "FROM \${ALPINE_IMAGE}" \
    'FROM scratch' \
    >"${test_output}/Dockerfile"
printf '%s\n' \
    'alpine:3.23.3' \
    >"${test_output}/base-images.expected"

awk -f scripts/awk/collect-dockerfile-base-images.awk \
    "${test_output}/Dockerfile" \
    >"${test_output}/base-images.actual"
cmp "${test_output}/base-images.expected" "${test_output}/base-images.actual"

#
# Share one raw-output filter for Compose and environment configuration.
#
printf '%s\n' \
    '# Full-line comment.' \
    'services:  ' \
    '  privateerr:  # Inline guidance.' \
    '' \
    'IMAGE_TAG=latest  # Generated default.' \
    >"${test_output}/commented.conf"
printf '%s\n' \
    'services:' \
    '  privateerr:' \
    'IMAGE_TAG=latest' \
    >"${test_output}/stripped.expected"

make --no-print-directory print-config \
    COMPOSE_FILE="${test_output}/commented.conf" \
    >"${test_output}/stripped-config.actual"
make --no-print-directory print-env \
    ENV_FILE="${test_output}/commented.conf" \
    COMPOSE_ENV_FILE="${test_output}/commented.conf" \
    >"${test_output}/stripped-env.actual"
cmp "${test_output}/stripped.expected" "${test_output}/stripped-config.actual"
cmp "${test_output}/stripped.expected" "${test_output}/stripped-env.actual"

#
# Archive a complete config tree through Make without overwriting backups.
#
mkdir -p "${test_output}/config/service"
printf '%s\n' 'preserved application state' \
    >"${test_output}/config/service/state.txt"

make --no-print-directory backup \
    CONFIG_PATH="${test_output}/config" \
    CONFIG_BACKUP_PATH="${test_output}/backups" \
    CONFIG_BACKUP_NAME=test \
    >"${test_output}/backup-first.out"
make --no-print-directory backup \
    CONFIG_PATH="${test_output}/config" \
    CONFIG_BACKUP_PATH="${test_output}/backups" \
    CONFIG_BACKUP_NAME=test \
    >"${test_output}/backup-second.out"

backup_count=$(find "${test_output}/backups" \
    -type f -name 'test-config-*.tar.gz' \
    | wc -l \
    | tr -d ' ')
test "${backup_count}" -eq 2
grep -F "Config cargo archived at ${test_output}/backups/test-config-" \
    "${test_output}/backup-first.out" >/dev/null
grep -F "Config cargo archived at ${test_output}/backups/test-config-" \
    "${test_output}/backup-second.out" >/dev/null

#
# Confirm every archive contains the original config state.
#
for archive in "${test_output}"/backups/test-config-*.tar.gz; do
    tar -tzf "${archive}" \
        | grep -F "${test_output#/}/config/service/state.txt" >/dev/null
done

#
# Reject a missing config directory without creating a backup destination.
#
if make --no-print-directory backup \
    CONFIG_PATH="${test_output}/missing-config" \
    CONFIG_BACKUP_PATH="${test_output}/missing-backups" \
    CONFIG_BACKUP_NAME=test \
    >"${test_output}/backup-missing.out" 2>&1; then
    echo "Config backup helper accepted a missing config directory." >&2
    exit 1
fi

grep -F "No ${test_output}/missing-config directory found to archive." \
    "${test_output}/backup-missing.out" >/dev/null
test ! -e "${test_output}/missing-backups"

#
# Accept resolved credentials without echoing either value.
#
credential_output=$(printf '%s\n' 'PIA_USER=p7654321' 'PIA_PASS=not-a-real-secret' \
    | scripts/compose/check-pia-credentials.sh)
test -z "${credential_output}"

#
# Reject missing values.
#
if printf '%s\n' 'PIA_USER=' 'PIA_PASS=not-a-real-secret' \
    | scripts/compose/check-pia-credentials.sh >"${test_output}/missing.out" 2>&1; then
    echo "Credential helper accepted a missing PIA username." >&2
    exit 1
fi

#
# Confirm the diagnostic identifies the problem and corrective action.
#
grep -F "This deployment cannot start without valid PIA credentials." \
    "${test_output}/missing.out" >/dev/null
grep -F "Credential  PIA_USER" \
    "${test_output}/missing.out" >/dev/null
grep -F "Problem     Missing or still using a known example value." \
    "${test_output}/missing.out" >/dev/null
grep -F "Fix         Set PIA_USER in the active deployment's .env file, then rerun the requested Make target." \
    "${test_output}/missing.out" >/dev/null

#
# Keep redirected diagnostic output free from terminal escape sequences.
#
if LC_ALL=C grep "$(printf '\033')" "${test_output}/missing.out" >/dev/null; then
    echo "Credential helper emitted terminal colors into redirected output." >&2
    exit 1
fi

#
# Reject both known example password values.
#
for example_password in abc123 shiverMeTimbers123; do
    if printf '%s\n' 'PIA_USER=p7654321' "PIA_PASS=${example_password}" \
        | scripts/compose/check-pia-credentials.sh \
            >"${test_output}/placeholder-${example_password}.out" 2>&1; then
        echo "Credential helper accepted a known example PIA password." >&2
        exit 1
    fi

    grep -F "Credential  PIA_PASS" \
        "${test_output}/placeholder-${example_password}.out" >/dev/null
done

#
# Confirm the status helper delegates project selection to Docker Compose.
#
: >"${test_output}/compose.yml"
: >"${test_output}/stack.env"
COMPOSE_TEST_LOG="${test_output}/docker.log" \
    scripts/compose/ps.sh \
        --docker-bin "$(pwd)/test/stubs/compose-docker-stub.sh" \
        --env-file "${test_output}/stack.env" \
        --compose-file "${test_output}/compose.yml" \
        >"${test_output}/ps.out"

#
# Confirm the status helper invokes Docker Compose with the expected arguments.
#
grep -F -- "compose --env-file ${test_output}/stack.env --file ${test_output}/compose.yml ps --format" \
    "${test_output}/docker.log" >/dev/null

#
# Confirm the status helper returns the expected Compose output.
#
grep -F "test-idle-latest" "${test_output}/ps.out" >/dev/null
grep -F "test-gluetun-latest" "${test_output}/ps.out" >/dev/null
grep -F "test-service-latest" "${test_output}/ps.out" >/dev/null

#
# Collapse duplicate wildcard bindings and stack each distinct published port.
#
test "$(grep -c 'test-gluetun-latest' "${test_output}/ps.out")" -eq 1
grep -E '^[[:space:]]+8080->8080/tcp$' \
    "${test_output}/ps.out" >/dev/null
grep -E '^[[:space:]]+6881->6881/udp$' \
    "${test_output}/ps.out" >/dev/null
grep -F "6881->6881/tcp" "${test_output}/ps.out" >/dev/null
grep -F "9696->9696/tcp" \
    "${test_output}/ps.out" >/dev/null

if grep -F '[::]' "${test_output}/ps.out" >/dev/null; then
    echo "Compose status helper retained a duplicate IPv6 wildcard binding." >&2
    exit 1
fi

#
# Keep clean non-destructive and keep destructive operations on explicit targets.
#
NO_COLOR=1 make --dry-run clean >"${test_output}/clean.out"
grep -F 'rm -rf .pytest_cache .ruff_cache test/logs' \
    "${test_output}/clean.out" >/dev/null
grep -F -- "-path './docker/pia-manual-connections'" \
    "${test_output}/clean.out" >/dev/null
grep -F -- "-name '.DS_Store'" "${test_output}/clean.out" >/dev/null
if grep -E '(^|[[:space:]])docker([[:space:]]|$)|\.env|wireguard|wg0\.conf|privateerr\.env' \
    "${test_output}/clean.out" >/dev/null; then
    echo "The clean target includes deployment or credential-bearing state." >&2
    exit 1
fi

#
# Keep ordinary down volume- and image-preserving.
#
NO_COLOR=1 make --dry-run down \
    DOCKER_COMPOSE=true \
    ENV_FILE=example.env \
    COMPOSE_ENV_FILE=example.env \
    >"${test_output}/down.out"
grep -F 'down --timeout 30 --remove-orphans' "${test_output}/down.out" >/dev/null
if grep -E 'down .*--volumes|down .*--rmi' "${test_output}/down.out" >/dev/null; then
    echo "The down target includes destructive volume or image options." >&2
    exit 1
fi

#
# Delegate destructive Docker cleanup while invoking clean and restore once.
#
NO_COLOR=1 make --dry-run nuke \
    DOCKER_COMPOSE=true \
    ENV_FILE=example.env \
    COMPOSE_ENV_FILE=example.env \
    >"${test_output}/nuke.out"
grep -F 'scripts/compose/nuke.sh' "${test_output}/nuke.out" >/dev/null
grep -F -- '--project-name "privateerr"' "${test_output}/nuke.out" >/dev/null
grep -F -- '--builder-name "privateerr-local"' "${test_output}/nuke.out" >/dev/null
test "$(grep -c 'make --no-print-directory clean' "${test_output}/nuke.out")" -eq 1
test "$(grep -c 'make --no-print-directory restore-test-config' "${test_output}/nuke.out")" -eq 1
if grep -E 'docker (system|image|volume|builder) prune|--all-inactive|rm --force.*(service|base)' \
    "${test_output}/nuke.out" >/dev/null; then
    echo "The nuke target contains global or forceful image cleanup." >&2
    exit 1
fi

#
# Keep both platform-build recipes composed entirely from overridable variables.
#
NO_COLOR=1 make --dry-run build-platforms \
    DOCKER_COMPOSE=true \
    DOCKER_BUILDX=privateerr-buildx \
    BUILDX_BUILDER_NAME=privateerr-test-builder \
    BUILDX_BUILD_OPTIONS=--test-build-option \
    BUILDX_PLATFORM_OPTIONS=--test-platform-option \
    BUILDX_PRIVATEERR_IMAGE_TAG=test/privateerr \
    BUILDX_BUCCANEERR_IMAGE_TAG=test/buccaneerr \
    PRIVATEERR_DOCKERFILE=test-privateerr.Dockerfile \
    PRIVATEERR_BUILD_CONTEXT=test-privateerr-context \
    BUCCANEERR_DOCKERFILE=test-buccaneerr.Dockerfile \
    BUCCANEERR_BUILD_CONTEXT=test-buccaneerr-context \
    >"${test_output}/build-platforms.out"

grep -F 'privateerr-buildx build --builder "privateerr-test-builder" --test-build-option --test-platform-option --tag "test/privateerr" --file "test-privateerr.Dockerfile" "test-privateerr-context"' \
    "${test_output}/build-platforms.out" >/dev/null
grep -F 'privateerr-buildx build --builder "privateerr-test-builder" --test-build-option --test-platform-option --tag "test/buccaneerr" --file "test-buccaneerr.Dockerfile" "test-buccaneerr-context"' \
    "${test_output}/build-platforms.out" >/dev/null

#
# Redirected help stays color-free and marks the destructive nuke target.
#
NO_COLOR=1 make help >"${test_output}/help.out"
grep -F '‼️ DANGER ‼️' "${test_output}/help.out" >/dev/null
if LC_ALL=C grep "$(printf '\033')" "${test_output}/help.out" >/dev/null; then
    echo "Make help emitted terminal colors into redirected output." >&2
    exit 1
fi

#
# Keep shared target groups and framed dependency comments reviewable.
#
common_targets=$(awk '
    /^COMMON_TARGETS=/ { active = 1 }
    active && match($0, /\$\([A-Z0-9_]+\)/) {
        if (targets != "") {
            targets = targets " "
        }
        targets = targets substr($0, RSTART + 2, RLENGTH - 3)
    }
    active && $0 !~ /\\$/ {
        print targets
        exit
    }
' Makefile)
test "${common_targets}" = "BUILD_DEPENDS CHECK_ENV CHECK_PIA ALL UP DOWN PS LOGS CONFIG ENV PRINT_CONFIG PRINT_ENV BUILD BUILD_PLATFORMS TEST TEST_MAKE_HELPERS TEST_WORKFLOWS TEST_E2E BACKUP RESTORE_TEST_CONFIG CLEAN_TEST CLEAN NUKE HELP"
common_recipe_order=$(awk '
    /^\$\([A-Z0-9_]+\)(:| )/ {
        target = $0
        sub(/^\$\(/, "", target)
        sub(/\).*/, "", target)
        if (targets != "") {
            targets = targets " "
        }
        targets = targets target
        if (++count == 24) {
            print targets
            exit
        }
    }
' Makefile)
test "${common_recipe_order}" = "${common_targets}"
grep -F ".DEFAULT_GOAL := \$(ALL)" Makefile >/dev/null
for target_group in COMMON_TARGETS PROJECT_TARGETS INTERNAL_TARGETS ALIAS_TARGETS; do
    grep -F "${target_group}=" Makefile >/dev/null
done

missing_dependency_comments=$(awk '
    /^# \$\(/ { target = $0; dependencies = 0; active = 1; next }
    active && /^# Dependencies/ { dependencies = 1 }
    active && /^\$\(/ {
        if (!dependencies) {
            print target
        }
        active = 0
    }
' Makefile)
test -z "${missing_dependency_comments}"

#
# Report success.
#
echo "Make helper tests passed."
