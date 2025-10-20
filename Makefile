SHELL := /bin/bash
ENV_FILE := .env

.PHONY: help ensure-env dirs pull up down logs ps smoke clean

help:
	@echo "Targets: pull, up, down, logs, ps, smoke, clean"

ensure-env:
	@test -f $(ENV_FILE) || (echo "Copy .env.example to .env and adjust settings."; exit 1)

dirs: ensure-env
	@set -a; source .env; set +a; \
	mkdir -p $$DATA_ROOT; \
	mkdir -p $$DATA_ROOT/files $$DATA_ROOT/indexes $$DATA_ROOT/logs

pull: ensure-env
	docker compose pull

up: ensure-env dirs
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f --tail=200

ps:
	docker compose ps

smoke:
	./scripts/smoke.sh

clean:
	docker compose down -v