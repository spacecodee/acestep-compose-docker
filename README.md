# acestep-compose-docker

Docker Compose wrapper to deploy [ACE-Step 1.5](https://github.com/ace-step/ACE-Step-1.5) for AI music generation on GPU-enabled environments like Lightning.ai Studios.

## Overview

This repository provides a production-friendly container setup for ACE-Step 1.5 with:

- NVIDIA GPU passthrough (CUDA 12.8 runtime)
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

## flash-attn (Optional or Required)

No OS change is required. You can keep Ubuntu 22.04 and choose one of these modes in `.env`:

- `FLASH_ATTN_MODE=off`: never install `flash-attn`.
- `FLASH_ATTN_MODE=auto` (default): install only if a compatible binary wheel exists.
- `FLASH_ATTN_MODE=required`: fail the build if `flash-attn` cannot be installed.

If you use `FLASH_ATTN_MODE=required`, also set:

- `CUDA_VARIANT=devel`

This uses the CUDA devel base image so source builds are possible when no wheel is available.

## Run Modes

Set `RUN_MODE` in `.env`:

| RUN_MODE | Behavior | Exposed Endpoint(s) |
| --- | --- | --- |
| `gradio` | Runs Gradio UI only | `http://localhost:${PORT}` |
| `api` | Runs API service only | `http://localhost:${ACESTEP_API_PORT}` |
| `both` | Runs API in background + Gradio in foreground | `http://localhost:${PORT}` and `http://localhost:${ACESTEP_API_PORT}` |

## ACE-Step .env Compatibility

ACE-Step already supports a rich `.env` contract upstream (for Gradio, API, and model behavior). This wrapper passes your `.env` directly into the container, so you can use official variables such as:

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
- `./outputs:/app/outputs`
  - Persists generated audio outputs.

## Lightning.ai Notes

- Open inbound ports `7860` (Gradio) and `8000` (API) in your Lightning.ai Studio.
- If you override ports in `.env`, open `PORT` and `ACESTEP_API_PORT` values instead.
- GPU is automatically consumed through the NVIDIA runtime in `docker-compose.yml`.
- For CPU validation in Studio or local dev, use the override compose file described above.
