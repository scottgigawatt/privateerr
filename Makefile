#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
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
UP_PULL=up-pull
UP_BUILD=up-build
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
TEST_RECOVERY=test-recovery
TEST_E2E=test-e2e
BACKUP=backup
RESTORE_VPN_EXAMPLES=restore-vpn-examples
RESET_TEST_STACK=reset-test-stack
CLEAN_ARTIFACTS=clean-artifacts
REMOVE_STACK=remove-stack
HELP=help

#
# Project target names.
#
WIREGUARD_CONFIG=wireguard-config
LIST_PIA_REGIONS=list-pia-regions
BUILD_TEST_IMAGE=build-test-image
LINT=lint
TEST_TYPES=test-types
FORMAT=format
TEST_RECOVERY_API=test-recovery-api
TEST_RECOVERY_LIVE=test-recovery-live
TEST_PRECOMMIT=test-precommit
SPELLCHECK=spellcheck
DOCS_INSTALL=docs-install
DOCS=docs
DOCS_SERVE=docs-serve

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
	$(UP_PULL) \
	$(UP_BUILD) \
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
	$(TEST_RECOVERY) \
	$(TEST_E2E) \
	$(BACKUP) \
	$(RESTORE_VPN_EXAMPLES) \
	$(RESET_TEST_STACK) \
	$(CLEAN_ARTIFACTS) \
	$(REMOVE_STACK) \
	$(HELP)

#
# Project targets.
#
PROJECT_TARGETS= \
	$(WIREGUARD_CONFIG) \
	$(LIST_PIA_REGIONS) \
	$(BUILD_TEST_IMAGE) \
	$(LINT) \
	$(TEST_TYPES) \
	$(FORMAT) \
	$(TEST_RECOVERY_API) \
	$(TEST_RECOVERY_LIVE) \
	$(TEST_PRECOMMIT) \
	$(SPELLCHECK) \
	$(DOCS_INSTALL) \
	$(DOCS) \
	$(DOCS_SERVE)

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
PRIVATEERR_SERVICE  ?= privateerr
GLUETUN_SERVICE     ?= gluetun
QBITTORRENT_SERVICE ?= qbittorrent
BUCCANEERR_SERVICE  ?= buccaneerr
APPLICATION_SERVICES = $(PRIVATEERR_SERVICE) $(GLUETUN_SERVICE) $(QBITTORRENT_SERVICE)
DEPENDENCY_SERVICES  = $(GLUETUN_SERVICE) $(QBITTORRENT_SERVICE)
TEST_SERVICES        = $(APPLICATION_SERVICES) $(BUCCANEERR_SERVICE)

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
BUCCANEERR_BUILD_CONTEXT ?= .
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
PRIVATEERR_COMPOSE_PROJECT_NAME ?=
COMPOSE_FILE                    ?= docker-compose.yml
COMPOSE_BUILD_FILE              ?= docker-compose.build.yml
COMPOSE_TEST_FILE               ?= docker-compose.test.yml
COMPOSE_PROJECT_NAME_OPTION      = $(if $(strip $(PRIVATEERR_COMPOSE_PROJECT_NAME)),--project-name "$(PRIVATEERR_COMPOSE_PROJECT_NAME)")
COMPOSE_DOWN_TIMEOUT            ?= 30
COMPOSE_ENV_FILE                ?= $(ENV_FILE)
COMPOSE_DOWN_OPTIONS            ?= --timeout $(COMPOSE_DOWN_TIMEOUT) --remove-orphans
COMPOSE_NUKE_OPTIONS            ?= --timeout $(COMPOSE_DOWN_TIMEOUT) --volumes --remove-orphans --rmi all
COMPOSE_BUILD_OPTIONS           ?= --pull --no-cache
COMPOSE_UP_OPTIONS              ?= --detach --no-build --pull never
COMPOSE_LOGS_OPTIONS            ?= --follow

