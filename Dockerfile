ARG CUDA_VARIANT=runtime
FROM nvidia/cuda:12.8.0-cudnn-${CUDA_VARIANT}-ubuntu22.04

ARG FLASH_ATTN_MODE=auto

ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    GRADIO_SERVER_NAME=0.0.0.0 \
    GRADIO_SERVER_PORT=7860 \
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

WORKDIR /app

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        python3-pip \
        build-essential \
        ninja-build \
        git \
        ffmpeg \
        libsndfile1 \
        curl \
        wget \
        ca-certificates \
        gnupg; \
    add-apt-repository ppa:deadsnakes/ppa; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        python3.11 \
        python3.11-dev; \
    ln -sf /usr/bin/python3.11 /usr/local/bin/python; \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py; \
    python /tmp/get-pip.py; \
    ln -sf /usr/local/bin/pip /usr/local/bin/pip3; \
    python -m pip install --no-cache-dir --upgrade pip setuptools wheel; \
    git clone https://github.com/ace-step/ACE-Step-1.5.git .; \
    python -m pip install --no-cache-dir \
        torch==2.10.0+cu128 \
        torchvision==0.25.0+cu128 \
        torchaudio==2.10.0+cu128 \
        --extra-index-url https://download.pytorch.org/whl/cu128; \
    # Exclude macOS-only deps and optional flash-attn from base Linux install.
    exclude_re='^[[:space:]]*(mlx|mlx-lm|flash-attn|flash_attn)'; \
    exclude_re="${exclude_re}([<>=!~].*)?$"; \
    grep -Ev "$exclude_re" requirements.txt > /tmp/requirements.linux.txt; \
    python -m pip install --no-cache-dir -r /tmp/requirements.linux.txt --no-deps; \
    python -m pip install --no-cache-dir -r /tmp/requirements.linux.txt; \
    if [ -d "acestep/third_parts/nano-vllm" ]; then \
        python -m pip install --no-cache-dir -e acestep/third_parts/nano-vllm; \
    fi; \
    if [ "$(uname -s)" = "Linux" ]; then \
        python -m pip install --no-cache-dir "triton>=3.0.0"; \
    fi; \
    if [ "$(uname -s)" = "Linux" ] && [ "$(uname -m)" = "x86_64" ]; then \
        case "${FLASH_ATTN_MODE}" in \
            off) \
                echo "Skipping flash-attn by configuration (FLASH_ATTN_MODE=off)."; \
                ;; \
            auto) \
                python -m pip install --no-cache-dir --only-binary=:all: flash-attn || \
                    echo "Skipping flash-attn (no compatible binary wheel for this platform)."; \
                ;; \
            required) \
                python -m pip install --no-cache-dir --no-build-isolation flash-attn; \
                ;; \
            *) \
                echo "Invalid FLASH_ATTN_MODE=${FLASH_ATTN_MODE}. Use: off, auto, required." >&2; \
                exit 1; \
                ;; \
        esac; \
    fi; \
    rm -rf /var/lib/apt/lists/* /tmp/get-pip.py /tmp/requirements.linux.txt

COPY scripts ./scripts
RUN chmod +x /app/scripts/entrypoint.sh /app/scripts/healthcheck.sh

EXPOSE 7860 8000

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
