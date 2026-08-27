#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# Makefile: Automation for managing Docker Compose services, including targets for
#           building, starting, stopping, cleaning, and validating Docker services.
#

#
# Common target names.
#
BUILD_DEPENDS=build-depends
CHECK_ENV=check-env
CHECK_PIA=check-pia
ENSURE_BUILDX_BUILDER=ensure-buildx-builder
ALL=all
UP=up
DOWN=down
PS=ps
LOGS=logs
CONFIG=config
ENV=env
PRINT_CONFIG=print-config
PRINT_ENV=print-env
BUILD=build
BUILD_PLATFORMS=build-platforms
TEST=test
TEST_MAKE_HELPERS=test-make-helpers
TEST_WORKFLOWS=test-workflows
TEST_E2E=test-e2e
BACKUP=backup
RESTORE_TEST_CONFIG=restore-test-config
CLEAN_TEST=clean-test
CLEAN=clean
NUKE=nuke
HELP=help

#
# Project target names.
#
RUN_PRIVATEERR=run-privateerr
BUILD_BUCCANEERR=build-buccaneerr

#
# Common targets.
#
COMMON_TARGETS= \
	$(BUILD_DEPENDS) \
	$(CHECK_ENV) \
	$(CHECK_PIA) \
	$(ENSURE_BUILDX_BUILDER) \
	$(ALL) \
	$(UP) \
	$(DOWN) \
	$(PS) \
	$(LOGS) \
	$(CONFIG) \
	$(ENV) \
	$(PRINT_CONFIG) \
	$(PRINT_ENV) \
	$(BUILD) \
	$(BUILD_PLATFORMS) \
	$(TEST) \
	$(TEST_MAKE_HELPERS) \
	$(TEST_WORKFLOWS) \
	$(TEST_E2E) \
	$(BACKUP) \
	$(RESTORE_TEST_CONFIG) \
	$(CLEAN_TEST) \
	$(CLEAN) \
	$(NUKE) \
	$(HELP)

#
# Project targets.
#
PROJECT_TARGETS= \
	$(RUN_PRIVATEERR) \
	$(BUILD_BUCCANEERR)

#
# Internal targets.
#
INTERNAL_TARGETS=

#
# Complete target inventory.
#
TARGETS= \
	$(COMMON_TARGETS) \
	$(PROJECT_TARGETS) \
	$(INTERNAL_TARGETS)

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
CONFIG_PATH                    ?= config
CONFIG_BACKUP_PATH             ?= backups
CONFIG_BACKUP_NAME             ?= privateerr
PRIVATEERR_EXAMPLE_WG_CONFIG   ?= test/examples/example-wg0.conf
PRIVATEERR_EXAMPLE_METADATA    ?= test/examples/example-privateerr.env
PRIVATEERR_GENERATED_WG_CONFIG ?= config/gluetun/wireguard/wg0.conf
PRIVATEERR_GENERATED_METADATA  ?= config/gluetun/wireguard/privateerr.env
RUNTIME_ARTIFACT_PATHS         := config/privateerr/logs \
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
# AWK command and reusable program options.
#
AWK_BIN                ?= awk
AWK_FILE_OPTION        ?= -f
AWK_ASSIGNMENT_OPTIONS ?= -F =

#
# Reusable AWK programs used by Make and Compose helpers.
#
DOCKERFILE_BASE_IMAGES_AWK ?= scripts/awk/collect-dockerfile-base-images.awk
ORDER_ENVIRONMENT_AWK      ?= scripts/awk/order-environment.awk
STRIP_COMMENTS_AWK         ?= scripts/awk/strip-comments.awk

