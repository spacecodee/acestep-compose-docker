#!/usr/bin/env bash
set -euo pipefail

RUN_MODE="${RUN_MODE:-gradio}"
GRADIO_PORT="${PORT:-${GRADIO_SERVER_PORT:-7860}}"
API_PORT="${ACESTEP_API_PORT:-8000}"

check_gradio() {
  curl -fsS "http://localhost:${GRADIO_PORT}" >/dev/null
}

check_api() {
  if curl -fsS "http://localhost:${API_PORT}/health" >/dev/null; then
    return 0
  fi
  curl -fsS "http://localhost:${API_PORT}/docs" >/dev/null
}

case "${RUN_MODE}" in
  gradio)
    check_gradio
    ;;
  api)
    check_api
    ;;
  both)
    check_gradio
    check_api
    ;;
  *)
    echo "Invalid RUN_MODE: ${RUN_MODE}" >&2
    exit 1
    ;;
esac

exit 0
