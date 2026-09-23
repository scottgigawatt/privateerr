#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# build.sh: Build and preview developer documentation using Buccaneerr's docs target.
#
# Usage: scripts/docs/build.sh install|build|serve
#
# Keep tools in the container, mount sources read-only, and publish only the generated site.
#

#
# Stop at failed builds and reject unset variables.
#
set -eu

#
# Resolve source paths independently of the caller's working directory.
#
repository_root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
: "${DOCKER_BIN:=docker}"
: "${DOCS_IMAGE:=privateerr-buccaneerr:docs}"
: "${DOCS_SITE_PATH:=site}"
: "${DOCS_SERVE_ADDRESS:=127.0.0.1:8000}"

#
# Build the optional toolchain without running the application or reading deployment credentials.
#
if [ "${1:-}" = install ]; then
    exec "${DOCKER_BIN}" build --target docs --tag "${DOCS_IMAGE}" \
        --file "${repository_root}/test/Dockerfile" "${repository_root}"
fi

#
# Run as the host user so generated artifacts remain writable on Linux runners.
#
set -- "${1:-}" --rm --init --read-only --cap-drop ALL \
    --security-opt no-new-privileges:true --tmpfs /tmp \
    --user "$(id -u):$(id -g)" \
    --volume "${repository_root}:/workspace:ro" --workdir /workspace \
    --env HOME=/tmp --env PYTHONDONTWRITEBYTECODE=1
mode=$1
shift

#
# Permit writes only to the requested output directory or disposable preview storage.
#
case "${mode}" in
    build)
        # Resolve the output directory before mounting it independently from read-only source.
        mkdir -p "${DOCS_SITE_PATH}"
        site_path=$(CDPATH='' cd -- "${DOCS_SITE_PATH}" && pwd)
        exec "${DOCKER_BIN}" run "$@" --network none \
            --volume "${site_path}:/site" \
            --entrypoint mkdocs "${DOCS_IMAGE}" build --strict --clean --site-dir /site
        ;;
    serve)
        exec "${DOCKER_BIN}" run "$@" --publish "${DOCS_SERVE_ADDRESS}:8000" \
            --entrypoint mkdocs "${DOCS_IMAGE}" serve --strict --dev-addr 0.0.0.0:8000
        ;;
    *)
        printf '%s\n' 'Usage: scripts/docs/build.sh install|build|serve' >&2
        exit 2
        ;;
esac