#
# Docker Compose options.
#
PRIVATEERR_COMPOSE_PROJECT_NAME ?= privateerr
COMPOSE_FILE                    ?= docker-compose.yml
COMPOSE_DOWN_TIMEOUT            ?= 30
COMPOSE_ENV_FILE                ?= $(ENV_FILE)
COMPOSE_DOWN_OPTIONS            ?= --timeout $(COMPOSE_DOWN_TIMEOUT) --remove-orphans
COMPOSE_NUKE_OPTIONS            ?= --timeout $(COMPOSE_DOWN_TIMEOUT) --volumes --remove-orphans --rmi all
COMPOSE_BUILD_OPTIONS           ?= --pull --no-cache
COMPOSE_UP_OPTIONS              ?= --build --force-recreate --pull always --remove-orphans
COMPOSE_LOGS_OPTIONS            ?= --follow

#
# Project-owned helpers used by Make and GitHub Actions.
#
PIA_CREDENTIAL_CHECK_CMD  ?= scripts/compose/check-pia-credentials.sh
COMPOSE_STATUS_CMD        ?= scripts/compose/ps.sh
COMPOSE_NUKE_CMD          ?= scripts/compose/nuke.sh
CONFIG_BACKUP_CMD         ?= scripts/compose/backup.sh
MAKE_HELPERS_TEST_CMD     ?= test/helpers/test-make-helpers.sh
COMPOSE_NUKE_TEST_CMD     ?= test/helpers/test-compose-nuke.sh
BASE_IMAGES_TEST_CMD      ?= test/helpers/test-dockerfile-base-images.sh
WORKFLOW_HELPERS_TEST_CMD ?= test/helpers/test-workflow-helpers.sh
POLICY_HELPERS_TEST_CMD   ?= test/helpers/test-policy-checks.sh
BUILD_PIN_POLICY_TEST_CMD ?= test/policy/check-build-pin-policy.sh
IMAGE_TAG_POLICY_TEST_CMD ?= test/policy/check-image-tag-policy.sh

#
# Disposable developer artifacts. Deployment state, generated credentials,
# containers, volumes, and images must never enter this list.
#
CLEAN_ARTIFACT_PATHS      := .pytest_cache .ruff_cache test/logs
CLEAN_ARTIFACT_FIND_ROOT  := .
CLEAN_ARTIFACT_FIND_PRUNE := -path './.git' -o -path './docker/pia-manual-connections'
CLEAN_ARTIFACT_FIND_MATCH := -type d -name '__pycache__' -o -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '.DS_Store' \)

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
BUILDX_BUILDER_NAME         ?= privateerr-local
BUILDX_BUILDER_DRIVER       ?= docker-container
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
	--builder "$(BUILDX_BUILDER_NAME)" \
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
# Bind Compose and its implicit --build paths to the repository-owned builder.
# Keep the project name explicit instead of deriving it from the checkout path.
#
PRIVATEERR_COMPOSE = \
	BUILDX_BUILDER="$(BUILDX_BUILDER_NAME)" \
	$(DOCKER_COMPOSE) \
	--project-name "$(PRIVATEERR_COMPOSE_PROJECT_NAME)" \
	--env-file "$(COMPOSE_ENV_FILE)" \
	--file "$(COMPOSE_FILE)"

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
.DEFAULT_GOAL := $(ALL)
.PHONY: $(TARGETS)

#
# $(BUILD_DEPENDS): Ensure build dependencies are installed.
#
# Dependencies: None.
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
# Dependencies: None.
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
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists.
#
$(CHECK_PIA): $(BUILD_DEPENDS) $(CHECK_ENV)
	@$(PRIVATEERR_COMPOSE) config --environment | $(PIA_CREDENTIAL_CHECK_CMD)

#
# $(ENSURE_BUILDX_BUILDER): Create the repository-owned Buildx builder when missing.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#
$(ENSURE_BUILDX_BUILDER): $(BUILD_DEPENDS)
	@if ! $(DOCKER_BUILDX) inspect "$(BUILDX_BUILDER_NAME)" >/dev/null 2>&1; then \
		$(DOCKER_BUILDX) create \
			--name "$(BUILDX_BUILDER_NAME)" \
			--driver "$(BUILDX_BUILDER_DRIVER)" >/dev/null; \
	fi

