#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# Dockerfile: Test-only Buccaneerr image for validating Privateerr, Gluetun, and PIA port forwarding.
#

#
# Default Alpine image tag that can be overridden using build args.
#
ARG ALPINE_TAG=3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

#
# Stage 1 of 6: Obtain the same static ShellCheck binary for every supported CPU.
# The official image includes ARMv6, which also runs on ARMv7 where Alpine lacks the package.
#
FROM koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d AS shellcheck

#
# Stage 2 of 6: Obtain the current Docker client without a daemon or extra plugins.
# Alpine's packaged client lags behind upstream security releases.
#
FROM docker:29.9.0-cli@sha256:1a4c7cb63513f349bdad01fcc6e0f3f2f67d37b9da86f14dc0d4a0942eecda00 AS docker-cli

#
# Stage 3 of 6: Rebuild Compose and actionlint with fixed Go libraries.
# Build tools stay separate from the published test image and production runtime.
#
FROM --platform=$BUILDPLATFORM golang:1.27.2-alpine3.24@sha256:85dc1069ac644ea3c527b177303a406eb3358192816cd7f9e5848eb658851673 AS compose

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG DOCKER_COMPOSE_VERSION=v5.6.0
ARG GO_X_NET_VERSION=v0.60.0
ARG ACTIONLINT_VERSION=v1.7.12
ARG GO_X_SYS_VERSION=v0.49.0
ENV GOTOOLCHAIN=local CGO_ENABLED=0
SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# Download checksum-verified upstream module sources, retaining the release behavior.
# Override only the networking dependency until upstream publishes its security refresh.
WORKDIR /src
RUN go mod download "github.com/docker/compose/v5@${DOCKER_COMPOSE_VERSION}" && \
    cp -a "$(go env GOMODCACHE)/github.com/docker/compose/v5@${DOCKER_COMPOSE_VERSION}/." /src && \
    chmod -R u+w /src && \
    current_net=$(go list -m -f '{{.Version}}' golang.org/x/net) && \
    if [ "$(printf '%s\n' "${current_net}" "${GO_X_NET_VERSION}" | sort -V | head -n 1)" != "${GO_X_NET_VERSION}" ]; then \
        go get "golang.org/x/net@${GO_X_NET_VERSION}"; \
    fi && \
    go mod verify && \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT#v} \
    go build -mod=readonly -trimpath -tags=e2e \
        -ldflags="-w -X github.com/docker/compose/v5/internal.Version=${DOCKER_COMPOSE_VERSION}" \
        -o /docker-compose ./cmd

# Rebuild the reviewed workflow checker with the same fixed Go runtime.
# Its Windows-only syscall advisory is also absent after the module refresh.
WORKDIR /actionlint-src
RUN go mod download "github.com/rhysd/actionlint@${ACTIONLINT_VERSION}" && \
    cp -a "$(go env GOMODCACHE)/github.com/rhysd/actionlint@${ACTIONLINT_VERSION}/." /actionlint-src && \
    chmod -R u+w /actionlint-src && \
    current_net=$(go list -m -f '{{.Version}}' golang.org/x/net) && \
    if [ "$(printf '%s\n' "${current_net}" "${GO_X_NET_VERSION}" | sort -V | head -n 1)" != "${GO_X_NET_VERSION}" ]; then \
        go get "golang.org/x/net@${GO_X_NET_VERSION}"; \
    fi && \
    current_sys=$(go list -m -f '{{.Version}}' golang.org/x/sys) && \
    if [ "$(printf '%s\n' "${current_sys}" "${GO_X_SYS_VERSION}" | sort -V | head -n 1)" != "${GO_X_SYS_VERSION}" ]; then \
        go get "golang.org/x/sys@${GO_X_SYS_VERSION}"; \
    fi && \
    go mod verify && \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT#v} \
    go build -mod=readonly -trimpath \
        -ldflags="-w -X github.com/rhysd/actionlint.version=${ACTIONLINT_VERSION}" \
        -o /actionlint ./cmd/actionlint

