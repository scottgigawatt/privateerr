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
ARG ALPINE_TAG=3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

#
# Stage 1 of 1: Build the production Privateerr image on the pinned Alpine base.
# The single stage contains only the runtime needed to generate WireGuard data.
#
FROM alpine:${ALPINE_TAG}

#
# Re-declare the Alpine tag after FROM so labels can record the base image.
#
ARG ALPINE_TAG=3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

#
# Default install locations and image metadata.
#
ARG PIA_BIN_HOME=/pia

#
# Privateerr includes "private", which Hadolint treats as secret-like.
# This build argument contains only an install path.
#
# hadolint ignore=DL3064
ARG PRIVATEERR_BIN_HOME=/privateerr
ARG IMAGE_CREATED=unknown
ARG IMAGE_REVISION=unknown
ARG IMAGE_VERSION=latest

#
# Expose runtime paths for PIA scripts, Privateerr, and startup health checks.
# These values contain installation paths rather than secrets.
#
# hadolint ignore=DL3064
ENV PIA_BIN_HOME=${PIA_BIN_HOME} \
    PRIVATEERR_BIN_HOME=${PRIVATEERR_BIN_HOME} \
    PRIVATEERR_HEALTHCHECK_MARKER=/healthcheck/privateerr.ready \
    PYTHONPATH=${PRIVATEERR_BIN_HOME} \
    PYTHONDONTWRITEBYTECODE=1

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
# Copy license files, upstream PIA scripts, Gluetun integration, and Privateerr helpers as one
# reviewable source boundary before installing the runtime.
#
COPY LICENSE                        /LICENSE
COPY pia-manual-connections/LICENSE /licenses/pia-manual-connections/LICENSE
COPY pia-manual-connections         ${PIA_BIN_HOME}
COPY privateerr                     ${PRIVATEERR_BIN_HOME}/privateerr
COPY gluetun                        ${PRIVATEERR_BIN_HOME}/gluetun
COPY privateerr-healthcheck.sh      /usr/local/bin/privateerr-healthcheck
COPY privateerr-date.sh             /usr/local/bin/date

#
# Refresh the pinned base from its stable repositories, then install the runtime.
# Stable Alpine supplies the patched Python interpreter, runtime libraries, and PIA tools.
#
RUN apk upgrade --no-cache && \
    apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        jq \
        openresolv \
        python3 \
        wireguard-tools && \
    chmod +x \
        /usr/local/bin/privateerr-healthcheck \
        /usr/local/bin/date

#
# Set the working directory to the PIA scripts install location.
#
WORKDIR ${PIA_BIN_HOME}

#
# Report healthy after the supervisor prepares the files required by its startup mode.
#
HEALTHCHECK CMD ["privateerr-healthcheck"]

#
# Run the Python supervisor directly as PID 1 so it receives shutdown signals
# and can stop all upstream children before removing temporary configuration.
#
CMD ["python3", "-m", "privateerr"]
