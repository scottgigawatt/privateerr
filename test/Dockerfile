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
# Stage 1 of 2: Obtain the same static ShellCheck binary for every supported CPU.
# The official image includes ARMv6, which also runs on ARMv7 where Alpine lacks the package.
#
FROM koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d AS shellcheck

#
# Stage 2 of 2: Keep all validation tools in the test-only Buccaneerr image.
#
FROM alpine:${ALPINE_TAG}

#
# Re-declare the Alpine tag after FROM so labels can record the base image.
#
ARG ALPINE_TAG=3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

#
# Default install locations and image metadata that can be overridden using build args.
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
#
RUN apk upgrade --no-cache libcrypto3 libssl3 && \
    apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        docker-cli \
        docker-cli-compose \
        git \
        make \
        gawk \
        grep \
        coreutils \
        jq \
        iptables \
        python3 \
        ruff \
        actionlint \
        pre-commit \
        nodejs \
        npm

COPY --from=shellcheck /bin/shellcheck /usr/local/bin/shellcheck

# Keep spelling and strict typing tools in the test image with fixed releases.
RUN npm install --global cspell@9.2.2 pyright@1.1.414 && npm cache clean --force

#
# Copy over the project license and Buccaneerr script, then make the script executable.
#
COPY LICENSE                  /LICENSE
COPY buccaneerr-entrypoint.sh ${BUCCANEERR_BIN_HOME}/buccaneerr-entrypoint.sh
COPY checks.sh               ${BUCCANEERR_BIN_HOME}/checks.sh
COPY helpers                 ${BUCCANEERR_BIN_HOME}/helpers
COPY policy                  ${BUCCANEERR_BIN_HOME}/policy
COPY stubs                   ${BUCCANEERR_BIN_HOME}/stubs
COPY examples                ${BUCCANEERR_BIN_HOME}/examples
COPY unit                    ${BUCCANEERR_BIN_HOME}/unit
COPY runtime                 ${BUCCANEERR_BIN_HOME}/runtime

#
# Make the Buccaneerr entrypoint script executable.
#
RUN chmod +x "${BUCCANEERR_BIN_HOME}/buccaneerr-entrypoint.sh"

#
# Run Buccaneerr.
#
CMD [ "bash", "-lc", "${BUCCANEERR_BIN_HOME}/buccaneerr-entrypoint.sh" ]