#
# Stage 4 of 6: Keep all validation tools in the test-only Buccaneerr image.
#
FROM alpine:${ALPINE_TAG} AS tools

#
# Re-declare the Alpine tag after FROM so labels can record the base image.
#
ARG ALPINE_TAG=3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

#
# Default install locations, fixed package floors, and image metadata.
#
ARG BUCCANEERR_BIN_HOME=/buccaneerr
ARG EDGE_APK_REPOSITORY=https://dl-cdn.alpinelinux.org/alpine/edge/main
ARG SETUPTOOLS_APK_MIN_VERSION=83.0.0-r0
ARG LIBEXPAT_APK_MIN_VERSION=2.9.0-r0
ARG ZLIB_APK_MIN_VERSION=1.3.2-r1
ARG IMAGE_CREATED=unknown
ARG IMAGE_REVISION=unknown
ARG IMAGE_VERSION=latest

#
# Set the Buccaneerr script location.
#
ENV BUCCANEERR_BIN_HOME=${BUCCANEERR_BIN_HOME} \
    PYTHONDONTWRITEBYTECODE=1 \
    RUFF_NO_CACHE=true

#
# Add Open Container Initiative image labels. These support container registry
# metadata, source links, and license display.
#
LABEL org.opencontainers.image.title="Buccaneerr" \
        org.opencontainers.image.description="Test-only Buccaneerr validator for Privateerr, Gluetun WireGuard, and PIA port-forwarding e2e checks." \
        org.opencontainers.image.url="https://github.com/scottgigawatt/privateerr" \
        org.opencontainers.image.documentation="https://github.com/scottgigawatt/privateerr#readme" \
        org.opencontainers.image.source="https://github.com/scottgigawatt/privateerr" \
        org.opencontainers.image.vendor="Scott Gigawatt" \
        org.opencontainers.image.licenses="Apache-2.0" \
        org.opencontainers.image.created="${IMAGE_CREATED}" \
        org.opencontainers.image.revision="${IMAGE_REVISION}" \
        org.opencontainers.image.version="${IMAGE_VERSION}" \
        org.opencontainers.image.base.name="docker.io/library/alpine:${ALPINE_TAG}"

#
# Upgrade the base OpenSSL runtime libraries to Alpine's current fixed release,
# then install validation tools. These stay out of the production image.
# Use only fixed setuptools and libexpat from edge until stable includes their security updates.
# Retain the tagged repository so later APK operations can resolve libexpat.
# The zlib floor rejects the older vulnerable stable revision.
# BusyBox supplies the portable AWK and core utilities used by the tests.
#
RUN apk upgrade --no-cache libcrypto3 libssl3 && \
    apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        git \
        make \
        grep \
        jq \
        iptables \
        python3 \
        py3-pip \
        ruff \
        nodejs \
        "zlib>=${ZLIB_APK_MIN_VERSION}" && \
    apk add --no-cache \
        --repository="${EDGE_APK_REPOSITORY}" \
        "py3-setuptools>=${SETUPTOOLS_APK_MIN_VERSION}" && \
    printf '%s\n' "@expatfix ${EDGE_APK_REPOSITORY}" >> /etc/apk/repositories && \
    apk add --no-cache "libexpat@expatfix>=${LIBEXPAT_APK_MIN_VERSION}"

