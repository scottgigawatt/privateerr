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
ARG ALPINE_TAG=3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

#
# Use the specified version of the Alpine image.
#
FROM alpine:${ALPINE_TAG}

#
# Re-declare the Alpine tag after FROM so labels can record the base image.
#
ARG ALPINE_TAG=3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

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
ENV BUCCANEERR_BIN_HOME=${BUCCANEERR_BIN_HOME}

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
# Install validation tools. These stay out of the production image.
#
RUN apk add --no-cache \
      bash \
      ca-certificates \
      curl

#
# Copy over the project license and Buccaneerr script, then make the script executable.
#
COPY LICENSE /LICENSE
COPY buccaneerr-entrypoint.sh ${BUCCANEERR_BIN_HOME}/buccaneerr-entrypoint.sh
RUN chmod +x "${BUCCANEERR_BIN_HOME}/buccaneerr-entrypoint.sh"

#
# Run Buccaneerr.
#
CMD [ "bash", "-lc", "${BUCCANEERR_BIN_HOME}/buccaneerr-entrypoint.sh" ]
