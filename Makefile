#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# Makefile: Automation for managing Docker Compose services, including targets for
#           building, starting, stopping, cleaning, and validating Docker services.
#

#
# Makefile target names.
#
ALL=all
DOWN=down
CLEAN=clean
CLEAN_TEST=clean-test
NUKE=nuke
BUILD_DEPENDS=build-depends
CHECK_ENV=check-env
CHECK_PIA=check-pia
BUILD=build
BUILD_BUCCANEERR=build-buccaneerr
BUILD_PLATFORMS=build-platforms
RUN_PRIVATEERR=run-privateerr
RESTORE_TEST_CONFIG=restore-test-config
TEST=test
TEST_MAKE_HELPERS=test-make-helpers
TEST_WORKFLOWS=test-workflows
TEST_E2E=test-e2e
UP=up
CONFIG=config
ENV=env
PRINT_CONFIG=print-config
PRINT_ENV=print-env
PS=ps
LOGS=logs
HELP=help
START=start
STOP=stop

#
# List of all available targets
#
TARGETS= \
	$(ALL) \
	$(DOWN) \
	$(CLEAN) \
	$(CLEAN_TEST) \
	$(NUKE) \
	$(BUILD_DEPENDS) \
	$(CHECK_ENV) \
	$(CHECK_PIA) \
	$(BUILD) \
	$(BUILD_BUCCANEERR) \
	$(BUILD_PLATFORMS) \
	$(RUN_PRIVATEERR) \
	$(RESTORE_TEST_CONFIG) \
	$(TEST) \
	$(TEST_MAKE_HELPERS) \
	$(TEST_WORKFLOWS) \
	$(TEST_E2E) \
	$(UP) \
	$(CONFIG) \
	$(ENV) \
	$(PRINT_CONFIG) \
	$(PRINT_ENV) \
	$(PS) \
	$(LOGS) \
	$(HELP) \
	$(START) \
	$(STOP)

#
# Punctuation expanded after Make parses $(call ...) arguments.
#
COMMA=,

#
# Docker Compose service names.
#
PRIVATEERR_SERVICE ?= privateerr
BUCCANEERR_SERVICE ?= buccaneerr

#
# Config reset paths.
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
# Docker image build paths.
#
PRIVATEERR_DOCKERFILE    ?= docker/Dockerfile
PRIVATEERR_BUILD_CONTEXT ?= docker
BUCCANEERR_DOCKERFILE    ?= test/Dockerfile
BUCCANEERR_BUILD_CONTEXT ?= test
DOCKERFILES              ?= $(PRIVATEERR_DOCKERFILE) $(BUCCANEERR_DOCKERFILE)

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
# Docker Compose command to list all images used by the stack, sorted and unique.
#
NUKE_COMPOSE_IMAGES_COMMAND ?= \
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) config --images 2>/dev/null | sort -u

#
# Docker container filter options used by the nuke target to identify containers to remove.
#
NUKE_CONTAINER_FILTER_OPTIONS ?= \
	--filter "name=^/privateerr-" \
	--filter "name=^/gluetun-" \
	--filter "name=^/buccaneerr-"

#
# Docker Compose options.
#
COMPOSE_FILE          ?= docker-compose.yml
COMPOSE_DOWN_TIMEOUT  ?= 30
COMPOSE_ENV_FILE      ?= $(ENV_FILE)
COMPOSE_DOWN_OPTIONS  ?= --timeout $(COMPOSE_DOWN_TIMEOUT) --volumes --remove-orphans
COMPOSE_BUILD_OPTIONS ?= --pull --no-cache
COMPOSE_UP_OPTIONS    ?= --build --force-recreate --pull always --remove-orphans
COMPOSE_LOGS_OPTIONS  ?= -f

#
# Project-owned helpers used by Make and GitHub Actions.
#
PIA_CREDENTIAL_CHECK_CMD  ?= scripts/compose/check-pia-credentials.sh
COMPOSE_STATUS_CMD        ?= scripts/compose/ps.sh
MAKE_HELPERS_TEST_CMD     ?= test/helpers/test-make-helpers.sh
WORKFLOW_HELPERS_TEST_CMD ?= test/helpers/test-workflow-helpers.sh

#
# Disposable developer artifacts. Deployment state, generated credentials,
# containers, volumes, and images must never enter this list.
#
CLEAN_ARTIFACT_PATHS := .pytest_cache .ruff_cache test/logs

