#!/usr/bin/env bash
set -euo pipefail

RUN_MODE="${RUN_MODE:-gradio}"
GRADIO_HOST="${SERVER_NAME:-${GRADIO_SERVER_NAME:-0.0.0.0}}"
GRADIO_PORT="${PORT:-${GRADIO_SERVER_PORT:-7860}}"
API_HOST="${ACESTEP_API_HOST:-0.0.0.0}"
API_PORT="${ACESTEP_API_PORT:-8000}"
AUTO_DOWNLOAD_MODELS="${ACESTEP_AUTO_DOWNLOAD_MODELS:-true}"
PRELOAD_MODELS="${ACESTEP_PRELOAD_MODELS:-acestep-v15-xl-base,acestep-5Hz-lm-4B}"
CHECKPOINTS_DIR="${ACESTEP_CHECKPOINTS_DIR:-/app/checkpoints}"

is_true() {
  case "${1,,}" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

trim_spaces() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

download_model_if_missing() {
  local model="$1"
  local model_dir="${CHECKPOINTS_DIR}/${model}"

  if [ -d "${model_dir}" ]; then
    echo "Startup model already present: ${model}"
    return 0
  fi

  echo "Downloading startup model: ${model}"
  uv run --no-sync acestep-download --model "${model}"
}

download_startup_models() {
  local model
  local models_raw

  if ! is_true "${AUTO_DOWNLOAD_MODELS}"; then
    echo "Startup model downloads disabled (ACESTEP_AUTO_DOWNLOAD_MODELS=${AUTO_DOWNLOAD_MODELS})."
    return 0
  fi

  mkdir -p "${CHECKPOINTS_DIR}"
  models_raw="${PRELOAD_MODELS}"

  IFS=',' read -r -a models <<< "${models_raw}"
  for model in "${models[@]}"; do
    model="$(trim_spaces "${model}")"
    [ -z "${model}" ] && continue
    download_model_if_missing "${model}"
  done
}

start_gradio() {
  uv run --no-sync acestep --server-name "${GRADIO_HOST}" --port "${GRADIO_PORT}"
}

start_api() {
  uv run --no-sync acestep-api --host "${API_HOST}" --port "${API_PORT}"
}

echo "Starting ACE-Step 1.5 in mode: ${RUN_MODE} (Gradio ${GRADIO_HOST}:${GRADIO_PORT}, API ${API_HOST}:${API_PORT})"
download_startup_models

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
