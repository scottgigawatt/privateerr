#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test-dockerfile-base-images.sh: Validate portable Dockerfile base-image
#                                 discovery without contacting Docker.
#
# Usage: test/helpers/test-dockerfile-base-images.sh
#

#
# Directory for isolated parser fixtures.
#
test_output=""

#
# Fail on errors and unset variables.
#
set -eu

#
# cleanup: Remove the isolated parser-test directory.
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
# Create isolated Dockerfile fixtures and register cleanup on exit.
#
test_output=$(mktemp -d)
trap cleanup 0 1 2 15

printf '%s\n' \
    '# Global defaults may be referenced by FROM.' \
    '  arg BASE_IMAGE=example.invalid/base@sha256:abc=def  ' \
    'ARG BUILDPLATFORM=linux/amd64' \
    "  from --platform=\${BUILDPLATFORM} \${BASE_IMAGE} AS Build  " \
    'ARG STAGE_ONLY=example.invalid/not-a-base:latest' \
    'FROM build AS final' \
    'FROM scratch' \
    "FROM \${UNRESOLVED_IMAGE}" \
    >"${test_output}/Dockerfile.one"

printf '%s\n' \
    'ARG BASE_IMAGE=alpine:3.24' \
    "FROM \$BASE_IMAGE AS base" \
    'FROM BASE' \
    'FROM alpine:3.24' \
    'FROM busybox:1.37' \
    >"${test_output}/Dockerfile.two"

printf '%s\n' \
    'example.invalid/base@sha256:abc=def' \
    'alpine:3.24' \
    'busybox:1.37' \
    >"${test_output}/base-images.expected"

awk -f scripts/awk/collect-dockerfile-base-images.awk \
    "${test_output}/Dockerfile.one" \
    "${test_output}/Dockerfile.two" \
    >"${test_output}/base-images.actual"

cmp "${test_output}/base-images.expected" "${test_output}/base-images.actual"

echo "Dockerfile base-image tests passed."