#
# Project-owned helpers used by Make and GitHub Actions.
#
PIA_CREDENTIAL_CHECK_CMD ?= scripts/compose/check-pia-credentials.sh
PIA_REGIONS_CMD          ?= scripts/compose/list-pia-regions.sh
COMPOSE_STATUS_CMD       ?= scripts/compose/ps.sh
COMPOSE_NUKE_CMD         ?= scripts/compose/nuke.sh
CONFIG_BACKUP_CMD        ?= scripts/compose/backup.sh
BUCCANEERR_CHECK_CMD     ?= scripts/compose/test.sh

#
# Documentation targets share Buccaneerr's optional, hash-verified docs build.
#
DOCS_CMD           ?= scripts/docs/build.sh
DOCS_IMAGE         ?= privateerr-buccaneerr:docs
DOCS_SITE_PATH     ?= site
DOCS_SERVE_ADDRESS ?= 127.0.0.1:8000

#
# Disposable developer artifacts. Deployment state, generated credentials,
# containers, volumes, and images must never enter this list.
#
CLEAN_ARTIFACT_PATHS      := .pytest_cache .ruff_cache test/logs site
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
# Docker Compose options for disposable generation without automatic restarts.
#
COMPOSE_PRIVATEERR_ONLY_OPTIONS ?= \
	--build \
	--rm \
	--no-deps \
	--env PRIVATEERR_AUTO_RECOVER=false \
	--env PRIVATEERR_KEEPALIVE=false

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
ifneq ($(MAKECMDGOALS),$(LIST_PIA_REGIONS))
DOCKER_COMPOSE := $(shell \
	if $(DOCKER_BIN) compose version >/dev/null 2>&1; then \
		echo "$(DOCKER_BIN) compose"; \
	elif command -v docker-compose >/dev/null 2>&1; then \
		echo "docker-compose"; \
	else \
		echo ""; \
	fi)
endif

#
# Use the base file and its environment-defined project name for normal operation.
# Explicit build and test layers share that context and the repository-owned builder.
#
PRIVATEERR_COMPOSE = \
	BUILDX_BUILDER="$(BUILDX_BUILDER_NAME)" \
	$(DOCKER_COMPOSE) \
	$(COMPOSE_PROJECT_NAME_OPTION) \
	--env-file "$(COMPOSE_ENV_FILE)" \
	--file "$(COMPOSE_FILE)"
PRIVATEERR_BUILD_COMPOSE = $(PRIVATEERR_COMPOSE) --file "$(COMPOSE_BUILD_FILE)"
PRIVATEERR_TEST_IMAGE_COMPOSE = $(PRIVATEERR_COMPOSE) --file "$(COMPOSE_TEST_FILE)"
PRIVATEERR_TEST_COMPOSE = $(PRIVATEERR_BUILD_COMPOSE) --file "$(COMPOSE_TEST_FILE)"

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
# The public PIA region lookup uses host tools and does not need Docker Compose.
#
ifneq ($(MAKECMDGOALS),$(LIST_PIA_REGIONS))
ifeq ($(DOCKER_COMPOSE),)
    $(error "Neither 'docker compose' nor 'docker-compose' is available. \
        Please install Docker Compose.")
endif
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
# Show the command chart when no target is supplied.
#
.DEFAULT_GOAL := $(HELP)

#
# Targets that are not files (i.e. never up-to-date); these will run every
# time the target is called or required.
#
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
		$(call print_line_inline,$(COLOR_ERROR),Docker Compose is unavailable.); \
		$(call print_detail_inline,$(COLOR_MUTED),Install Docker Compose and make sure Docker is running.); \
		exit 1; \
	}

#
# $(CHECK_ENV): Ensure .env exists before running Compose commands.
#
# Dependencies: None.
#
$(CHECK_ENV):
	@if [ ! -f "$(ENV_FILE)" ]; then \
		$(call print_line_inline,$(COLOR_ERROR),No $(ENV_FILE) settings file found.); \
		$(call print_detail_inline,$(COLOR_MUTED),Run cp $(EXAMPLE_ENV_FILE) $(ENV_FILE)$(COMMA) then set your PIA credentials and shared API key.); \
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
# $(ALL): Pulls and starts the application stack using published images.
#
# Dependencies:
#   $(UP) - Pull and start Privateerr, Gluetun, and qBittorrent.
#
$(ALL): $(UP)

