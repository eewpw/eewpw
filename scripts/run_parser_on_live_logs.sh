#!/usr/bin/env bash
#
# This script is a temporary utility. It will be merged into run_live_pipeline.sh eventually.
# The script runs eewpw-parse-live on real EEW logs, without using eewpw-replay-log at all.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
ENV_FILE="${REPO_ROOT}/.env"
PARSER_VENV="${REPO_ROOT}/tools/parser-venv"
PARSE_LIVE_BIN="${PARSER_VENV}/bin/eewpw-parse-live"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: Missing .env file at ${ENV_FILE}" >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

if [[ -z "${DATA_ROOT:-}" ]]; then
  echo "ERROR: DATA_ROOT is not set in ${ENV_FILE}" >&2
  exit 1
fi

if [[ ! -d "${PARSER_VENV}" ]]; then
  echo "ERROR: Missing parser venv at ${PARSER_VENV}" >&2
  exit 1
fi

if [[ ! -x "${PARSE_LIVE_BIN}" ]]; then
  echo "ERROR: Missing executable parser CLI at ${PARSE_LIVE_BIN}" >&2
  exit 1
fi

if [[ "${DATA_ROOT}" = /* ]]; then
  DATA_ROOT_ABS="${DATA_ROOT}"
else
  DATA_ROOT_ABS="${REPO_ROOT}/${DATA_ROOT}"
fi

LIVE_POLL_INTERVAL="${LIVE_POLL_INTERVAL:-0.2}"
LIVE_FINDER_INSTANCE="${LIVE_FINDER_INSTANCE:-finder@live}"
LIVE_VS_INSTANCE="${LIVE_VS_INSTANCE:-vs@live}"
LIVE_FINDER_LOG="${LIVE_FINDER_LOG:-}"
LIVE_VS_LOG="${LIVE_VS_LOG:-}"

mkdir -p "${DATA_ROOT_ABS}"
DATA_ROOT_ABS="$(cd "${DATA_ROOT_ABS}" && pwd -P)"

resolve_path() {
  local input_path="$1"
  if [[ "${input_path}" = /* ]]; then
    printf '%s\n' "${input_path}"
  else
    printf '%s\n' "${REPO_ROOT}/${input_path}"
  fi
}

mkdir -p \
  "${DATA_ROOT_ABS}/live/raw" \
  "${DATA_ROOT_ABS}/live/archive" \
  "${DATA_ROOT_ABS}/live/state"

echo "DATA_ROOT=${DATA_ROOT_ABS}"

PIDS=()
cleanup_done=0

cleanup() {
  if [[ "${cleanup_done}" -eq 1 ]]; then
    return
  fi
  cleanup_done=1
  trap - INT TERM EXIT

  if ((${#PIDS[@]} > 0)); then
    kill "${PIDS[@]}" 2>/dev/null || true
    wait "${PIDS[@]}" 2>/dev/null || true
  fi
}

handle_signal() {
  cleanup
  exit 0
}

trap handle_signal INT TERM HUP
trap cleanup EXIT

started=0

if [[ -n "${LIVE_FINDER_LOG}" ]]; then
  finder_log_path="$(resolve_path "${LIVE_FINDER_LOG}")"
  if [[ -f "${finder_log_path}" ]]; then
    "${PARSE_LIVE_BIN}" \
      --algo finder \
      --dialect scfinder \
      --logfile "${finder_log_path}" \
      --data-root "${DATA_ROOT_ABS}" \
      --instance "${LIVE_FINDER_INSTANCE}" \
      --poll-interval "${LIVE_POLL_INTERVAL}" &
    PIDS+=("$!")
    started=$((started + 1))
    echo "Started finder parser: ${finder_log_path}"
  else
    echo "Skipped finder parser: missing file ${finder_log_path}"
  fi
else
  echo "Skipped finder parser: LIVE_FINDER_LOG is not set"
fi

if [[ -n "${LIVE_VS_LOG}" ]]; then
  vs_log_path="$(resolve_path "${LIVE_VS_LOG}")"
  if [[ -f "${vs_log_path}" ]]; then
    "${PARSE_LIVE_BIN}" \
      --algo vs \
      --dialect scvsmag \
      --logfile "${vs_log_path}" \
      --data-root "${DATA_ROOT_ABS}" \
      --instance "${LIVE_VS_INSTANCE}" \
      --poll-interval "${LIVE_POLL_INTERVAL}" &
    PIDS+=("$!")
    started=$((started + 1))
    echo "Started vs parser: ${vs_log_path}"
  else
    echo "Skipped vs parser: missing file ${vs_log_path}"
  fi
else
  echo "Skipped vs parser: LIVE_VS_LOG is not set"
fi

if [[ "${started}" -eq 0 ]]; then
  echo "ERROR: No valid live logs configured; nothing started." >&2
  exit 1
fi

echo "Started ${started} parser process(es). Press Ctrl-C to stop them cleanly."

set +e
wait
wait_status=$?
set -e

cleanup
exit "${wait_status}"