# Install pre-commit with fixed virtualenv outside Alpine's older Python tool packages.
# The complete lockfile verifies every dependency and keeps these tools test-only.
# Keep only seed wheels for the installed Python, preserving their upstream hash checks.
COPY test/requirements-tools.txt /tmp/requirements-tools.txt
RUN python3 -m venv /opt/precommit && \
    /opt/precommit/bin/python -m pip install --no-cache-dir --disable-pip-version-check \
        --require-hashes --requirement /tmp/requirements-tools.txt && \
    /opt/precommit/bin/python -m pip uninstall --yes pip && \
    /opt/precommit/bin/python -c 'import sys; from virtualenv.seed.wheels import embed; version = ".".join(map(str, sys.version_info[:2])); active = embed.BUNDLE_SUPPORT[version]; [embed.get_embed_wheel(package, version) for package in active]; [wheel.unlink() for wheel in embed.BUNDLE_FOLDER.glob("*.whl") if wheel.name not in active.values()]' && \
    apk del py3-pip && \
    rm /tmp/requirements-tools.txt
ENV PATH="/opt/precommit/bin:${PATH}"

COPY --from=shellcheck /bin/shellcheck /usr/local/bin/shellcheck
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=compose /docker-compose /usr/local/lib/docker/cli-plugins/docker-compose
COPY --from=compose /actionlint /usr/bin/actionlint

# Retain upstream license and notice files for rebuilt third-party tools.
COPY --from=compose /src/LICENSE /licenses/docker-compose/LICENSE
COPY --from=compose /src/NOTICE /licenses/docker-compose/NOTICE
COPY --from=compose /actionlint-src/LICENSE.txt /licenses/actionlint/LICENSE.txt

#
# Copy the integrity-checked dependency manifests for the test tools.
#
COPY test/package.json test/package-lock.json /opt/tools/

#
# Install the locked checkers with a temporary package manager. Removing npm in
# the same layer keeps its bundled dependencies out of the published image.
#
RUN apk add --no-cache --virtual .node-build-deps npm && \
    npm ci --prefix /opt/tools --omit=dev --ignore-scripts && \
    apk del .node-build-deps && \
    rm -rf /root/.npm

#
# Use the locked spelling, typing, and Markdown commands throughout the test image.
#
ENV PATH="/opt/tools/node_modules/.bin:${PATH}"

#
# Copy over the project license and Buccaneerr script, then make the script executable.
#
COPY test/LICENSE                  /LICENSE
COPY test/buccaneerr-entrypoint.sh ${BUCCANEERR_BIN_HOME}/buccaneerr-entrypoint.sh
COPY test/checks.sh                ${BUCCANEERR_BIN_HOME}/checks.sh
COPY test/helpers                  ${BUCCANEERR_BIN_HOME}/helpers
COPY test/policy                   ${BUCCANEERR_BIN_HOME}/policy
COPY test/stubs                    ${BUCCANEERR_BIN_HOME}/stubs
COPY test/examples                 ${BUCCANEERR_BIN_HOME}/examples
COPY test/unit                     ${BUCCANEERR_BIN_HOME}/unit
COPY test/runtime                  ${BUCCANEERR_BIN_HOME}/runtime

#
# Make the Buccaneerr entrypoint script executable.
#
RUN chmod +x "${BUCCANEERR_BIN_HOME}/buccaneerr-entrypoint.sh"

#
# Run Buccaneerr.
#
CMD [ "bash", "-lc", "${BUCCANEERR_BIN_HOME}/buccaneerr-entrypoint.sh" ]

#
# Stage 5 of 6: Extend Buccaneerr with the locked developer documentation toolchain.
# This optional target keeps documentation packages out of ordinary test and production images.
#
FROM tools AS docs

# Install documentation tools in an isolated environment without changing Alpine's Python packages.
RUN apk add --no-cache py3-pip && python3 -m venv /opt/docs
COPY requirements-docs.txt /tmp/requirements-docs.txt
RUN /opt/docs/bin/python -m pip install --no-cache-dir --disable-pip-version-check \
    --require-hashes --requirement /tmp/requirements-docs.txt && \
    rm /tmp/requirements-docs.txt
ENV PATH="/opt/docs/bin:${PATH}"

#
# Stage 6 of 6: Publish the ordinary Buccaneerr tools without optional documentation dependencies.
# Keeping this stage last preserves the default image built by Compose and release workflows.
#
FROM tools AS buccaneerr