#
# $(UP): Pulls published images and starts only the application services.
#
# Dependencies:
#   $(CHECK_PIA) - Reject missing or example PIA credentials.
#
$(UP): $(CHECK_PIA)
	$(call announce,Pulling published images and starting the application stack. 🚀)
	$(PRIVATEERR_COMPOSE) pull $(APPLICATION_SERVICES)
	$(PRIVATEERR_COMPOSE) up $(COMPOSE_UP_OPTIONS) $(APPLICATION_SERVICES)

#
# $(UP_PULL): Explicit alias for published-image application startup.
#
# Dependencies:
#   $(UP) - Pull and start only the application services.
#
$(UP_PULL): $(UP)

#
# $(UP_BUILD): Pulls application dependencies and starts a locally built Privateerr.
#
# Dependencies:
#   $(CHECK_PIA) - Reject missing or example PIA credentials.
#   $(ENSURE_BUILDX_BUILDER) - Select the repository-owned image builder.
#
$(UP_BUILD): $(CHECK_PIA) $(ENSURE_BUILDX_BUILDER)
	$(call announce,Building Privateerr and starting the application stack. ⚒️)
	$(PRIVATEERR_COMPOSE) pull $(DEPENDENCY_SERVICES)
	$(PRIVATEERR_BUILD_COMPOSE) build $(COMPOSE_BUILD_OPTIONS) $(PRIVATEERR_SERVICE)
	$(PRIVATEERR_BUILD_COMPOSE) up $(COMPOSE_UP_OPTIONS) $(APPLICATION_SERVICES)

