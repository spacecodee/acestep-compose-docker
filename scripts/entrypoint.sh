#!/usr/bin/env bash
set -euo pipefail

RUN_MODE="${RUN_MODE:-gradio}"
GRADIO_HOST="${SERVER_NAME:-${GRADIO_SERVER_NAME:-0.0.0.0}}"
GRADIO_PORT="${PORT:-${GRADIO_SERVER_PORT:-7860}}"
API_HOST="${ACESTEP_API_HOST:-0.0.0.0}"
API_PORT="${ACESTEP_API_PORT:-8000}"
AUTO_DOWNLOAD_MODELS="${ACESTEP_AUTO_DOWNLOAD_MODELS:-true}"
PRELOAD_MODELS="${ACESTEP_PRELOAD_MODELS:-acestep-v15-xl-base,acestep-5Hz-lm-4B}"
PRELOAD_BACKGROUND="${ACESTEP_PRELOAD_BACKGROUND:-true}"
PRELOAD_FATAL="${ACESTEP_PRELOAD_FATAL:-false}"
CHECKPOINTS_DIR="${ACESTEP_CHECKPOINTS_DIR:-/app/checkpoints}"
REPAIR_INVALID_MODELS="${ACESTEP_REPAIR_INVALID_MODELS:-true}"
DEFAULT_DIT_MODEL="${ACESTEP_CONFIG_PATH:-acestep-v15-turbo}"
DEFAULT_LM_MODEL="${ACESTEP_LM_MODEL_PATH:-acestep-5Hz-lm-1.7B}"

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

  if model_looks_valid "${model}"; then
    echo "Startup model already present: ${model}"
    return 0
  fi

  if [ -d "${model_dir}" ] && is_true "${REPAIR_INVALID_MODELS}"; then
    echo "Startup model appears incomplete/invalid, forcing re-download: ${model}"
    if ! uv run --no-sync acestep-download --model "${model}" --force; then
      echo "Warning: Failed to re-download startup model: ${model}" >&2
      return 1
    fi
  else
    echo "Downloading startup model: ${model}"
    if ! uv run --no-sync acestep-download --model "${model}"; then
      echo "Warning: Failed to download startup model: ${model}" >&2
      return 1
    fi
  fi

  if ! model_looks_valid "${model}"; then
    echo "Warning: Startup model still looks invalid after download: ${model}" >&2
    return 1
  fi

  return 0
}

model_has_weights() {
  local model_dir="$1"
  compgen -G "${model_dir}/*.safetensors" > /dev/null || \
    compgen -G "${model_dir}/*.bin" > /dev/null || \
    compgen -G "${model_dir}/*.pt" > /dev/null
}

model_looks_valid() {
  local model="$1"
  local model_dir="${CHECKPOINTS_DIR}/${model}"

  [ -d "${model_dir}" ] || return 1

  if [[ "${model}" == acestep-v15-* ]]; then
    [ -f "${model_dir}/config.json" ] || return 1
    grep -q '"model_type"[[:space:]]*:' "${model_dir}/config.json" || return 1
    [ -f "${model_dir}/silence_latent.pt" ] || return 1
    model_has_weights "${model_dir}" || return 1
    return 0
  fi

  model_has_weights "${model_dir}"
}

download_startup_models() {
  local model
  local models_raw
  local failures=0

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
    if ! download_model_if_missing "${model}"; then
      failures=$((failures + 1))
    fi
  done

  if [ "${failures}" -gt 0 ]; then
    if is_true "${PRELOAD_FATAL}"; then
      echo "Startup model preload failed for ${failures} model(s) and PRELOAD_FATAL is enabled." >&2
      return 1
    fi
    echo "Startup model preload had ${failures} failure(s); continuing service startup." >&2
  fi

  return 0
}

start_gradio() {
  uv run --no-sync acestep \
    --server-name "${GRADIO_HOST}" \
    --port "${GRADIO_PORT}" \
    --config_path "${DEFAULT_DIT_MODEL}" \
    --lm_model_path "${DEFAULT_LM_MODEL}"
}

start_api() {
  uv run --no-sync acestep-api --host "${API_HOST}" --port "${API_PORT}"
}

echo "Starting ACE-Step 1.5 in mode: ${RUN_MODE} (Gradio ${GRADIO_HOST}:${GRADIO_PORT}, API ${API_HOST}:${API_PORT})"

if is_true "${PRELOAD_BACKGROUND}" && ! is_true "${PRELOAD_FATAL}"; then
  echo "Starting startup model preload in background."
  download_startup_models &
else
  download_startup_models
fi

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
