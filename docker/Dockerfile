#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# Dockerfile: Custom image to generate a Private Internet Access WireGuard configuration file and Gluetun metadata.
#

#
# Default Alpine image tag that can be overridden using build args.
#
ARG ALPINE_TAG=3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

#
# Stage 1 of 1: Build the production Privateerr image on the pinned Alpine base.
# The single stage contains only the runtime needed to generate WireGuard data.
#
FROM alpine:${ALPINE_TAG}

#
# Re-declare the Alpine tag after FROM so labels can record the base image.
#
ARG ALPINE_TAG=3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

#
# Default install locations, fixed package floors, and image metadata.
#
ARG PIA_BIN_HOME=/pia

#
# Privateerr includes "private", which Hadolint treats as secret-like.
# This build argument contains only an install path.
#
# hadolint ignore=DL3064
ARG PRIVATEERR_BIN_HOME=/privateerr
ARG EDGE_APK_REPOSITORY=https://dl-cdn.alpinelinux.org/alpine/edge/main
ARG LIBEXPAT_APK_MIN_VERSION=2.9.0-r0
ARG ZLIB_APK_MIN_VERSION=1.3.2-r1
ARG IMAGE_CREATED=unknown
ARG IMAGE_REVISION=unknown
ARG IMAGE_VERSION=latest

#
# Set PIA scripts, Privateerr helper, and healthcheck locations.
#

#
# This environment block publishes paths, not secrets.
#
# hadolint ignore=DL3064
ENV PIA_BIN_HOME=${PIA_BIN_HOME} \
    PRIVATEERR_BIN_HOME=${PRIVATEERR_BIN_HOME} \
    PRIVATEERR_HEALTHCHECK_MARKER=/healthcheck/privateerr.ready

#
# Add Open Container Initiative image labels. GitHub Container Registry reads
# these to link the package back to the repo, show a description, display
# license details, and identify the image in registries.
#
LABEL org.opencontainers.image.title="Privateerr" \
        org.opencontainers.image.description="Privateerr generates PIA WireGuard configs and Gluetun metadata from unmodified PIA manual connection scripts." \
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
# Copy license files, upstream PIA scripts, and Privateerr-owned helpers as one
# reviewable source boundary before installing the runtime.
#
COPY LICENSE                        /LICENSE
COPY pia-manual-connections/LICENSE /licenses/pia-manual-connections/LICENSE
COPY pia-manual-connections         ${PIA_BIN_HOME}
COPY privateerr-entrypoint.sh       ${PRIVATEERR_BIN_HOME}/privateerr-entrypoint.sh
COPY privateerr-generate.sh         ${PRIVATEERR_BIN_HOME}/privateerr-generate.sh
COPY privateerr                     ${PRIVATEERR_BIN_HOME}/privateerr
COPY privateerr-healthcheck.sh      /usr/local/bin/privateerr-healthcheck
COPY privateerr-date.sh             /usr/local/bin/date

#
# Upgrade the base OpenSSL runtime libraries to Alpine's current fixed release,
# then install Python for the supervisor and the tools used by upstream PIA scripts.
# Stable Alpine provides fixed jq, nghttp2, and zlib.
# Only libexpat needs edge until stable includes its 2.9.0 security fixes.
#
RUN apk upgrade --no-cache libcrypto3 libssl3 && \
    apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        jq \
        openresolv \
        python3 \
        wireguard-tools \
        "zlib>=${ZLIB_APK_MIN_VERSION}" && \
    printf '%s\n' "@expatfix ${EDGE_APK_REPOSITORY}" >> /etc/apk/repositories && \
    apk add --no-cache "libexpat@expatfix>=${LIBEXPAT_APK_MIN_VERSION}" && \
    chmod +x \
        "${PRIVATEERR_BIN_HOME}/privateerr-entrypoint.sh" \
        /usr/local/bin/privateerr-healthcheck \
        /usr/local/bin/date

#
# Set the working directory to the PIA scripts install location.
#
WORKDIR ${PIA_BIN_HOME}

#
# Report healthy after the wrapper finishes generating the config and metadata.
#
HEALTHCHECK CMD ["privateerr-healthcheck"]

#
# Run the Privateerr wrapper as PID 1 so it receives Docker stop signals and
# can exit cleanly after keepalive mode is interrupted.
#
CMD [ "bash", "-c", "exec ${PRIVATEERR_BIN_HOME}/privateerr-entrypoint.sh" ]