#
# Docker Compose options for test targets.
#
COMPOSE_TEST_OPTIONS ?= \
	--build \
	--force-recreate \
	--remove-orphans \
	--abort-on-container-exit \
	--exit-code-from $(BUCCANEERR_SERVICE)

#
# Docker Compose options for running only Privateerr.
#
COMPOSE_PRIVATEERR_ONLY_OPTIONS ?= \
	--build \
	--force-recreate \
	--remove-orphans \
	--abort-on-container-exit \
	--exit-code-from $(PRIVATEERR_SERVICE)

#
# Docker Buildx options used to verify multi-architecture image builds.
#
BUILDX_PLATFORM_OPTIONS     ?= --platform linux/amd64,linux/arm64,linux/arm/v7
BUILDX_BUILD_OPTIONS        ?= --pull --no-cache
BUILDX_PRIVATEERR_IMAGE_TAG ?= ghcr.io/scottgigawatt/privateerr:multiarch-local
BUILDX_BUCCANEERR_IMAGE_TAG ?= ghcr.io/scottgigawatt/buccaneerr:multiarch-local

#
# Docker commands used directly instead of through Compose.
#
DOCKER_BIN    ?= docker
DOCKER_BUILDX ?= $(DOCKER_BIN) buildx

#
# Reusable Buildx command and complete image-specific platform builds. Keep the
# target recipe short while leaving every command component overridable.
#
BUILDX_BUILD = \
	$(DOCKER_BUILDX) build \
	$(BUILDX_BUILD_OPTIONS) \
	$(BUILDX_PLATFORM_OPTIONS)

PRIVATEERR_PLATFORM_BUILD = \
	$(BUILDX_BUILD) \
	--tag "$(BUILDX_PRIVATEERR_IMAGE_TAG)" \
	--file "$(PRIVATEERR_DOCKERFILE)" \
	"$(PRIVATEERR_BUILD_CONTEXT)"

BUCCANEERR_PLATFORM_BUILD = \
	$(BUILDX_BUILD) \
	--tag "$(BUILDX_BUCCANEERR_IMAGE_TAG)" \
	--file "$(BUCCANEERR_DOCKERFILE)" \
	"$(BUCCANEERR_BUILD_CONTEXT)"

#
# Docker Compose command compatible with 'docker compose' (v2) and 'docker-compose' (v1).
#
DOCKER_COMPOSE := $(shell \
	if $(DOCKER_BIN) compose version >/dev/null 2>&1; then \
		echo "$(DOCKER_BIN) compose"; \
	elif command -v docker-compose >/dev/null 2>&1; then \
		echo "docker-compose"; \
	else \
		echo ""; \
	fi)

