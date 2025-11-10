#!/usr/bin/env bash
# Re-pull and restart all containers to upgrade to the latest version.
# Runs the smoke test after to ensure everything is healthy.

set -euo pipefail
docker compose pull
docker compose up -d
./scripts/smoke.sh
echo "[OK] Upgraded & healthy."
