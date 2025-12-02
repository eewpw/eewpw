#!/usr/bin/env bash
# Usage:
#   ./scripts/run_live_pipeline.sh live
#   ./scripts/run_live_pipeline.sh replay
#
# Modes:
#   live   : Tail REAL EEW logs and feed them directly to eewpw-parse-live.
#            No eewpw-replay-log is used in this mode.
#   replay : Use eewpw-replay-log to feed FAKE log files from static source logs,
#            while eewpw-parse-live tails the FAKE logs. Intended for synthetic
#            tests and demos, NOT for real operations.

set -euo pipefail

MODE="${1:-replay}"

if [[ "${MODE}" != "live" && "${MODE}" != "replay" ]]; then
  echo "Invalid mode: ${MODE}"
  echo "Usage: $0 [live|replay]"
  exit 1
fi

# --------------------------
# Configuration
# --------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PARSER_VENV="${SCRIPT_DIR}/../tools/parser-venv"   # venv with eewpw-parser installed
SRC_LOG_ROOT="${SCRIPT_DIR}/../example-data/Elm2020"  # Real/static EEW logs (scfinder.log, scvsmag-processing-info.log)
DATA_ROOT="${SCRIPT_DIR}/../data"

# For replay mode only:
# FAKE_DIR is the directory where eewpw-replay-log writes fake logs (see replay_log_cli.ensure_tmp_and_target)
# REPLAY_SPEED defines the speed of log replay (0.0 = as fast as possible, 1.0 = real-time)
# REPEAT_COUNT defines how many times to repeat the source logs
FAKE_DIR="${SCRIPT_DIR}/../tmp"
REPLAY_SPEED=1.0
REPEAT_COUNT=1

# --------------------------
# Activate venv
# --------------------------
source "${PARSER_VENV}/bin/activate"

if [[ "${MODE}" == "live" ]]; then
  # ==========================
  # LIVE MODE: real logs only
  # ==========================
  echo "[run_live_pipeline] MODE=live"
  echo "[run_live_pipeline] Tailing real logs under: ${SRC_LOG_ROOT}"
  echo "[run_live_pipeline] Data root: ${DATA_ROOT}"

  # Finder (tails real log file)
  "${PARSER_VENV}/bin/eewpw-parse-live" \
    --algo finder \
    --dialect scfinder \
    --logfile "${SRC_LOG_ROOT}/scfinder.log" \
    --data-root "${DATA_ROOT}" \
    --instance finder@live \
    --poll-interval 0.2 &

  FINDER_PID=$!

  # VS (tails real log file)
  "${PARSER_VENV}/bin/eewpw-parse-live" \
    --algo vs \
    --dialect scvsmag \
    --logfile "${SRC_LOG_ROOT}/scvsmag-processing-info.log" \
    --data-root "${DATA_ROOT}" \
    --instance vs@live \
    --poll-interval 0.2 &

  VS_PID=$!

  # In live mode we just wait; stop with Ctrl-C
  trap 'echo "Stopping live parsers..."; kill "${FINDER_PID}" "${VS_PID}" 2>/dev/null || true; exit 0' INT TERM
  wait

else
  # ==========================
  # REPLAY MODE: synthetic
  # ==========================
  echo "[run_live_pipeline] MODE=replay"
  echo "[run_live_pipeline] Replaying logs from: ${SRC_LOG_ROOT}"
  echo "[run_live_pipeline] Fake logs under: ${FAKE_DIR}"
  echo "[run_live_pipeline] Data root: ${DATA_ROOT}"
  echo "[run_live_pipeline] REPEAT_COUNT=${REPEAT_COUNT}, REPLAY_SPEED=${REPLAY_SPEED}"
  mkdir -p "${FAKE_DIR}"

  # eewpw-replay-log writes to tmp/fake_<srcname>.log (see replay_log_cli.ensure_tmp_and_target)
  FAKE_FINDER="${FAKE_DIR}/fake_scfinder.log"
  FAKE_VS="${FAKE_DIR}/fake_scvsmag-processing-info.log"

  # Truncate fake logs
  : > "${FAKE_FINDER}"
  : > "${FAKE_VS}"

  # --------------------------
  # Start live parsers on FAKE logs
  # --------------------------

  # Finder (tails fake replay file)
  "${PARSER_VENV}/bin/eewpw-parse-live" \
    --algo finder \
    --dialect scfinder \
    --logfile "${FAKE_FINDER}" \
    --data-root "${DATA_ROOT}" \
    --instance finder@replay \
    --poll-interval 0.2 &

  FINDER_PID=$!

  # VS (tails fake replay file)
  "${PARSER_VENV}/bin/eewpw-parse-live" \
    --algo vs \
    --dialect scvsmag \
    --logfile "${FAKE_VS}" \
    --data-root "${DATA_ROOT}" \
    --instance vs@replay \
    --poll-interval 0.2 &

  VS_PID=$!

  # --------------------------
  # Feed FAKE logs with replay
  # --------------------------

  # Replay Finder log; it writes to ${FAKE_DIR}/fake_scfinder.log internally
  "${PARSER_VENV}/bin/eewpw-replay-log" \
    --speed "${REPLAY_SPEED}" \
    --repeat "${REPEAT_COUNT}" \
    --time-mode realtime \
    "${SRC_LOG_ROOT}/scfinder.log" &

  REPLAY_FINDER_PID=$!

  # Replay VS log; it writes to ${FAKE_DIR}/fake_scvsmag-processing-info.log internally
  "${PARSER_VENV}/bin/eewpw-replay-log" \
    --speed "${REPLAY_SPEED}" \
    --repeat "${REPEAT_COUNT}" \
    --time-mode realtime \
    "${SRC_LOG_ROOT}/scvsmag-processing-info.log" &

  REPLAY_VS_PID=$!

  # --------------------------
  # Wait for replay to finish
  # --------------------------
  # Ensure Ctrl-C / SIGTERM stops both replay writers and live parsers
  trap 'echo "Stopping replay and parsers..."; kill "${REPLAY_FINDER_PID}" "${REPLAY_VS_PID}" "${FINDER_PID}" "${VS_PID}" 2>/dev/null || true; exit 0' INT TERM
  wait "${REPLAY_FINDER_PID}" "${REPLAY_VS_PID}"

  # Once replay is done, we can stop the parsers
  kill "${FINDER_PID}" "${VS_PID}" || true

  echo "Replay finished. Parsed data should now be under: ${DATA_ROOT}"
fi
