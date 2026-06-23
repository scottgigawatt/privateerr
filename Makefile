#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# Makefile: Automation for managing Docker Compose services, including targets for
#           building, starting, stopping, cleaning, and validating Docker services.
#

#
# Makefile target names
#
ALL=all
DOWN=down
CLEAN=clean
NUKE=nuke
BUILD_DEPENDS=build-depends
CHECK_ENV=check-env
BUILD=build
BUILD_BUCCANEERR=build-buccaneerr
RUN_PRIVATEERR=run-privateerr
RESET_CONFIG=reset-config
TEST_E2E=test-e2e
TEST_DOWN=test-down
TEST_LOGS=test-logs
UP=up
LOGS=logs
HELP=help
START=start
STOP=stop

#
# Docker Compose service names
#
PRIVATEERR_SERVICE ?= privateerr
BUCCANEERR_SERVICE ?= buccaneerr

#
# Config reset paths
#
PRIVATEERR_EXAMPLE_WG_CONFIG   ?= test/examples/example-wg0.conf
PRIVATEERR_EXAMPLE_METADATA    ?= test/examples/example-privateerr.env
PRIVATEERR_GENERATED_WG_CONFIG ?= config/gluetun/wireguard/wg0.conf
PRIVATEERR_GENERATED_METADATA  ?= config/gluetun/wireguard/privateerr.env
PRIVATEERR_GENERATED_PATHS     ?= config/privateerr/logs \
	config/buccaneerr/logs \
	config/gluetun/forwarded_port \
	config/gluetun/ip \
	config/gluetun/piaportforward.json \
	config/gluetun/servers

#
# Dockerfile paths used to discover local base images.
#
DOCKERFILES ?= docker/Dockerfile test/Dockerfile

#
# Extract base FROM images from Dockerfiles and resolve Dockerfile ARG defaults.
#
FROM_IMAGES ?= $(shell awk '\
	/^ARG / { split($$2, arg_parts, "="); docker_args[arg_parts[1]] = arg_parts[2] } \
	/^FROM / { \
		from_image = $$2; \
		for (arg_name in docker_args) { \
			gsub("\\$$[{]" arg_name "[}]", docker_args[arg_name], from_image); \
		} \
		print from_image; \
	}' $(DOCKERFILES) | sort -u)

#
# Docker cleanup commands and options used by the nuke target.
#
NUKE_COMPOSE_IMAGES_COMMAND   ?= $(DOCKER_COMPOSE) config --images 2>/dev/null | sort -u
NUKE_CONTAINER_FILTER_OPTIONS ?= --filter "name=^/privateerr-" --filter "name=^/gluetun-" --filter "name=^/buccaneerr-"

#
# Docker Compose options
#
COMPOSE_DOWN_TIMEOUT            ?= 30
COMPOSE_DOWN_OPTIONS            ?= --timeout $(COMPOSE_DOWN_TIMEOUT) --volumes --remove-orphans
COMPOSE_BUILD_OPTIONS           ?= --pull --no-cache
COMPOSE_UP_OPTIONS              ?= --build --force-recreate --pull always --remove-orphans
COMPOSE_LOGS_OPTIONS            ?= -f
COMPOSE_TEST_OPTIONS            ?= --build --force-recreate --remove-orphans --abort-on-container-exit --exit-code-from $(BUCCANEERR_SERVICE)
COMPOSE_PRIVATEERR_ONLY_OPTIONS ?= --build --force-recreate --remove-orphans --abort-on-container-exit --exit-code-from $(PRIVATEERR_SERVICE)

#
# Docker Compose command compatible with 'docker compose' (v2) and 'docker-compose' (v1).
#
DOCKER_COMPOSE := $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; elif command -v docker-compose >/dev/null 2>&1; then echo "docker-compose"; else echo ""; fi)

ifeq ($(DOCKER_COMPOSE),)
    $(error "Neither 'docker compose' nor 'docker-compose' is available. Please install Docker Compose.")
endif

#
# Build dependencies
#
DEPENDENCIES=docker

#
# Environment file paths
#
ENV_FILE=.env
EXAMPLE_ENV_FILE=example.env

