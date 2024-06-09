#
# Makefile for managing Docker Compose services.
# This Makefile includes targets for building, starting, stopping, and cleaning Docker services.
# It ensures that necessary dependencies are installed and Docker images are built with specified options.
#

#
# Makefile target names
#
ALL=all
DOWN=down
CLEAN=clean
BUILD_DEPENDS=build-depends
PIA_CREDS=pia-creds
BUILD=build
UP=up
LOGS=logs
HELP=help
RUN=run

#
# Docker Compose options
#
COMPOSE_SERVICE_NAME  ?= privateerr
COMPOSE_DOWN_TIMEOUT  ?= 30
COMPOSE_DOWN_OPTIONS  ?= --timeout $(COMPOSE_DOWN_TIMEOUT) --rmi all --volumes
COMPOSE_BUILD_OPTIONS ?= --pull --no-cache
COMPOSE_UP_OPTIONS    ?= --build --force-recreate --pull always
COMPOSE_LOGS_OPTIONS  ?= --follow

#
# Build dependencies
#
DEPENDENCIES=docker docker-compose

#
# Path to Dockerfile
#
DOCKERFILE := docker/Dockerfile

#
# Extract base FROM image from Dockerfile
#
FROM_IMAGE=$(shell awk '/^FROM / { print $$2 }' $(DOCKERFILE) | sed 's/:.*//' | head -n 1)

#
# Targets that are not files (i.e. never up-to-date); these will run every
# time the target is called or required.
#
.PHONY: $(ALL) $(DOWN) $(CLEAN) $(BUILD_DEPENDS) $(BUILD) $(UP) $(LOGS) $(HELP) $(RUN)

#
# $(ALL): Default makefile target. Builds and starts the service stack.
#
$(ALL): $(UP)

#
# $(BUILD_DEPENDS): Ensure build dependencies are installed.
#
$(BUILD_DEPENDS):
	$(foreach exe,$(DEPENDENCIES), \
		$(if $(shell which $(exe) 2> /dev/null),,$(error "No $(exe) in PATH")))

#
# $(PIA_CREDS): Ensures Private Internet Access credentials are set.
#
$(PIA_CREDS):
	@if [ -z "${PIA_USER}" ]; then \
		echo "Please set PIA_USER"; \
		exit 1; \
	fi; \
	if [ -z "${PIA_PASS}" ]; then \
		echo "Please set PIA_PASS"; \
		exit 1; \
	fi

#
# $(DOWN): Stops containers and removes containers, networks, volumes, and images created by up.
#
$(DOWN): $(BUILD_DEPENDS)
	@echo "\nStopping service $(COMPOSE_SERVICE_NAME)"
	docker-compose down $(COMPOSE_DOWN_OPTIONS)

	@echo "\nRemoving images based on $(FROM_IMAGE)"
	@docker images -q "$(FROM_IMAGE)" | xargs -r docker rmi -f || true

#
# $(BUILD): Builds the service stack.
#
# Dependencies: $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#               $(PIA_CREDS) - Ensure Private Internet Access credentials are set.
#
$(BUILD): $(BUILD_DEPENDS) $(PIA_CREDS)
	@echo "\nBuilding service $(COMPOSE_SERVICE_NAME)"
	docker-compose build $(COMPOSE_BUILD_OPTIONS) $(COMPOSE_SERVICE_NAME)

#
# $(UP): Builds, (re)creates, and starts containers for services.
#
# Dependencies: $(BUILD_DEPENDS) - Ensure build dependencies are installed.
#               $(PIA_CREDS) - Ensure Private Internet Access credentials are set.
#
$(UP): $(BUILD_DEPENDS) $(PIA_CREDS)
	@echo "\nStarting service $(COMPOSE_SERVICE_NAME)"
	docker-compose up $(COMPOSE_UP_OPTIONS)

#
# $(LOGS): View output from containers.
#
$(LOGS):
	@echo "\nGetting logs for service $(COMPOSE_SERVICE_NAME)"
	docker-compose logs $(COMPOSE_LOGS_OPTIONS)

#
# $(HELP): Print help information.
#
$(HELP):
	@echo "Usage: make [TARGET]"
	@echo ""
	@echo "Targets:"
	@echo "  $(ALL)             - Builds and starts the service stack."
	@echo "  $(BUILD_DEPENDS)   - Ensures build dependencies are installed."
	@echo "  $(PIA_CREDS)       - Ensures Private Internet Access credentials are set."
	@echo "  $(DOWN)            - Stops and removes containers, networks, volumes, and images."
	@echo "  $(CLEAN)           - Alias for $(DOWN)."
	@echo "  $(BUILD)           - Builds the service stack."
	@echo "  $(UP)              - Builds, (re)creates, and starts containers for services."
	@echo "  $(RUN)             - Alias for $(UP)."
	@echo "  $(LOGS)            - Shows logs for the service."
	@echo "  $(HELP)            - Displays this help message."

#
# Alias for down
#
$(CLEAN): $(DOWN)

#
# Alias for up
#
$(RUN): $(UP)
