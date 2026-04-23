#
# Makefile for EEWPW deployment: manages containers, environment, and data setup
#
SHELL := /bin/bash
ENV_FILE := .env
COMPOSE_FILE ?= docker-compose.yml
DC := docker compose -f $(COMPOSE_FILE)

# ------------------------------
# Parser (eewpw-parser) helpers
# ------------------------------
PARSER_VENV      ?= tools/parser-venv
PARSER_PYTHON    ?= python3
PARSER_PY        := $(PARSER_VENV)/bin/python
PARSER_PIP       := $(PARSER_VENV)/bin/pip
PARSER_BIN       := $(PARSER_VENV)/bin
# Pin to a branch or tag if you want stability (e.g. "v0.1.0")
PARSER_VERSION   ?= master
PARSER_REPO_URL  ?= https://github.com/eewpw/eewpw-parser.git

# Create venv if missing
$(PARSER_VENV):
	$(PARSER_PYTHON) -m venv $(PARSER_VENV)
	$(PARSER_PIP) install --upgrade pip


# ------------------------------
# Makefile targets
# ------------------------------
.PHONY: help ensure-env dirs pull up down update logs ps smoke clean prune parser-install parser-update parser-reset parser-check

# Display available targets and usage
help:
	@echo "Targets: pull, up, down, update, logs, ps, smoke, clean, prune, parser-install, parser-update, parser-reset, parser-check, ensure-env, dirs"; \
	echo "Use a different compose file by setting COMPOSE_FILE=<file>. e.g.: make up COMPOSE_FILE=docker-no-redis-compose.yml"


# Verify parser CLI entry points are callable
# Temporary deployment workaround: Python 3.9 only validates offline parser CLI here.
# Long-term fix is to align parser/runtime Python support and remove deployment-side special cases.
parser-check: $(PARSER_VENV)
	@set -e; \
	py_major="$$( $(PARSER_PY) -c 'import sys; print(sys.version_info.major)' )"; \
	py_minor="$$( $(PARSER_PY) -c 'import sys; print(sys.version_info.minor)' )"; \
	py_mm="$$py_major.$$py_minor"; \
	echo "Parser check using Python $$py_mm"; \
	$(PARSER_BIN)/eewpw-parse --help >/dev/null; \
	if [ "$$py_major" -gt 3 ] || [ "$$py_major" -eq 3 -a "$$py_minor" -ge 10 ]; then \
		$(PARSER_BIN)/eewpw-parse-live --help >/dev/null; \
		$(PARSER_BIN)/eewpw-replay-log --help >/dev/null; \
		echo "Parser CLI check passed (offline + live + replay)."; \
	elif [ "$$py_major" -eq 3 -a "$$py_minor" -eq 9 ]; then \
		echo "WARNING: Temporary compatibility workaround active on Python 3.9; skipping live/replay parser CLI validation."; \
		echo "Offline parser CLI check passed (live/replay checks skipped on Python 3.9)."; \
	else \
		echo "ERROR: Unsupported Python $$py_mm for parser-check (expected 3.9 or 3.10+)." >&2; \
		exit 1; \
	fi

# Remove parser venv so it can be rebuilt cleanly
parser-reset:
	rm -rf $(PARSER_VENV)
	@echo "Parser environment removed: $(PARSER_VENV)"

# Install or upgrade eewpw-parser into the venv
parser-install: $(PARSER_VENV)
	$(PARSER_PIP) install --upgrade pip
	$(PARSER_PIP) install --upgrade --force-reinstall --no-cache-dir "git+$(PARSER_REPO_URL)@$(PARSER_VERSION)"
	@$(MAKE) parser-check
	@echo
	@echo "Parser environment created/updated and parser installed. CLI tools are in: $(PARSER_BIN)"
	@echo "Examples:"
	@echo "  $(PARSER_BIN)/eewpw-parse --help"
	@echo "  $(PARSER_BIN)/eewpw-parse-live --help"
	@echo "  $(PARSER_BIN)/eewpw-replay-log --help"

# Rebuild parser venv from scratch, then reinstall parser
parser-update:
	@$(MAKE) parser-reset
	@$(MAKE) parser-install
	@echo "Parser environment rebuilt and parser updated to $(PARSER_VERSION) from $(PARSER_REPO_URL)."

# Ensure .env exists before running other targets
ensure-env:
	@test -f $(ENV_FILE) || (echo "Copy .env.example to .env and adjust settings."; exit 1)

# Create required data directories (from .env DATA_ROOT)
dirs: ensure-env
	@set -a; source .env; set +a; \
	mkdir -p $$DATA_ROOT; \
	install -d -m 0777 "$$DATA_ROOT/files"; \
	install -d -m 0777 "$$DATA_ROOT/indexes"; \
	install -d -m 0777 "$$DATA_ROOT/logs"; \
	install -d -m 0777 "$$DATA_ROOT/auxdata"; \
	install -d -m 0777 "$$DATA_ROOT/config"; \
	install -d -m 0777 "$$DATA_ROOT/manifests";

# Pull the latest images from GitHub Container Registry
pull: ensure-env
	$(DC) pull

# Start the full stack (with Redis by default)
up: ensure-env dirs
	$(DC) up -d
	
# Stop containers and remove network (volumes remain)
down:
	$(DC) down
	
# Update containers to latest images
update: ensure-env dirs
	$(DC) pull
	$(DC) up -d

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

# Prune unused images and containers
prune:
	docker system prune -f
	docker volume prune -f
	