#
# Targets that are not files (i.e. never up-to-date); these will run every
# time the target is called or required.
#
.PHONY: $(ALL) $(DOWN) $(CLEAN) $(NUKE) $(BUILD_DEPENDS) $(CHECK_ENV) $(BUILD) $(BUILD_BUCCANEERR) $(RUN_PRIVATEERR) $(RESET_CONFIG) $(TEST_E2E) $(TEST_DOWN) $(TEST_LOGS) $(UP) $(LOGS) $(HELP) $(START) $(STOP)

#
# $(ALL): Default makefile target. Builds and starts the service stack.
#
# Dependencies:
#   $(UP) - Builds, recreates, and starts every service in the stack.
#
$(ALL): $(UP)

#
# $(BUILD_DEPENDS): Ensure build dependencies are installed.
#
$(BUILD_DEPENDS):
	$(foreach exe,$(DEPENDENCIES), \
		$(if $(shell which $(exe) 2> /dev/null),,$(error "No $(exe) in PATH")))
	@# Verify Docker Compose availability.
	@$(DOCKER_COMPOSE) version >/dev/null 2>&1 || (echo "Docker Compose be missin'. Install docker compose or docker-compose. 🧭" && exit 1)

#
# $(CHECK_ENV): Ensure .env exists before running Compose commands.
#
$(CHECK_ENV):
	@if [ ! -f "$(ENV_FILE)" ]; then \
		echo "\nNo $(ENV_FILE) found. The ship needs a chart before it sails. 🗺️"; \
		echo "Copy $(EXAMPLE_ENV_FILE) to $(ENV_FILE), then update yer PIA credentials and voyage settings."; \
		echo "Run: cp $(EXAMPLE_ENV_FILE) $(ENV_FILE)"; \
		exit 1; \
	fi

#
# $(DOWN): Stops containers and removes containers, networks, and volumes.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(DOWN): $(BUILD_DEPENDS) $(CHECK_ENV)
	@echo "\nDroppin' anchor for the whole fleet. ⚓"
	$(DOCKER_COMPOSE) down $(COMPOSE_DOWN_OPTIONS)

#
# $(BUILD): Builds only the Privateerr image.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(BUILD): $(BUILD_DEPENDS) $(CHECK_ENV)
	@echo "\nHammerin' Privateerr into a seaworthy image. ⚒️"
	$(DOCKER_COMPOSE) build $(COMPOSE_BUILD_OPTIONS) $(PRIVATEERR_SERVICE)

#
# $(BUILD_BUCCANEERR): Builds only the Buccaneerr image.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(BUILD_BUCCANEERR): $(BUILD_DEPENDS) $(CHECK_ENV)
	@echo "\nForgin' the Buccaneerr spyglass. 🔎"
	$(DOCKER_COMPOSE) build $(COMPOSE_BUILD_OPTIONS) $(BUCCANEERR_SERVICE)

#
# $(RUN_PRIVATEERR): Runs only Privateerr to generate WireGuard config and metadata.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(RUN_PRIVATEERR): $(BUILD_DEPENDS) $(CHECK_ENV)
	@echo "\nSummonin' WireGuard map and Gluetun scroll. 📜"
	PRIVATEERR_KEEPALIVE=false $(DOCKER_COMPOSE) up \
		$(COMPOSE_PRIVATEERR_ONLY_OPTIONS) \
		$(PRIVATEERR_SERVICE)

#
# $(RESET_CONFIG): Restores checked-in example config files after live tests.
#
$(RESET_CONFIG):
	@echo "\nRestorin' example maps for safe check-in. 🧭"
	cp $(PRIVATEERR_EXAMPLE_WG_CONFIG) $(PRIVATEERR_GENERATED_WG_CONFIG)
	cp $(PRIVATEERR_EXAMPLE_METADATA) $(PRIVATEERR_GENERATED_METADATA)

#
# $(TEST_E2E): Starts the full stack once and runs the Buccaneerr.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(TEST_E2E): $(BUILD_DEPENDS) $(CHECK_ENV)
	@echo "\nLaunching Privateerr, Gluetun, and Buccaneerr in one voyage. 🌊"
	$(DOCKER_COMPOSE) up $(COMPOSE_TEST_OPTIONS)

#
# $(TEST_DOWN): Stops and removes containers, then restores example config files.
#
# Dependencies:
#   $(DOWN) - Stop and remove the stack.
#   $(RESET_CONFIG) - Restore example config files.
#
$(TEST_DOWN): $(DOWN) $(RESET_CONFIG)

