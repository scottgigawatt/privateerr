#
# Dockerfile: Custom image to create a configuration file for PIA VPN native WireGuard connections.
#

#
# Default image tag that can be overridden using build args
#
ARG UBUNTU_TAG=latest

#
# Use the specified version of the Ubuntu image
#
FROM ubuntu:${UBUNTU_TAG}

#
# Default time zone and install location that can be overridden using build args
#
ARG TZ=America/New_York
ARG PIA_APP_HOME=/pia

#
# Use zero interaction for apt and set PIA scripts install location
#
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=${TZ} \
    PIA_APP_HOME=${PIA_APP_HOME}

#
# Copy over the PIA manual connection scripts
#
COPY pia ${PIA_APP_HOME}

#
# Install required packages to generate PIA manual connection using wireguard
#
RUN echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections && \
    # Update package lists
    apt update -q && \
    # Install required packages
    apt -yq install curl jq wireguard-tools resolvconf && \
    # Clean cache and remove all downloaded package files
    apt -yq clean && apt-get autoclean && apt-get autoremove && \
    # Remove package lists loaded by apt update
    rm -rf /var/lib/apt/lists/*

#
# Set the working directory to the PIA scripts install location
#
WORKDIR ${PIA_APP_HOME}

#
# Run the setup script
#
CMD [ "sh", "-c", "${PIA_APP_HOME}/run_setup.sh" ]