#
# Terminal presentation settings. Recipe-time checks enable color only for
# interactive terminals and honor the standard NO_COLOR opt-out.
#
# See https://no-color.org/ for the opt-out convention.
#
COLOR_RESET   := \033[0m
COLOR_TITLE   := \033[1;36m
COLOR_COMMAND := \033[1;33m
COLOR_INFO    := \033[0;36m
COLOR_SUCCESS := \033[0;32m
COLOR_WARNING := \033[1;33m
COLOR_ERROR   := \033[1;31m
COLOR_MUTED   := \033[0;37m

#
# Shell fragments used by user-facing Make output. Test stdout here instead of
# inside $(shell ...): GNU Make captures expansion output before a recipe sees
# the caller's terminal.
#
define print_line_inline
if [ -t 1 ] && [ -z "$$NO_COLOR" ]; then \
	printf '\n%b%s%b\n' "$(1)" "$(2)" "$(COLOR_RESET)"; \
else \
	printf '\n%s\n' "$(2)"; \
fi
endef

define print_detail_inline
if [ -t 1 ] && [ -z "$$NO_COLOR" ]; then \
	printf '  %b%s%b\n' "$(1)" "$(2)" "$(COLOR_RESET)"; \
else \
	printf '  %s\n' "$(2)"; \
fi
endef

#
# User-facing Make output helpers.
#
define announce
	@$(call print_line_inline,$(COLOR_INFO),$(1))
endef

define announce_success
	@$(call print_line_inline,$(COLOR_SUCCESS),$(1))
endef

define announce_warning
	@$(call print_line_inline,$(COLOR_WARNING),$(1))
endef

define announce_error
	@$(call print_line_inline,$(COLOR_ERROR),$(1))
endef

define announce_title
	@$(call print_line_inline,$(COLOR_TITLE),$(1))
endef

define announce_detail
	@$(call print_detail_inline,$(COLOR_MUTED),$(1))
endef

#
# Help message formatting.
#
define help_line
	@if [ -t 1 ] && [ -z "$$NO_COLOR" ]; then \
		printf '  %b%-24s%b %s\n' "$(COLOR_COMMAND)" "$(1)" "$(COLOR_RESET)" "$(2)"; \
	else \
		printf '  %-24s %s\n' "$(1)" "$(2)"; \
	fi
endef

define help_heading
	@$(call print_line_inline,$(COLOR_TITLE),$(1))
endef

#
# Verify Docker Compose availability.
#
ifeq ($(DOCKER_COMPOSE),)
    $(error "Neither 'docker compose' nor 'docker-compose' is available. \
        Please install Docker Compose.")
endif

#
# Build dependencies.
#
DEPENDENCIES=docker

#
# Environment file paths.
#
ENV_FILE=.env
EXAMPLE_ENV_FILE=example.env

#
# Targets that are not files (i.e. never up-to-date); these will run every
# time the target is called or required.
#
.PHONY: $(TARGETS)

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
	@$(DOCKER_COMPOSE) version >/dev/null 2>&1 || { \
		$(call print_line_inline,$(COLOR_ERROR),Docker Compose be missin'.); \
		$(call print_detail_inline,$(COLOR_MUTED),Install docker compose or docker-compose. 🧭); \
		exit 1; \
	}

#
# $(CHECK_ENV): Ensure .env exists before running Compose commands.
#
$(CHECK_ENV):
	@if [ ! -f "$(ENV_FILE)" ]; then \
		$(call print_line_inline,$(COLOR_ERROR),No $(ENV_FILE) found. The ship needs a chart before it sails. 🗺️); \
		$(call print_detail_inline,$(COLOR_MUTED),Copy $(EXAMPLE_ENV_FILE) to $(ENV_FILE) and set real PIA credentials.); \
		exit 1; \
	fi

#
# $(CHECK_PIA): Reject missing or documented example PIA credentials before a
#               target starts Privateerr.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure Docker and Docker Compose are installed.
#   $(CHECK_ENV) - Ensure .env exists.
#
$(CHECK_PIA): $(BUILD_DEPENDS) $(CHECK_ENV)
	@$(DOCKER_COMPOSE) --env-file $(COMPOSE_ENV_FILE) -f $(COMPOSE_FILE) \
		config --environment | $(PIA_CREDENTIAL_CHECK_CMD)

#
# $(DOWN): Stops containers and removes containers, networks, and volumes.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(DOWN): $(BUILD_DEPENDS) $(CHECK_ENV)
	$(call announce,Droppin' anchor for the Privateerr test stack. ⚓)
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) down $(COMPOSE_DOWN_OPTIONS)

#
# $(BUILD): Builds only the Privateerr image.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(BUILD): $(BUILD_DEPENDS) $(CHECK_ENV)
	$(call announce,Building the Privateerr image. ⚒️)
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) build $(COMPOSE_BUILD_OPTIONS) $(PRIVATEERR_SERVICE)

#
# $(BUILD_BUCCANEERR): Builds only the Buccaneerr image.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(BUILD_BUCCANEERR): $(BUILD_DEPENDS) $(CHECK_ENV)
	$(call announce,Building the Buccaneerr image. 🔎)
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) build $(COMPOSE_BUILD_OPTIONS) $(BUCCANEERR_SERVICE)

#
# $(BUILD_PLATFORMS): Verifies both images build for published architectures.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#
$(BUILD_PLATFORMS): $(BUILD_DEPENDS)
	$(call announce,Verifying builds for amd64$(COMMA) arm64$(COMMA) and arm/v7. 🧭)
	$(PRIVATEERR_PLATFORM_BUILD)
	$(BUCCANEERR_PLATFORM_BUILD)

#
# $(RUN_PRIVATEERR): Runs only Privateerr to generate WireGuard config and metadata.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_PIA) - Reject missing or example PIA credentials.
#
$(RUN_PRIVATEERR): $(CHECK_PIA)
	$(call announce,Generating WireGuard config and Gluetun metadata. 📜)
	PRIVATEERR_KEEPALIVE=false $(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up \
		$(COMPOSE_PRIVATEERR_ONLY_OPTIONS) \
		$(PRIVATEERR_SERVICE)

#
# $(RESTORE_TEST_CONFIG): Restores checked-in example config files after live tests.
#
# Dependencies: None.
#
$(RESTORE_TEST_CONFIG):
	$(call announce,Restoring example config files. 🧭)
	cp $(PRIVATEERR_EXAMPLE_WG_CONFIG) $(PRIVATEERR_GENERATED_WG_CONFIG)
	cp $(PRIVATEERR_EXAMPLE_METADATA) $(PRIVATEERR_GENERATED_METADATA)

#
# $(TEST_MAKE_HELPERS): Tests credential and Compose status helpers locally.
#
# Dependencies: None.
#
$(TEST_MAKE_HELPERS):
	$(MAKE_HELPERS_TEST_CMD)

#
# $(TEST_WORKFLOWS): Tests Discord and registry workflow helpers locally.
#
# Dependencies: None.
#
$(TEST_WORKFLOWS):
	$(WORKFLOW_HELPERS_TEST_CMD)

#
# $(TEST): Runs policy scripts and isolated automation-helper tests.
#
# Dependencies:
#   $(TEST_MAKE_HELPERS) - Test secret-safe Make helpers.
#   $(TEST_WORKFLOWS) - Test workflow payload and registry helpers.
#
$(TEST): $(TEST_MAKE_HELPERS) $(TEST_WORKFLOWS)
	sh -n docker/privateerr-date.sh \
		docker/privateerr-entrypoint.sh \
		docker/privateerr-healthcheck.sh \
		config/gluetun/scripts/gluetun-entrypoint-wrapper.sh \
		test/buccaneerr-entrypoint.sh
	test/check-alpine-tag-pins.sh
	test/check-image-tag-policy.sh
	$(call announce_success,Privateerr's local test voyage came back clean. ✅)

#
# $(TEST_E2E): Starts the full stack once and runs the Buccaneerr.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_PIA) - Reject missing or example PIA credentials.
#
$(TEST_E2E): $(CHECK_PIA)
	$(call announce,Starting Privateerr$(COMMA) Gluetun$(COMMA) and Buccaneerr for e2e validation. 🌊)
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up $(COMPOSE_TEST_OPTIONS)

#
# $(CLEAN_TEST): Stops and removes containers, then restores example config files.
#
# Dependencies:
#   $(DOWN) - Stop and remove the stack.
#   $(RESTORE_TEST_CONFIG) - Restore example config files.
#
$(CLEAN_TEST): $(DOWN) $(RESTORE_TEST_CONFIG)

#
# $(NUKE): Removes containers, local images, generated files, and resets example config.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(NUKE): $(BUILD_DEPENDS) $(CHECK_ENV)
	$(call announce_warning,‼️ DANGER ‼️ Removing containers$(COMMA) images$(COMMA) logs$(COMMA) and generated state. 💣)
	@compose_images="$$( $(NUKE_COMPOSE_IMAGES_COMMAND) || true )"; \
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) down $(COMPOSE_DOWN_OPTIONS) --rmi all; \
	containers="$$($(DOCKER_BIN) ps -aq $(NUKE_CONTAINER_FILTER_OPTIONS))"; \
	if [ -n "$${containers}" ]; then \
		echo "Removing leftover containers. 🧨"; \
		$(DOCKER_BIN) rm -f $${containers}; \
	fi; \
	if [ -n "$${compose_images}" ]; then \
		echo "Removing local service images."; \
		$(DOCKER_BIN) image rm -f $${compose_images} >/dev/null 2>&1 || true; \
	fi

	@echo "Removing generated logs and Gluetun state. 🧽"
	rm -rf $(PRIVATEERR_GENERATED_PATHS)

	@echo "Removing base images used by Dockerfiles. ⚓"
	$(DOCKER_BIN) image rm -f $(FROM_IMAGES) >/dev/null 2>&1 || true

	@$(MAKE) --no-print-directory $(RESTORE_TEST_CONFIG)

#
# $(UP): Builds, (re)creates, and starts every service in the stack.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_PIA) - Reject missing or example PIA credentials.
#
$(UP): $(CHECK_PIA)
	$(call announce,Building and starting the full service stack. 🚀)
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up $(COMPOSE_UP_OPTIONS)

#
# $(CONFIG): Renders the Docker Compose model.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(CONFIG): $(BUILD_DEPENDS) $(CHECK_ENV)
	$(DOCKER_COMPOSE) --env-file $(COMPOSE_ENV_FILE) -f $(COMPOSE_FILE) config

#
# $(ENV): Prints the evaluated docker compose default env configuration.
#
# Dependencies:
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(ENV): $(CHECK_ENV)
	@. ./$(COMPOSE_ENV_FILE) && \
	awk -F '=' '/^[^#]/ { \
		gsub(/^[[:space:]]+|[[:space:]]+$$/, ""); \
		value = ENVIRON[$$1]; \
		if (!value) { \
			split($$2, parts, /:-/); \
			if (length(parts) > 1) { \
				gsub(/[{}"]/,"", parts[2]); \
				value = parts[2]; \
			} \
		} \
		printf "%s=%s\n", $$1, value \
	}' $(COMPOSE_ENV_FILE)

#
# $(PRINT_CONFIG): Prints the raw uncommented docker compose yaml configuration.
#
$(PRINT_CONFIG):
	@awk '{ \
		sub(/#.*/, ""); \
		sub(/[[:space:]]+$$/, ""); \
		if (NF) print \
	}' $(COMPOSE_FILE)

#
# $(PRINT_ENV): Prints the raw uncommented docker compose env configuration.
#
# Dependencies:
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(PRINT_ENV): $(CHECK_ENV)
	@awk '{ \
		sub(/#.*/, ""); \
		sub(/[[:space:]]+$$/, ""); \
		if (NF) print \
	}' $(COMPOSE_ENV_FILE)

#
# $(PS): Displays the current Compose project in a compact status table.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure Docker and Docker Compose are installed.
#   $(CHECK_ENV) - Ensure .env exists.
#
$(PS): $(BUILD_DEPENDS) $(CHECK_ENV)
	$(COMPOSE_STATUS_CMD) \
		--env-file $(COMPOSE_ENV_FILE) \
		--compose-file $(COMPOSE_FILE)

#
# $(LOGS): View output from containers.
#
# Dependencies:
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(LOGS): $(CHECK_ENV)
	$(call announce,Showing service stack logs. 🔎)
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) logs $(COMPOSE_LOGS_OPTIONS)

#
# $(HELP): Print help information.
#
$(HELP):
	$(call announce_title,🏴‍☠️ Privateerr command chart)
	$(call announce_detail,Usage: make <target>)
	$(call help_heading,🚀 Run the stack)
	$(call help_line,$(RUN_PRIVATEERR),Generate WireGuard config and Gluetun metadata.)
	$(call help_line,$(UP),Build and start the complete validation stack.)
	$(call help_line,$(DOWN),Stop and remove stack containers and volumes.)
	$(call help_line,$(PS),Show a compact container status table.)
	$(call help_line,$(LOGS),Follow stack logs.)
	$(call help_heading,🔎 Inspect configuration)
	$(call help_line,$(CONFIG),Print Docker Compose's rendered configuration.)
	$(call help_line,$(ENV),Print resolved Compose environment values.)
	$(call help_line,$(PRINT_CONFIG),Print raw Compose configuration without comments.)
	$(call help_line,$(PRINT_ENV),Print raw environment settings without comments.)
	$(call help_heading,🧪 Test and build)
	$(call help_line,$(TEST),Run policy and automation-helper tests.)
	$(call help_line,$(TEST_MAKE_HELPERS),Test credential and status helpers.)
	$(call help_line,$(TEST_WORKFLOWS),Test Discord and registry workflow helpers.)
	$(call help_line,$(TEST_E2E),Run the live Privateerr and Gluetun test.)
	$(call help_line,$(BUILD),Build the Privateerr image.)
	$(call help_line,$(BUILD_BUCCANEERR),Build the Buccaneerr test image.)
	$(call help_line,$(BUILD_PLATFORMS),Check every published image architecture.)
	$(call help_heading,🧹 Maintenance)
	$(call help_line,$(CLEAN),Remove only disposable developer artifacts.)
	$(call help_line,$(CLEAN_TEST),Stop the stack and restore example test config.)
	$(call help_line,$(RESTORE_TEST_CONFIG),Restore checked-in example VPN config.)
	$(call help_line,$(NUKE),‼️ DANGER ‼️ remove containers$(COMMA) volumes$(COMMA) images$(COMMA) and generated state.)
	$(call announce_warning,⚠️  Destructive targets never run automatically. Back up config before using them.)

#
# $(CLEAN): Removes only disposable developer artifacts.
#
# Dependencies: None.
#
$(CLEAN):
	$(call announce,Clearing disposable developer artifacts. 🧹)
	rm -rf $(CLEAN_ARTIFACT_PATHS)

#
# $(START): Alias for $(UP).
#
# Dependencies:
#   $(UP) - Builds, recreates, and starts every service in the stack.
#
$(START): $(UP)

#
# $(STOP): Alias for $(DOWN).
#
# Dependencies:
#   $(DOWN) - Stop and remove the stack.
#
$(STOP): $(DOWN)
