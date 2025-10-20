#!/usr/bin/env bash
# Manage eewpw-config.toml inside the frontend container (under /app/client)
#
# Usage:
#   scripts/manage-config.sh copy <local_path_to_toml>
#   scripts/manage-config.sh append "key = value"    # appends a single line
#   scripts/manage-config.sh append -f <local_path>   # appends contents of file
#   scripts/manage-config.sh view
#   scripts/manage-config.sh delete
#
# Options via env vars:
#   EEWPW_COMPOSE_FILE   : compose file to use (default: docker-compose.yml)
#   EEWPW_SERVICE        : service name (default: frontend)
#   EEWPW_CONFIG_PATH    : path inside container (default: /app/client/eewpw-config.toml)
#
set -euo pipefail

EEWPW_COMPOSE_FILE=${EEWPW_COMPOSE_FILE:-docker-compose.yml}
EEWPW_SERVICE=${EEWPW_SERVICE:-frontend}
EEWPW_CONFIG_PATH=${EEWPW_CONFIG_PATH:-/app/client/eewpw-config.toml}

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  sed -n '2,25p' "$0"
}

need_compose() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] docker not found in PATH" >&2; exit 1;
  fi
  if ! docker compose version >/dev/null 2>&1; then
    echo "[ERROR] docker compose plugin not available" >&2; exit 1;
  fi
  if [[ ! -f "$ROOT_DIR/$EEWPW_COMPOSE_FILE" ]]; then
    echo "[ERROR] compose file not found: $ROOT_DIR/$EEWPW_COMPOSE_FILE" >&2; exit 1;
  fi
}

container_up() {
  local cid
  cid=$(docker compose -f "$ROOT_DIR/$EEWPW_COMPOSE_FILE" ps -q "$EEWPW_SERVICE" || true)
  if [[ -z "$cid" ]]; then
    echo "[ERROR] service '$EEWPW_SERVICE' is not running. Start it first:" >&2
    echo "  docker compose -f $EEWPW_COMPOSE_FILE up -d $EEWPW_SERVICE" >&2
    exit 1
  fi
}

copy_config() {
  local src="$1"
  [[ -f "$src" ]] || { echo "[ERROR] source file not found: $src" >&2; exit 1; }
  echo "[INFO] Copying $src → $EEWPW_SERVICE:$EEWPW_CONFIG_PATH"
  # Ensure target directory exists and copy content
  docker compose -f "$ROOT_DIR/$EEWPW_COMPOSE_FILE" exec -T "$EEWPW_SERVICE" sh -lc "mkdir -p $(dirname "$EEWPW_CONFIG_PATH") && cat > '$EEWPW_CONFIG_PATH'" <"$src"
  echo "[OK] Copied."
}

append_line() {
  local line="$1"
  echo "[INFO] Appending one line to $EEWPW_SERVICE:$EEWPW_CONFIG_PATH"
  docker compose -f "$ROOT_DIR/$EEWPW_COMPOSE_FILE" exec -T "$EEWPW_SERVICE" sh -lc "mkdir -p $(dirname "$EEWPW_CONFIG_PATH") && touch '$EEWPW_CONFIG_PATH' && printf '%s\n' \"$(printf '%s' "$line" | sed 's/\\/\\\\/g; s/\"/\\\"/g')\" >> '$EEWPW_CONFIG_PATH'"
  echo "[OK] Appended."
}

append_file() {
  local src="$1"
  [[ -f "$src" ]] || { echo "[ERROR] file to append not found: $src" >&2; exit 1; }
  echo "[INFO] Appending contents of $src to $EEWPW_SERVICE:$EEWPW_CONFIG_PATH"
  docker compose -f "$ROOT_DIR/$EEWPW_COMPOSE_FILE" exec -T "$EEWPW_SERVICE" sh -lc "mkdir -p $(dirname "$EEWPW_CONFIG_PATH") && touch '$EEWPW_CONFIG_PATH' && cat >> '$EEWPW_CONFIG_PATH'" <"$src"
  echo "[OK] Appended."
}

view_config() {
  echo "[INFO] Viewing $EEWPW_SERVICE:$EEWPW_CONFIG_PATH"
  docker compose -f "$ROOT_DIR/$EEWPW_COMPOSE_FILE" exec -T "$EEWPW_SERVICE" sh -lc "if [ -f '$EEWPW_CONFIG_PATH' ]; then echo '--- $EEWPW_CONFIG_PATH ---'; cat '$EEWPW_CONFIG_PATH'; else echo '[INFO] No config at $EEWPW_CONFIG_PATH'; fi"
}

delete_config() {
  echo "[INFO] Deleting $EEWPW_SERVICE:$EEWPW_CONFIG_PATH"
  docker compose -f "$ROOT_DIR/$EEWPW_COMPOSE_FILE" exec -T "$EEWPW_SERVICE" sh -lc "rm -f '$EEWPW_CONFIG_PATH' && echo '[OK] Deleted' || true"
}

main() {
  need_compose
  [[ $# -ge 1 ]] || { usage; exit 1; }
  local cmd="$1"; shift || true
  case "$cmd" in
    copy)
      [[ $# -eq 1 ]] || { echo "Usage: $0 copy <local_path_to_toml>" >&2; exit 1; }
      container_up; copy_config "$1";;
    append)
      if [[ $# -eq 2 && "$1" == "-f" ]]; then
        container_up; append_file "$2";
      elif [[ $# -ge 1 ]]; then
        container_up; append_line "$*";
      else
        echo "Usage: $0 append \"key = value\"  OR  $0 append -f <file>" >&2; exit 1;
      fi;;
    view)
      container_up; view_config;;
    delete)
      container_up; delete_config;;
    -h|--help|help)
      usage;;
    *)
      echo "[ERROR] Unknown command: $cmd" >&2; usage; exit 1;;
  esac
}

main "$@"
