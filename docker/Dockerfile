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
ARG ALPINE_TAG=latest

#
# Use the specified version of the Alpine image.
#
FROM alpine:${ALPINE_TAG}

#
# Re-declare the Alpine tag after FROM so labels can record the base image.
#
ARG ALPINE_TAG=latest

#
# Default install locations and image metadata that can be overridden using build args.
#
ARG PIA_BIN_HOME=/pia
ARG PRIVATEERR_BIN_HOME=/privateerr
ARG IMAGE_CREATED=unknown
ARG IMAGE_REVISION=unknown
ARG IMAGE_VERSION=latest

#
# Set PIA scripts, Privateerr helper, and healthcheck locations.
#
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
# Copy over the PIA manual connection scripts and Privateerr helper scripts.
#
COPY pia-manual-connections ${PIA_BIN_HOME}
COPY privateerr-entrypoint.sh ${PRIVATEERR_BIN_HOME}/privateerr-entrypoint.sh

#
# Install only the tools required to generate PIA manual WireGuard configs.
# Privateerr does not establish the VPN connection itself. It stops after
# writing the WireGuard config and metadata that Gluetun will consume.
# openresolv provides the resolvconf command that PIA's scripts check when
# PIA_DNS=true, even though Privateerr only writes a config file.
#
RUN apk add --no-cache \
      bash \
      ca-certificates \
      coreutils \
      curl \
      jq \
      openresolv \
      wireguard-tools && \
    chmod +x "${PRIVATEERR_BIN_HOME}/privateerr-entrypoint.sh"

#
# Set the working directory to the PIA scripts install location.
#
WORKDIR ${PIA_BIN_HOME}

#
# Report healthy after the wrapper finishes generating the config and metadata.
#
HEALTHCHECK CMD test -f "${PRIVATEERR_HEALTHCHECK_MARKER}" || exit 1

#
# Run the Privateerr wrapper as PID 1 so it receives Docker stop signals and
# can exit cleanly after keepalive mode is interrupted.
#
CMD [ "bash", "-c", "exec ${PRIVATEERR_BIN_HOME}/privateerr-entrypoint.sh" ]
