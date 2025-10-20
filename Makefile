SHELL := /bin/bash
ENV_FILE := .env
COMPOSE_FILE ?= docker-compose.yml
DC := docker compose -f $(COMPOSE_FILE)

.PHONY: help ensure-env dirs pull up down logs ps smoke clean

help:
	@echo "Targets: pull, up, down, logs, ps, smoke, clean"; \
	echo "Use a different compose file by setting COMPOSE_FILE=<file>. e.g.: make up COMPOSE_FILE=docker-no-redis-compose.yml"

ensure-env:
	@test -f $(ENV_FILE) || (echo "Copy .env.example to .env and adjust settings."; exit 1)

dirs: ensure-env
	@set -a; source .env; set +a; \
	mkdir -p $$DATA_ROOT; \
	mkdir -p $$DATA_ROOT/files $$DATA_ROOT/indexes $$DATA_ROOT/logs $$DATA_ROOT/auxdata

pull: ensure-env
	$(DC) pull

up: ensure-env dirs
	$(DC) up -d

down:
	$(DC) down

logs:
	$(DC) logs -f --tail=200

ps:
	$(DC) ps

smoke:
	./scripts/smoke.sh

clean:
	$(DC) down -v