#
# $(DOWN): Stops containers and removes containers and networks.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(DOWN): $(BUILD_DEPENDS) $(CHECK_ENV)
	$(call announce,Stopping the Privateerr stack; preserving volumes and images.)
	$(PRIVATEERR_TEST_COMPOSE) down $(COMPOSE_DOWN_OPTIONS)

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
		$(COMPOSE_PROJECT_NAME_OPTION) \
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
	$(PRIVATEERR_BUILD_COMPOSE) build $(COMPOSE_BUILD_OPTIONS) $(PRIVATEERR_SERVICE)

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
# $(TEST): Runs lint, policy, helper, and Python tests in one offline Buccaneerr container.
#
# Dependencies: Docker builds the cached Buccaneerr test image.
#
$(TEST):
	$(BUCCANEERR_CHECK_CMD) all
	$(call announce_success,Privateerr's test voyage came back clean. ✅)

#
# $(TEST_MAKE_HELPERS): Tests reusable Make and Compose helpers inside Buccaneerr.
#
# Dependencies: Docker builds the cached Buccaneerr test image.
#
$(TEST_MAKE_HELPERS):
	$(BUCCANEERR_CHECK_CMD) helpers

#
# $(TEST_WORKFLOWS): Tests workflow helpers and publishing policies inside Buccaneerr.
#
# Dependencies: Docker builds the cached Buccaneerr test image.
#
$(TEST_WORKFLOWS):
	$(BUCCANEERR_CHECK_CMD) workflows

#
# $(TEST_RECOVERY): Tests recovery and generation inside Buccaneerr without PIA credentials.
#
# Dependencies: Docker builds the cached Buccaneerr test image.
#
$(TEST_RECOVERY):
	$(BUCCANEERR_CHECK_CMD) python

#
# $(TEST_E2E): Starts the full stack once and runs the Buccaneerr.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_PIA) - Reject missing or example PIA credentials.
#
$(TEST_E2E): $(CHECK_PIA) $(ENSURE_BUILDX_BUILDER)
	$(call announce,Starting Privateerr$(COMMA) Gluetun$(COMMA) qBittorrent$(COMMA) and Buccaneerr for e2e validation. 🌊)
	$(PRIVATEERR_TEST_COMPOSE) up $(COMPOSE_TEST_OPTIONS) $(TEST_SERVICES)

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
# $(RESTORE_VPN_EXAMPLES): Restores checked-in example config files after live tests.
#
# Dependencies: None.
#
$(RESTORE_VPN_EXAMPLES):
	$(call announce_warning,Replacing saved WireGuard configuration and PIA metadata with test examples. Stop any Privateerr containers using this directory first. ⚠️)
	cp "$(PRIVATEERR_EXAMPLE_WG_CONFIG)" "$(PRIVATEERR_GENERATED_WG_CONFIG)"
	cp "$(PRIVATEERR_EXAMPLE_METADATA)" "$(PRIVATEERR_GENERATED_METADATA)"

#
# $(RESET_TEST_STACK): Stops and removes containers, then restores example config files.
#
# Dependencies:
#   $(DOWN) - Stop and remove the stack.
#
$(RESET_TEST_STACK): $(DOWN)
	@$(MAKE) --no-print-directory $(RESTORE_VPN_EXAMPLES)

#
# $(CLEAN_ARTIFACTS): Removes only disposable developer artifacts.
#
# Dependencies: None.
#
$(CLEAN_ARTIFACTS):
	$(call announce,Clearing disposable developer artifacts. 🧹)
	rm -rf $(CLEAN_ARTIFACT_PATHS)
	find "$(CLEAN_ARTIFACT_FIND_ROOT)" \
		\( $(CLEAN_ARTIFACT_FIND_PRUNE) \) -prune -o \
		\( $(CLEAN_ARTIFACT_FIND_MATCH) \) -exec rm -rf {} +

#
# $(REMOVE_STACK): Removes project Docker resources and disposable runtime state.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(REMOVE_STACK): $(BUILD_DEPENDS) $(CHECK_ENV)
	$(call announce_warning,‼️ DANGER ‼️ Removing this project's containers$(COMMA) networks$(COMMA) volumes$(COMMA) eligible images$(COMMA) and build cache. 💣)
	$(call announce_warning,VPN runtime files and logs will be deleted; WireGuard configuration and PIA metadata will be replaced with test examples.)
	$(COMPOSE_NUKE_CMD) \
		--docker-bin "$(DOCKER_BIN)" \
		--compose-file "$(COMPOSE_FILE)" \
		--compose-file "$(COMPOSE_BUILD_FILE)" \
		--compose-file "$(COMPOSE_TEST_FILE)" \
		--env-file "$(COMPOSE_ENV_FILE)" \
		$(COMPOSE_PROJECT_NAME_OPTION) \
		--down-timeout "$(COMPOSE_DOWN_TIMEOUT)" \
		$(foreach dockerfile,$(DOCKERFILES),--dockerfile "$(dockerfile)") \
		--base-image-awk "$(DOCKERFILE_BASE_IMAGES_AWK)" \
		--builder-name "$(BUILDX_BUILDER_NAME)" \
		--additional-image "$(BUILDX_PRIVATEERR_IMAGE_TAG)" \
		--additional-image "$(BUILDX_BUCCANEERR_IMAGE_TAG)"
	@$(MAKE) --no-print-directory $(CLEAN_ARTIFACTS)
	@echo "Removing generated logs and Gluetun state. 🧽"
	rm -rf $(RUNTIME_ARTIFACT_PATHS)
	@$(MAKE) --no-print-directory $(RESTORE_VPN_EXAMPLES)

#
# $(HELP): Print help information.
#
# Dependencies: None.
#
$(HELP):
	$(call announce_title,🏴‍☠️ Privateerr command chart)
	$(call announce_detail,Usage: make <target>)
	$(call help_heading,🚀 Run the stack)
	$(call help_line,$(UP),Pull published images and start the application stack.)
	$(call help_line,$(UP_PULL),Explicit alias for published-image startup.)
	$(call help_line,$(UP_BUILD),Build Privateerr and start it with pulled dependencies.)
	$(call help_line,$(DOWN),Stop the stack while preserving volumes and images.)
	$(call help_line,$(PS),Show a compact container status table.)
	$(call help_line,$(LOGS),Follow stack logs.)
	$(call help_heading,🔎 Inspect configuration)
	$(call help_line,$(CONFIG),Print rendered Compose configuration (may expose secrets).)
	$(call help_line,$(ENV),Print resolved environment values (may expose secrets).)
	$(call help_line,$(PRINT_CONFIG),Print raw Compose configuration without comments.)
	$(call help_line,$(PRINT_ENV),Print raw environment settings (may expose secrets).)
	$(call help_heading,🧪 Build and test)
	$(call help_line,$(BUILD),Build the Privateerr image.)
	$(call help_line,$(BUILD_PLATFORMS),Check every published image architecture.)
	$(call help_line,$(TEST),Run credential-free lint$(COMMA) policy$(COMMA) helper$(COMMA) and unit tests.)
	$(call help_line,$(TEST_RECOVERY),Test recovery and generation inside Buccaneerr.)
	$(call help_line,$(TEST_TYPES),Check all Python with strict Pyright in Buccaneerr.)
	$(call help_line,$(LINT),Check Python formatting and Python/shell lint.)
	$(call help_line,$(FORMAT),Format Python and organize imports.)
	$(call help_line,$(TEST_RECOVERY_API),Test the real Gluetun API without PIA credentials.)
	$(call help_line,$(TEST_RECOVERY_LIVE),Test live PIA recovery in isolated containers.)
	$(call help_line,$(TEST_PRECOMMIT),Run all pre-commit hooks inside Buccaneerr.)
	$(call help_line,$(SPELLCHECK),Check project spelling inside Buccaneerr.)
	$(call help_line,$(TEST_MAKE_HELPERS),Test reusable Make and Compose helpers.)
	$(call help_line,$(TEST_WORKFLOWS),Test workflow helpers and shared publishing policies.)
	$(call help_line,$(TEST_E2E),Run live PIA validation with VPN fault injection by default.)
	$(call help_heading,📚 Developer documentation)
	$(call help_line,$(DOCS_INSTALL),Build the locked documentation tools in Buccaneerr.)
	$(call help_line,$(DOCS),Build the strict developer site and Python reference.)
	$(call help_line,$(DOCS_SERVE),Preview developer documentation at localhost:8000.)
	$(call help_heading,🧹 Maintenance)
	$(call help_line,$(BACKUP),Archive the complete config directory.)
	$(call help_line,$(RESTORE_VPN_EXAMPLES),‼️ DANGER ‼️ replace saved WireGuard configuration and PIA metadata with test examples.)
	$(call help_line,$(RESET_TEST_STACK),‼️ DANGER ‼️ stop the selected stack$(COMMA) then replace VPN files with test examples; disposable tests only.)
	$(call help_line,$(CLEAN_ARTIFACTS),Delete generated docs$(COMMA) test logs$(COMMA) and Python caches; keep deployments.)
	$(call help_line,$(REMOVE_STACK),‼️ DANGER ‼️ delete stack containers$(COMMA) volumes$(COMMA) images$(COMMA) cache and logs; replace VPN files with examples.)
	$(call help_heading,🧭 Privateerr tools)
	$(call help_line,$(WIREGUARD_CONFIG),Build Privateerr locally$(COMMA) generate a PIA WireGuard configuration file and Gluetun metadata$(COMMA) then exit.)
	$(call help_line,$(LIST_PIA_REGIONS),List all PIA region IDs and port-forwarding support.)
	$(call help_line,$(BUILD_TEST_IMAGE),Build Buccaneerr$(COMMA) the image used for Privateerr validation tools.)
	$(call announce_warning,⚠️  Reset and removal commands are for disposable tests. Verify backups of .env$(COMMA) config$(COMMA) and volumes first.)

#
# $(WIREGUARD_CONFIG): Builds and runs Privateerr once to generate a PIA WireGuard configuration file and Gluetun metadata.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_PIA) - Reject missing or example PIA credentials.
#
$(WIREGUARD_CONFIG): $(CHECK_PIA) $(ENSURE_BUILDX_BUILDER)
	$(call announce,Building Privateerr and generating a PIA WireGuard configuration file and Gluetun metadata. 📜)
	$(PRIVATEERR_BUILD_COMPOSE) run \
		$(COMPOSE_PRIVATEERR_ONLY_OPTIONS) \
		$(PRIVATEERR_SERVICE)

#
# $(LIST_PIA_REGIONS): List the public PIA catalog without credentials or stack changes.
#
# Dependencies: Host curl and jq; network access to PIA's public region catalog.
#
$(LIST_PIA_REGIONS):
	@$(PIA_REGIONS_CMD)

#
# $(BUILD_TEST_IMAGE): Builds only the Buccaneerr image.
#
# Dependencies:
#   $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#   $(CHECK_ENV) - Ensure .env exists before running Compose commands.
#
$(BUILD_TEST_IMAGE): $(BUILD_DEPENDS) $(CHECK_ENV) $(ENSURE_BUILDX_BUILDER)
	$(call announce,Building the Buccaneerr image. 🔎)
	$(PRIVATEERR_TEST_IMAGE_COMPOSE) build $(COMPOSE_BUILD_OPTIONS) $(BUCCANEERR_SERVICE)

#
# $(LINT): Check Python formatting, imports, correctness, and shell scripts in Buccaneerr.
#
# Dependencies: Docker builds the cached Buccaneerr image.
#
$(LINT):
	$(BUCCANEERR_CHECK_CMD) lint

#
# $(TEST_TYPES): Check all project-owned Python against the shared strict configuration.
#
# Dependencies: Docker builds and runs the test-only Buccaneerr image.
#
$(TEST_TYPES):
	$(BUCCANEERR_CHECK_CMD) types

#
# $(FORMAT): Apply Python import fixes and formatting with Buccaneerr's Ruff version.
#
# Dependencies: Docker; intentionally writes formatted source files.
#
$(FORMAT):
	$(BUCCANEERR_CHECK_CMD) format

#
# $(TEST_RECOVERY_API): Exercise the real Gluetun API without PIA credentials.
#
# Dependencies: Docker and a built PRIVATEERR_TEST_IMAGE.
#
$(TEST_RECOVERY_API):
	$(BUCCANEERR_CHECK_CMD) runtime

#
# $(TEST_RECOVERY_LIVE): Exercise live PIA recovery using isolated Docker resources.
#
# Dependencies: Docker, PRIVATEERR_TEST_IMAGE, and PIA credentials in .env.
#
$(TEST_RECOVERY_LIVE):
	$(BUCCANEERR_CHECK_CMD) live

#
# $(TEST_PRECOMMIT): Run repository hooks inside Buccaneerr with nested Docker access.
#
# Dependencies: Docker and network access to download pinned hook environments.
#
$(TEST_PRECOMMIT):
	$(BUCCANEERR_CHECK_CMD) precommit

#
# $(SPELLCHECK): Check project vocabulary using Buccaneerr's CSpell installation.
#
# Dependencies: Docker builds the cached Buccaneerr image.
#
$(SPELLCHECK):
	$(BUCCANEERR_CHECK_CMD) spellcheck

#
# $(DOCS_INSTALL): Build the optional documentation target in Buccaneerr.
#
# Dependencies: None; Docker reuses unchanged toolchain layers.
#
$(DOCS_INSTALL):
	DOCS_IMAGE="$(DOCS_IMAGE)" $(DOCS_CMD) install

#
# $(DOCS): Build the complete developer site with documentation warnings treated as errors.
#
# Dependencies:
#   $(DOCS_INSTALL) - Install exact, hash-verified documentation packages in Buccaneerr.
#
$(DOCS): $(DOCS_INSTALL)
	DOCS_IMAGE="$(DOCS_IMAGE)" DOCS_SITE_PATH="$(DOCS_SITE_PATH)" $(DOCS_CMD) build

#
# $(DOCS_SERVE): Preview the developer site with automatic reloads for source edits.
#
# Dependencies:
#   $(DOCS_INSTALL) - Install exact, hash-verified documentation packages in Buccaneerr.
#
$(DOCS_SERVE): $(DOCS_INSTALL)
	DOCS_IMAGE="$(DOCS_IMAGE)" DOCS_SERVE_ADDRESS="$(DOCS_SERVE_ADDRESS)" $(DOCS_CMD) serve