#
# $(NUKE): Removes containers, local images, generated files, and resets example config.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(NUKE): $(BUILD_DEPENDS) $(CHECK_ENV)
	@echo "\nFirin' the clean broadside. Repo-safe files stay aboard. 💣"
	@compose_images="$$( $(NUKE_COMPOSE_IMAGES_COMMAND) || true )"; \
	$(DOCKER_COMPOSE) down $(COMPOSE_DOWN_OPTIONS) --rmi all; \
	containers="$$(docker ps -aq $(NUKE_CONTAINER_FILTER_OPTIONS))"; \
	if [ -n "$${containers}" ]; then \
		echo "Scuttlin' leftover containers. 🧨"; \
		docker rm -f $${containers}; \
	fi; \
	if [ -n "$${compose_images}" ]; then \
		echo "Sinkin' local service images. 🏴‍☠️"; \
		docker image rm -f $${compose_images} >/dev/null 2>&1 || true; \
	fi

	@echo "Scrubbin' generated logs and Gluetun state. 🧽"
	rm -rf $(PRIVATEERR_GENERATED_PATHS)

	@echo "Keelhaulin' base FROM images. ⚓"
	docker image rm -f $(FROM_IMAGES) >/dev/null 2>&1 || true

	@$(MAKE) --no-print-directory $(RESET_CONFIG)

#
# $(TEST_LOGS): View output from stack containers.
#
# Dependencies:
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(TEST_LOGS): $(CHECK_ENV)
	@echo "\nReadin' ship logs. 🔎"
	$(DOCKER_COMPOSE) logs $(COMPOSE_LOGS_OPTIONS)

#
# $(UP): Builds, (re)creates, and starts every service in the stack.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(UP): $(BUILD_DEPENDS) $(CHECK_ENV)
	@echo "\nRaisin' the whole Privateerr fleet. 🏴‍☠️"
	$(DOCKER_COMPOSE) up $(COMPOSE_UP_OPTIONS)

#
# $(LOGS): View output from containers.
#
# Dependencies:
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(LOGS): $(CHECK_ENV)
	@echo "\nReadin' logs for the fleet. 🔎"
	$(DOCKER_COMPOSE) logs $(COMPOSE_LOGS_OPTIONS)

#
# $(HELP): Print help information.
#
$(HELP):
	@echo "Usage: make [TARGET]"
	@echo ""
	@echo "Targets:"
	@echo "  $(ALL)                Builds and starts the full service stack."
	@echo "  $(BUILD_DEPENDS)      Ensures build dependencies are installed."
	@echo "  $(CHECK_ENV)          Ensures .env exists before Compose commands run."
	@echo "  $(DOWN)               Stops and removes the full service stack."
	@echo "  $(CLEAN)              Stops the stack and restores example config files."
	@echo "  $(NUKE)               Removes containers, images, generated files, and restores example config."
	@echo "  $(BUILD)              Builds only the Privateerr image."
	@echo "  $(BUILD_BUCCANEERR)   Builds only the Buccaneerr image."
	@echo "  $(RUN_PRIVATEERR)     Runs only Privateerr to generate config and metadata."
	@echo "  $(RESET_CONFIG)       Restores example wg0.conf and privateerr.env files."
	@echo "  $(TEST_E2E)           Runs the full one-shot Privateerr + Gluetun validation voyage."
	@echo "  $(TEST_DOWN)          Stops the stack and restores example config files."
	@echo "  $(TEST_LOGS)          Shows logs for the service stack."
	@echo "  $(UP)                 Builds, (re)creates, and starts every service."
	@echo "  $(START)              Alias for $(UP)."
	@echo "  $(STOP)               Alias for $(DOWN)."
	@echo "  $(LOGS)               Shows logs for the service stack."
	@echo "  $(HELP)               Displays this help message."

#
# Alias for test-down
#
# Dependencies:
#   $(TEST_DOWN) - Stop the stack and restore example config files.
#
$(CLEAN): $(TEST_DOWN)

#
# Alias for up
#
# Dependencies:
#   $(UP) - Builds, recreates, and starts every service in the stack.
#
$(START): $(UP)

#
# Alias for down
#
# Dependencies:
#   $(DOWN) - Stop and remove the stack.
#
$(STOP): $(DOWN)
