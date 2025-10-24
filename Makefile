#
# Makefile for EEWPW deployment: manages containers, environment, and data setup
#
SHELL := /bin/bash
ENV_FILE := .env
COMPOSE_FILE ?= docker-compose.yml
DC := docker compose -f $(COMPOSE_FILE)

.PHONY: help ensure-env dirs pull up down logs ps smoke clean

# Display available targets and usage
help:
	@echo "Targets: pull, up, down, logs, ps, smoke, clean"; \
	echo "Use a different compose file by setting COMPOSE_FILE=<file>. e.g.: make up COMPOSE_FILE=docker-no-redis-compose.yml"

# Ensure .env exists before running other targets
ensure-env:
	@test -f $(ENV_FILE) || (echo "Copy .env.example to .env and adjust settings."; exit 1)

# Create required data directories (from .env DATA_ROOT)
dirs: ensure-env
	@set -a; source .env; set +a; \
	mkdir -p $$DATA_ROOT; \
	mkdir -p $$DATA_ROOT/files $$DATA_ROOT/indexes $$DATA_ROOT/logs $$DATA_ROOT/auxdata $$DATA_ROOT/config; \
	chmod -R a+rwX $$DATA_ROOT

# Pull the latest images from GitHub Container Registry
pull: ensure-env
	$(DC) pull

# Start the full stack (with Redis by default)
up: ensure-env dirs
	$(DC) up -d
	
# Stop containers and remove network (volumes remain)
down:
	$(DC) down
	
# Follow combined container logs (latest 200 lines)
logs:
	$(DC) logs -f --tail=200

# List container status
ps:
	$(DC) ps

# Run a quick smoke test against the backend
smoke:
	./scripts/smoke.sh

# Remove containers and volumes completely
clean:
	$(DC) down -v