ARG CUDA_BASE_VERSION=12.8.0
ARG CUDA_VARIANT=runtime
FROM nvidia/cuda:${CUDA_BASE_VERSION}-cudnn-${CUDA_VARIANT}-ubuntu22.04

ARG CUDA_BASE_VERSION

ARG INSTALL_BITSANDBYTES=true
ARG INSTALL_TORCHCODEC_CUDA13_RUNTIME=true

ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    GRADIO_SERVER_NAME=0.0.0.0 \
    GRADIO_SERVER_PORT=7860 \
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
    PATH=/root/.local/bin:${PATH} \
    UV_LINK_MODE=copy \
    UV_PYTHON_PREFERENCE=managed \
    UV_PYTHON_DOWNLOADS=automatic \
    UV_PROJECT_ENVIRONMENT=/app/.venv

WORKDIR /app

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        ninja-build \
        git \
        ffmpeg \
        libsndfile1 \
        curl \
        wget \
        ca-certificates; \
    curl -LsSf https://astral.sh/uv/install.sh | sh; \
    git clone https://github.com/ace-step/ACE-Step-1.5.git .; \
    uv sync --frozen || uv sync; \
    if [ "${INSTALL_BITSANDBYTES}" = "true" ]; then \
        uv pip install --python /app/.venv/bin/python bitsandbytes; \
    fi; \
    if [ "${INSTALL_TORCHCODEC_CUDA13_RUNTIME}" = "true" ]; then \
        cuda_major="${CUDA_BASE_VERSION%%.*}"; \
        if [ "${cuda_major}" -lt 13 ]; then \
            uv pip install --python /app/.venv/bin/python \
                nvidia-cuda-runtime \
                nvidia-cuda-nvrtc \
                nvidia-nvjitlink; \
        else \
            echo "Skipping extra CUDA13 runtime pip packages (CUDA base already ${CUDA_BASE_VERSION})."; \
        fi; \
    fi; \
    rm -rf /var/lib/apt/lists/*

COPY scripts ./scripts
RUN chmod +x /app/scripts/entrypoint.sh /app/scripts/healthcheck.sh

EXPOSE 7860 8000

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
