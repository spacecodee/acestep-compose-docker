#!/usr/bin/env bash
set -euo pipefail

RUN_MODE="${RUN_MODE:-gradio}"
GRADIO_HOST="${SERVER_NAME:-${GRADIO_SERVER_NAME:-0.0.0.0}}"
GRADIO_PORT="${PORT:-${GRADIO_SERVER_PORT:-7860}}"
API_HOST="${ACESTEP_API_HOST:-0.0.0.0}"
API_PORT="${ACESTEP_API_PORT:-8000}"

start_gradio() {
  uv run --no-sync acestep --server-name "${GRADIO_HOST}" --port "${GRADIO_PORT}"
}

start_api() {
  uv run --no-sync acestep-api --host "${API_HOST}" --port "${API_PORT}"
}

echo "Starting ACE-Step 1.5 in mode: ${RUN_MODE} (Gradio ${GRADIO_HOST}:${GRADIO_PORT}, API ${API_HOST}:${API_PORT})"

case "${RUN_MODE}" in
  gradio)
    start_gradio
    ;;
  api)
    start_api
    ;;
  both)
    start_api &
    API_PID=$!
    trap 'kill "${API_PID}" 2>/dev/null || true' EXIT INT TERM
    start_gradio
    ;;
  *)
    echo "Invalid RUN_MODE: ${RUN_MODE}. Expected: gradio, api, both." >&2
    exit 1
    ;;
esac