#
# $(ALL): Default makefile target. Builds and starts the service stack.
#
# Dependencies:
#   $(UP) - Builds, recreates, and starts every service in the stack.
#
$(ALL): $(UP)

#
# $(UP): Builds, (re)creates, and starts every service in the stack.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_PIA) - Reject missing or example PIA credentials.
#
$(UP): $(CHECK_PIA) $(ENSURE_BUILDX_BUILDER)
	$(call announce,Building and starting the full service stack. 🚀)
	$(PRIVATEERR_COMPOSE) up $(COMPOSE_UP_OPTIONS)

#
# $(DOWN): Stops containers and removes containers and networks.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(DOWN): $(BUILD_DEPENDS) $(CHECK_ENV)
	$(call announce,Droppin' anchor for the Privateerr test stack. ⚓)
	$(PRIVATEERR_COMPOSE) down $(COMPOSE_DOWN_OPTIONS)

#
# $(PS): Displays the current Compose project in a compact status table.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure Docker and Docker Compose are installed.
#   $(CHECK_ENV) - Ensure .env exists.
#
$(PS): $(BUILD_DEPENDS) $(CHECK_ENV)
	$(COMPOSE_STATUS_CMD) \
		--docker-bin "$(DOCKER_BIN)" \
		--env-file "$(COMPOSE_ENV_FILE)" \
		--compose-file "$(COMPOSE_FILE)"

#
# $(LOGS): View output from containers.
#
# Dependencies:
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(LOGS): $(CHECK_ENV)
	$(call announce,Showing service stack logs. 🔎)
	$(PRIVATEERR_COMPOSE) logs $(COMPOSE_LOGS_OPTIONS)

#
# $(CONFIG): Renders the Docker Compose model.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(CONFIG): $(BUILD_DEPENDS) $(CHECK_ENV)
	$(PRIVATEERR_COMPOSE) config

#
# $(ENV): Prints the evaluated docker compose default env configuration.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(ENV): $(BUILD_DEPENDS) $(CHECK_ENV)
	@$(PRIVATEERR_COMPOSE) config --environment | \
	$(AWK_BIN) $(AWK_ASSIGNMENT_OPTIONS) $(AWK_FILE_OPTION) \
		$(ORDER_ENVIRONMENT_AWK) - $(COMPOSE_ENV_FILE)

#
# $(PRINT_CONFIG): Prints the raw uncommented docker compose yaml configuration.
#
# Dependencies: None.
#
$(PRINT_CONFIG):
	@$(AWK_BIN) $(AWK_FILE_OPTION) $(STRIP_COMMENTS_AWK) $(COMPOSE_FILE)

#
# $(PRINT_ENV): Prints the raw uncommented docker compose env configuration.
#
# Dependencies:
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(PRINT_ENV): $(CHECK_ENV)
	@$(AWK_BIN) $(AWK_FILE_OPTION) $(STRIP_COMMENTS_AWK) $(COMPOSE_ENV_FILE)

#
# $(BUILD): Builds only the Privateerr image.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(BUILD): $(BUILD_DEPENDS) $(CHECK_ENV) $(ENSURE_BUILDX_BUILDER)
	$(call announce,Building the Privateerr image. ⚒️)
	$(PRIVATEERR_COMPOSE) build $(COMPOSE_BUILD_OPTIONS) $(PRIVATEERR_SERVICE)

#
# $(BUILD_PLATFORMS): Verifies both images build for published architectures.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#
$(BUILD_PLATFORMS): $(BUILD_DEPENDS) $(ENSURE_BUILDX_BUILDER)
	$(call announce,Verifying builds for amd64$(COMMA) arm64$(COMMA) and arm/v7. 🧭)
	$(PRIVATEERR_PLATFORM_BUILD)
	$(BUCCANEERR_PLATFORM_BUILD)

#
# $(TEST): Runs policy scripts and isolated automation-helper tests.
#
# Dependencies:
#   $(TEST_MAKE_HELPERS) - Test reusable Make and Compose helpers.
#   $(TEST_WORKFLOWS) - Test workflow payload and registry helpers.
#
$(TEST): $(TEST_MAKE_HELPERS) $(TEST_WORKFLOWS)
	sh -n docker/privateerr-date.sh \
		docker/privateerr-entrypoint.sh \
		docker/privateerr-healthcheck.sh \
		config/gluetun/scripts/gluetun-entrypoint-wrapper.sh \
		test/buccaneerr-entrypoint.sh
	$(call announce_success,Privateerr's local test voyage came back clean. ✅)

#
# $(TEST_MAKE_HELPERS): Tests reusable Make and Compose helpers locally.
#
# Dependencies: None.
#
$(TEST_MAKE_HELPERS):
	$(MAKE_HELPERS_TEST_CMD)
	$(BASE_IMAGES_TEST_CMD)
	$(COMPOSE_NUKE_TEST_CMD)

#
# $(TEST_WORKFLOWS): Tests workflow helpers and shared publishing policies
#                    locally.
#
# Dependencies: None.
#
$(TEST_WORKFLOWS):
	$(WORKFLOW_HELPERS_TEST_CMD)
	$(BUILD_PIN_POLICY_TEST_CMD)
	$(IMAGE_TAG_POLICY_TEST_CMD)
	$(POLICY_HELPERS_TEST_CMD)

#
# $(TEST_E2E): Starts the full stack once and runs the Buccaneerr.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_PIA) - Reject missing or example PIA credentials.
#
$(TEST_E2E): $(CHECK_PIA) $(ENSURE_BUILDX_BUILDER)
	$(call announce,Starting Privateerr$(COMMA) Gluetun$(COMMA) and Buccaneerr for e2e validation. 🌊)
	$(PRIVATEERR_COMPOSE) up $(COMPOSE_TEST_OPTIONS)

#
# $(BACKUP): Archives the complete Privateerr config directory.
#
# Dependencies: None.
#
$(BACKUP):
	@$(CONFIG_BACKUP_CMD) \
		"$(CONFIG_PATH)" \
		"$(CONFIG_BACKUP_PATH)" \
		"$(CONFIG_BACKUP_NAME)"

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
# $(CLEAN_TEST): Stops and removes containers, then restores example config files.
#
# Dependencies:
#   $(DOWN) - Stop and remove the stack.
#   $(RESTORE_TEST_CONFIG) - Restore example config files.
#
$(CLEAN_TEST): $(DOWN) $(RESTORE_TEST_CONFIG)

#
# $(CLEAN): Removes only disposable developer artifacts.
#
# Dependencies: None.
#
$(CLEAN):
	$(call announce,Clearing disposable developer artifacts. 🧹)
	rm -rf $(CLEAN_ARTIFACT_PATHS)
	find "$(CLEAN_ARTIFACT_FIND_ROOT)" \
		\( $(CLEAN_ARTIFACT_FIND_PRUNE) \) -prune -o \
		\( $(CLEAN_ARTIFACT_FIND_MATCH) \) -exec rm -rf {} +

#
# $(NUKE): Removes project Docker resources and disposable runtime state.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(NUKE): $(BUILD_DEPENDS) $(CHECK_ENV)
	$(call announce_warning,‼️ DANGER ‼️ Removing containers$(COMMA) volumes$(COMMA) images$(COMMA) scoped build cache$(COMMA) logs$(COMMA) and generated state. 💣)
	$(COMPOSE_NUKE_CMD) \
		--docker-bin "$(DOCKER_BIN)" \
		--compose-file "$(COMPOSE_FILE)" \
		--env-file "$(COMPOSE_ENV_FILE)" \
		--project-name "$(PRIVATEERR_COMPOSE_PROJECT_NAME)" \
		--down-timeout "$(COMPOSE_DOWN_TIMEOUT)" \
		$(foreach dockerfile,$(DOCKERFILES),--dockerfile "$(dockerfile)") \
		--base-image-awk "$(DOCKERFILE_BASE_IMAGES_AWK)" \
		--builder-name "$(BUILDX_BUILDER_NAME)" \
		--additional-image "$(BUILDX_PRIVATEERR_IMAGE_TAG)" \
		--additional-image "$(BUILDX_BUCCANEERR_IMAGE_TAG)"
	@$(MAKE) --no-print-directory $(CLEAN)
	@echo "Removing generated logs and Gluetun state. 🧽"
	rm -rf $(RUNTIME_ARTIFACT_PATHS)
	@$(MAKE) --no-print-directory $(RESTORE_TEST_CONFIG)

#
# $(HELP): Print help information.
#
# Dependencies: None.
#
$(HELP):
	$(call announce_title,🏴‍☠️ Privateerr command chart)
	$(call announce_detail,Usage: make <target>)
	$(call help_heading,🚀 Run the stack)
	$(call help_line,$(UP),Build and start the complete validation stack.)
	$(call help_line,$(DOWN),Stop the stack while preserving volumes and images.)
	$(call help_line,$(PS),Show a compact container status table.)
	$(call help_line,$(LOGS),Follow stack logs.)
	$(call help_heading,🔎 Inspect configuration)
	$(call help_line,$(CONFIG),Print Docker Compose's rendered configuration.)
	$(call help_line,$(ENV),Print resolved Compose environment values.)
	$(call help_line,$(PRINT_CONFIG),Print raw Compose configuration without comments.)
	$(call help_line,$(PRINT_ENV),Print raw environment settings without comments.)
	$(call help_heading,🧪 Build and test)
	$(call help_line,$(BUILD),Build the Privateerr image.)
	$(call help_line,$(BUILD_PLATFORMS),Check every published image architecture.)
	$(call help_line,$(TEST),Run policy and automation-helper tests.)
	$(call help_line,$(TEST_MAKE_HELPERS),Test reusable Make and Compose helpers.)
	$(call help_line,$(TEST_WORKFLOWS),Test workflow helpers and shared publishing policies.)
	$(call help_line,$(TEST_E2E),Run the live Privateerr and Gluetun test.)
	$(call help_heading,🧹 Maintenance)
	$(call help_line,$(BACKUP),Archive the complete config directory.)
	$(call help_line,$(RESTORE_TEST_CONFIG),Restore checked-in example VPN config.)
	$(call help_line,$(CLEAN_TEST),Stop the stack and restore example test config.)
	$(call help_line,$(CLEAN),Remove only disposable developer artifacts.)
	$(call help_line,$(NUKE),‼️ DANGER ‼️ remove project Docker resources and transient state.)
	$(call help_heading,🧭 Privateerr tools)
	$(call help_line,$(RUN_PRIVATEERR),Generate WireGuard config and Gluetun metadata.)
	$(call help_line,$(BUILD_BUCCANEERR),Build the Buccaneerr test image.)
	$(call announce_warning,⚠️  Destructive targets never run automatically. Run make backup first.)

#
# $(RUN_PRIVATEERR): Runs only Privateerr to generate WireGuard config and metadata.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_PIA) - Reject missing or example PIA credentials.
#
$(RUN_PRIVATEERR): $(CHECK_PIA) $(ENSURE_BUILDX_BUILDER)
	$(call announce,Generating WireGuard config and Gluetun metadata. 📜)
	PRIVATEERR_KEEPALIVE=false $(PRIVATEERR_COMPOSE) up \
		$(COMPOSE_PRIVATEERR_ONLY_OPTIONS) \
		$(PRIVATEERR_SERVICE)

#
# $(BUILD_BUCCANEERR): Builds only the Buccaneerr image.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(BUILD_BUCCANEERR): $(BUILD_DEPENDS) $(CHECK_ENV) $(ENSURE_BUILDX_BUILDER)
	$(call announce,Building the Buccaneerr image. 🔎)
	$(PRIVATEERR_COMPOSE) build $(COMPOSE_BUILD_OPTIONS) $(BUCCANEERR_SERVICE)
