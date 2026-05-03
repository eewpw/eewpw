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
.PHONY: help ensure-env dirs _fix_permissions _check_data_root pull up down update logs ps smoke clean prune parser-install parser-update parser-reset parser-check

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

# Create required data directories from .env.
# `dirs` is used by `up` and `update`, so keep only non-destructive checks here.
dirs: ensure-env
	@set -a; source .env; set +a; \
	mkdir -p "$$DATA_ROOT"; \
	install -d -m 0777 "$$DATA_ROOT/files"; \
	install -d -m 0777 "$$DATA_ROOT/indexes"; \
	install -d -m 0777 "$$DATA_ROOT/logs"; \
	install -d -m 0777 "$$DATA_ROOT/auxdata"; \
	install -d -m 0777 "$$DATA_ROOT/config"; \
	install -d -m 0777 "$$DATA_ROOT/manifests"; \
	$(MAKE) _fix_permissions; \
	$(MAKE) _check_data_root

# Private helper: recursively repair DATA_ROOT permissions for bind-mounted reuse.
_fix_permissions: ensure-env
	# Resolve DATA_ROOT without `realpath` for macOS/Linux portability.
	# chmod may fail for root-owned files; warn here and let access checks decide.
	@set -a; source .env; set +a; \
	if [ -z "$$DATA_ROOT" ]; then \
		echo "ERROR: DATA_ROOT is not set in .env"; \
		exit 1; \
	fi; \
	mkdir -p "$$DATA_ROOT"; \
	DATA_ROOT_RAW="$$DATA_ROOT"; \
	DATA_ROOT_ABS="$$(cd "$$DATA_ROOT" && pwd -P)"; \
	echo "_fix_permissions: DATA_ROOT(raw)=$$DATA_ROOT_RAW"; \
	echo "_fix_permissions: DATA_ROOT(abs)=$$DATA_ROOT_ABS"; \
	perm_warn=0; \
	if ! find "$$DATA_ROOT_ABS" -type d -exec chmod a+rwx {} +; then \
		echo "WARNING: _fix_permissions could not repair permissions on one or more directories under $$DATA_ROOT_ABS"; \
		perm_warn=1; \
	fi; \
	if ! find "$$DATA_ROOT_ABS" -type f -exec chmod a+rw {} +; then \
		echo "WARNING: _fix_permissions could not repair permissions on one or more files under $$DATA_ROOT_ABS"; \
		perm_warn=1; \
	fi; \
	if [ "$$perm_warn" -eq 1 ]; then \
		echo "WARNING: Continuing to _check_data_root despite chmod warnings."; \
	fi

# Private helper: verify DATA_ROOT access and warn about stale upload/index state.
_check_data_root: ensure-env
	# Resolve DATA_ROOT without `realpath` for macOS/Linux portability.
	# Relative DATA_ROOT is allowed, but can point to a different folder after reinstall.
	# Runtime dirs need r/w/x; user-managed auxdata/config only need r/x here.
	# File/index and manifest checks are warn-only heuristics.
	@set -a; source .env; set +a; \
	if [ -z "$$DATA_ROOT" ]; then \
		echo "ERROR: DATA_ROOT is not set in .env"; \
		exit 1; \
	fi; \
	mkdir -p "$$DATA_ROOT"; \
	DATA_ROOT_RAW="$$DATA_ROOT"; \
	DATA_ROOT_ABS="$$(cd "$$DATA_ROOT" && pwd -P)"; \
	echo "_check_data_root: COMPOSE_FILE=$(COMPOSE_FILE)"; \
	echo "_check_data_root: DATA_ROOT(raw)=$$DATA_ROOT_RAW"; \
	echo "_check_data_root: DATA_ROOT(abs)=$$DATA_ROOT_ABS"; \
	echo "_check_data_root: EEWPW_DATA_DIR=$${EEWPW_DATA_DIR:-}"; \
	case "$$DATA_ROOT_RAW" in \
		/*) ;; \
		*) echo "WARNING: DATA_ROOT is relative ($$DATA_ROOT_RAW). Absolute path resolves to $$DATA_ROOT_ABS" ;; \
	esac; \
	fail=0; \
	for d in files indexes logs auxdata config manifests; do \
		if [ ! -d "$$DATA_ROOT_ABS/$$d" ]; then \
			echo "ERROR: Missing required directory: $$DATA_ROOT_ABS/$$d"; \
			fail=1; \
		fi; \
	done; \
	for d in files indexes logs manifests; do \
		p="$$DATA_ROOT_ABS/$$d"; \
		if [ -d "$$p" ] && { [ ! -r "$$p" ] || [ ! -w "$$p" ] || [ ! -x "$$p" ]; }; then \
			echo "ERROR: Insufficient runtime access for $$p (need r/w/x)"; \
			fail=1; \
		fi; \
	done; \
	for d in auxdata config; do \
		p="$$DATA_ROOT_ABS/$$d"; \
		if [ -d "$$p" ] && { [ ! -r "$$p" ] || [ ! -x "$$p" ]; }; then \
			echo "ERROR: Insufficient access for $$p (need r/x)"; \
			fail=1; \
		fi; \
	done; \
	for f in "$$DATA_ROOT_ABS"/files/*.json; do \
		[ -e "$$f" ] || break; \
		id="$$(basename "$$f" .json)"; \
		meta="$$DATA_ROOT_ABS/indexes/$$id/meta.json"; \
		if [ ! -f "$$meta" ]; then \
			echo "WARNING: files/$$id.json exists but indexes/$$id/meta.json is missing"; \
		fi; \
	done; \
	for meta in "$$DATA_ROOT_ABS"/indexes/*/meta.json; do \
		[ -e "$$meta" ] || break; \
		idx_id="$$(basename "$$(dirname "$$meta")")"; \
		file_json="$$DATA_ROOT_ABS/files/$$idx_id.json"; \
		if [ ! -f "$$file_json" ]; then \
			if grep -Eiq '"(dataset_type|dataset_kind|kind|type|source_type|source_kind)"[[:space:]]*:[[:space:]]*"(virtual|derived|synthetic|live|remote|external)"' "$$meta"; then \
				:; \
			else \
				echo "WARNING: indexes/$$idx_id/meta.json exists but files/$$idx_id.json is missing (ordinary physical dataset expected)"; \
			fi; \
		fi; \
	done; \
	for manifest in "$$DATA_ROOT_ABS"/manifests/*.json; do \
		[ -e "$$manifest" ] || break; \
		if [ ! -s "$$manifest" ]; then \
			echo "WARNING: manifests/$$(basename "$$manifest") appears malformed (empty file)"; \
		elif ! grep -Eq '^[[:space:]]*[\{\[]' "$$manifest"; then \
			echo "WARNING: manifests/$$(basename "$$manifest") appears malformed (not JSON-like)"; \
		elif ! grep -Eq ':' "$$manifest"; then \
			echo "WARNING: manifests/$$(basename "$$manifest") appears malformed (missing key/value separator)"; \
		fi; \
		sources="$$(grep -Eo '"source"[[:space:]]*:[[:space:]]*"[^"]+"' "$$manifest" | sed -E 's/.*:[[:space:]]*"([^"]+)"/\1/' || true)"; \
		for src in $$sources; do \
			if [ ! -f "$$DATA_ROOT_ABS/indexes/$$src/meta.json" ]; then \
				echo "WARNING: manifests/$$(basename "$$manifest") references missing indexes/$$src/meta.json"; \
			fi; \
		done; \
	done; \
	if [ "$$fail" -ne 0 ]; then \
		exit 1; \
	fi
	
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
	
