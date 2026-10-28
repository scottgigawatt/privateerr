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
ARG ALPINE_TAG=3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

#
# Stage 1 of 6: Obtain a static ShellCheck binary for every supported CPU.
# The official image includes ARMv6, which also runs on ARMv7 where Alpine lacks the package.
#
FROM koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d AS shellcheck

#
# Stage 2 of 6: Obtain the current Docker client without a daemon or extra plugins.
# Alpine's packaged client lags behind upstream security releases.
#
FROM docker:29.9.2-cli@sha256:5e6baf67325a79f64ed3bed6863954d5e05d0f3d4e57cbdb14809346814bbfdb AS docker-cli

#
# Stage 3 of 6: Obtain the reviewed official Compose binary for every supported CPU.
# Keep official tooling intact rather than rebuilding its dependency graph.
#
FROM docker/compose-bin:v5.6.1@sha256:2aeaeedd4f2d8e2dcb399b2b9723bfaeb6714140cb0657897f5865960f1624ae AS compose

#
# Stage 4 of 6: Keep all validation tools in the test-only Buccaneerr image.
#
FROM alpine:${ALPINE_TAG} AS tools

#
# Re-declare the Alpine tag after FROM so labels can record the base image.
#
ARG ALPINE_TAG=3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

#
# Default install locations and image metadata.
#
ARG BUCCANEERR_BIN_HOME=/buccaneerr
ARG IMAGE_CREATED=unknown
ARG IMAGE_REVISION=unknown
ARG IMAGE_VERSION=latest

#
# Set the Buccaneerr script location.
#
ENV BUCCANEERR_BIN_HOME=${BUCCANEERR_BIN_HOME} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=${BUCCANEERR_BIN_HOME}/runtime \
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
# Refresh the patched Python interpreter and validation tools from stable Alpine.
# BusyBox supplies portable AWK and core utilities; Python checker versions are
# locked separately so linting and documentation use the same current Ruff release.
#
RUN apk upgrade --no-cache && \
    apk add --no-cache \
        actionlint \
        bash \
        ca-certificates \
        curl \
        git \
        make \
        grep \
        jq \
        iptables \
        nodejs \
        python3

#
# Copy the Python tool dependency lock for hash-verified installation.
#
COPY test/requirements-tools.txt /tmp/requirements-tools.txt

#
# Install pre-commit, virtualenv, and Ruff in an isolated, hash-verified environment.
# The complete lockfile verifies every dependency and keeps these tools test-only.
# Keep only active upstream seed wheels and remove temporary bootstrap packages together.
#
RUN apk add --no-cache --virtual .python-build-deps py3-pip && \
    python3 -m venv /opt/precommit && \
    /opt/precommit/bin/python -m pip install --no-cache-dir --disable-pip-version-check \
        --require-hashes --requirement /tmp/requirements-tools.txt && \
    /opt/precommit/bin/python -m pip uninstall --yes pip && \
    /opt/precommit/bin/python -c 'import sys; from virtualenv.seed.wheels import embed; version = ".".join(map(str, sys.version_info[:2])); active = embed.BUNDLE_SUPPORT[version]; [embed.get_embed_wheel(package, version) for package in active]; [wheel.unlink() for wheel in embed.BUNDLE_FOLDER.glob("*.whl") if wheel.name not in active.values()]' && \
    apk del .python-build-deps && \
    rm /tmp/requirements-tools.txt

#
# Make the isolated Python checkers available to repository checks.
#
ENV PATH="/opt/precommit/bin:${PATH}"

#
# Copy tool binaries from digest-pinned upstream images.
#
COPY --from=shellcheck /bin/shellcheck /usr/local/bin/shellcheck
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=compose /docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

#
# Copy npm dependency manifests for integrity-verified installation.
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
# Copy the project license, Python validator, and developer checks into Buccaneerr.
#
COPY test/LICENSE    /LICENSE
COPY test/checks.sh  ${BUCCANEERR_BIN_HOME}/checks.sh
COPY test/helpers    ${BUCCANEERR_BIN_HOME}/helpers
COPY test/policy     ${BUCCANEERR_BIN_HOME}/policy
COPY test/stubs      ${BUCCANEERR_BIN_HOME}/stubs
COPY test/examples   ${BUCCANEERR_BIN_HOME}/examples
COPY test/unit       ${BUCCANEERR_BIN_HOME}/unit
COPY test/runtime    ${BUCCANEERR_BIN_HOME}/runtime

#
# Run the Python validator directly so it owns preflight, logging, and fault cleanup.
#
CMD ["python3", "-m", "validate_stack"]

#
# Stage 5 of 6: Extend Buccaneerr with the locked developer documentation toolchain.
# This optional target keeps documentation packages out of ordinary test and production images.
#
FROM tools AS docs

#
# Install documentation tools in an isolated environment without changing Alpine's Python packages.
#
RUN apk add --no-cache --virtual .docs-build-deps py3-pip && \
    python3 -m venv /opt/docs && \
    apk del .docs-build-deps

#
# Copy the locked documentation toolchain manifest into the test image.
#
COPY requirements-docs.txt /tmp/requirements-docs.txt

#
# Install the locked documentation toolchain in an isolated environment.
#
RUN /opt/docs/bin/python -m pip install --no-cache-dir --disable-pip-version-check \
    --require-hashes --requirement /tmp/requirements-docs.txt && \
    rm /tmp/requirements-docs.txt

#
# Use the documentation environment for site builds and API rendering.
#
ENV PATH="/opt/docs/bin:${PATH}"

#
# Stage 6 of 6: Publish the ordinary Buccaneerr tools without optional documentation dependencies.
# Keeping this stage last preserves the default image built by Compose and release workflows.
#
FROM tools AS buccaneerr
