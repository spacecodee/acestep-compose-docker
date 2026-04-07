# acestep-compose-docker

Docker Compose wrapper to deploy [ACE-Step 1.5](https://github.com/ace-step/ACE-Step-1.5) for AI music generation on GPU-enabled environments like Lightning.ai Studios.

## Overview

This repository provides a production-friendly container setup for ACE-Step 1.5 with:

- NVIDIA GPU passthrough (CUDA 12.8 runtime)
- Official ACE-Step dependency flow via `uv sync`
- Gradio UI and REST API support
- Persistent model cache and output storage through bind mounts
- Run-mode switching via environment variables (`gradio`, `api`, `both`)

## Requirements

- Docker 24+
- Docker Compose v2+
- NVIDIA Container Toolkit installed and configured
- NVIDIA driver compatible with CUDA 12.8 runtime

## Quick Start

1. Copy environment defaults:

	```bash
	cp .env.example .env
	```

2. Build and start in detached mode:

	```bash
	docker compose up --build -d
	```

3. Open Gradio:

	- http://localhost:7860 (or your configured `PORT`)

On first run, model downloads can be large (roughly 10-20 GB). The `./models` volume avoids re-downloading across restarts.

## CPU-only Testing

Use the CPU override file for environments without a GPU:

```bash
docker compose -f docker-compose.yml -f docker-compose.cpu.yml up --build
```

## Dependency Installation (Official ACE-Step Flow)

This wrapper now follows ACE-Step docs for Linux/macOS inside the container:

- Install `uv`
- Run `uv sync` to resolve and install dependencies
- Start services with `uv run ...`

By default, the image also installs `bitsandbytes` (controlled by `INSTALL_BITSANDBYTES=true`) so training paths can use 8-bit optimizers instead of falling back to standard AdamW.

This avoids duplicate/conflicting manual installs from custom `pip` steps and stays aligned with upstream.

## Startup Model Pre-Download

On container startup, this wrapper can pre-download models before launching services.

Default behavior (equivalent commands):

```bash
uv run acestep-download --model acestep-v15-xl-base
uv run acestep-download --model acestep-5Hz-lm-4B
```

Configure in `.env`:

- `ACESTEP_AUTO_DOWNLOAD_MODELS=true|false`
- `ACESTEP_PRELOAD_MODELS=acestep-v15-xl-base,acestep-5Hz-lm-4B`
- `ACESTEP_PRELOAD_BACKGROUND=true|false` (recommended `true` on Lightning so UI starts sooner)
- `ACESTEP_PRELOAD_FATAL=true|false` (when `true`, startup fails if preload fails)
- `ACESTEP_REPAIR_INVALID_MODELS=true|false` (force re-download if a model folder exists but is invalid/incomplete)

Downloaded checkpoints are persisted in `./checkpoints`.

At runtime, Gradio starts with `ACESTEP_CONFIG_PATH` and `ACESTEP_LM_MODEL_PATH` as default selected models.

## flash-attn

No OS change is required. You can keep Ubuntu 22.04 and choose one of these modes in `.env`:

- Keep `ACESTEP_USE_FLASH_ATTENTION=true` in `.env` (enabled by default).
- If your platform needs source compilation for GPU dependencies, set `CUDA_VARIANT=devel`.

ACE-Step auto-detects whether `flash_attn` is actually available and falls back safely when it is not.

## Run Modes

Set `RUN_MODE` in `.env`:

| RUN_MODE | Behavior | Exposed Endpoint(s) |
| --- | --- | --- |
| `gradio` | Runs Gradio UI only | `http://localhost:${PORT}` |
| `api` | Runs API service only | `http://localhost:${ACESTEP_API_PORT}` |
| `both` | Runs API in background + Gradio in foreground | `http://localhost:${PORT}` and `http://localhost:${ACESTEP_API_PORT}` |

## ACE-Step .env Compatibility

ACE-Step already supports a rich `.env` contract upstream (for Gradio, API, and model behavior). This wrapper passes your `.env` directly into the container, so you can use official variables such as:

- The global `.env` in this wrapper is also mounted as `/app/.env` inside the container, so ACE-Step's native `.env` loader reads the same values.

- `ACESTEP_CONFIG_PATH`
- `ACESTEP_LM_MODEL_PATH`
- `ACESTEP_INIT_LLM`
- `ACESTEP_DOWNLOAD_SOURCE`
- `ACESTEP_API_KEY`
- `PORT`
- `SERVER_NAME`
- `LANGUAGE`
- `ACESTEP_API_HOST`
- `ACESTEP_API_PORT`

This keeps the Docker Compose setup aligned with ACE-Step documentation while still adding container-specific control via `RUN_MODE`.

## Volumes

- `./models:/root/.cache/huggingface`
  - Persists HuggingFace model cache between container restarts/rebuilds.
- `./checkpoints:/app/checkpoints`
	- Persists ACE-Step model checkpoints and avoids repeated startup downloads.
- `./outputs:/app/outputs`
  - Persists generated audio outputs.

## Lightning.ai Notes

- Open inbound ports `7860` (Gradio) and `8000` (API) in your Lightning.ai Studio.
- If you override ports in `.env`, open `PORT` and `ACESTEP_API_PORT` values instead.
- Keep `HOST_BIND_IP=0.0.0.0` so Docker publishes ports on all interfaces (required for public Cloudspaces URLs).
- GPU is automatically consumed through the NVIDIA runtime in `docker-compose.yml`.
- For CPU validation in Studio or local dev, use the override compose file described above.
- If you get an initial HTTP 502 on the public URL, check container logs and wait for startup downloads/model initialization to finish before retrying.
- Browser warning `Permissions-Policy: Unrecognized feature 'browsing-topics'` is proxy/browser related and can be ignored.
