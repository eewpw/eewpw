#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Load .env if present
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ROOT/.env"
  set +a
fi

BACKEND_PORT="${BACKEND_PORT:-8000}"
FRONTEND_PORT="${FRONTEND_PORT:-8050}"

echo "[SMOKE] Backend /healthz"
code=$(curl -s -o /tmp/eewpw_healthz.out -w "%{http_code}" "http://localhost:${BACKEND_PORT}/healthz" || true)
if [[ "$code" -ge 200 && "$code" -lt 300 ]]; then
  printf "OK (%s): " "$code"
  # print a short preview of body (JSON or plain text)
  head -c 200 /tmp/eewpw_healthz.out || true
  echo
else
  echo "[ERROR] /healthz returned $code"
  cat /tmp/eewpw_healthz.out || true
  exit 1
fi

echo "[SMOKE] Backend /status (optional)"
code=$(curl -s -o /tmp/eewpw_status.out -w "%{http_code}" "http://localhost:${BACKEND_PORT}/status" || true)
if [[ "$code" -eq 404 ]]; then
  echo "Skipped: /status not implemented (404)"
elif [[ "$code" -ge 200 && "$code" -lt 300 ]]; then
  echo "OK ($code)"
else
  echo "[WARN] /status returned $code — continuing"
fi

echo "[SMOKE] Frontend reachability"
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${FRONTEND_PORT}/" || true)
if [[ "$code" -ge 200 && "$code" -lt 400 ]]; then
  echo "OK ($code)"
else
  echo "[ERROR] Frontend returned $code"
  exit 1
fi

echo "[OK] Smoke tests passed."