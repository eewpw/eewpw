#!/usr/bin/env bash
set -euo pipefail

# Load environment variables from .env if present
if [[ -f "$(dirname "$0")/../.env" ]]; then
  set -a
  source "$(dirname "$0")/../.env"
  set +a
else
  echo "[WARN] .env file not found. Using default ports."
fi

# Fallback defaults (only used if .env missing or vars unset)
BACKEND_PORT="${BACKEND_PORT:-8000}"
FRONTEND_PORT="${FRONTEND_PORT:-8050}"

BACKEND_HOST="http://localhost:${BACKEND_PORT}"
FRONTEND_HOST="http://localhost:${FRONTEND_PORT}"

# Check for jq dependency
if ! command -v jq >/dev/null 2>&1; then
  echo "[ERROR] jq is required but not installed. Aborting."
  exit 1
fi

echo "[SMOKE] Backend /healthz"
curl -fsS "${BACKEND_HOST}/healthz" | jq -r .status

echo "[SMOKE] Backend /status (if exists)"
curl -fsS "${BACKEND_HOST}/status" | jq .

echo "[SMOKE] Frontend reachability (HTML expected)"
curl -fsS "${FRONTEND_HOST}/" >/dev/null

echo "[OK] Smoke tests passed."