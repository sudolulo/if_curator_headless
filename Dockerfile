# =============================================================================
# Stage 1: Base — platform-specific base image
# =============================================================================
# amd64:  NVIDIA CUDA runtime (for GPU acceleration)
# arm64:  Plain Ubuntu (no CUDA on ARM; CPU or media-kit only)

FROM --platform=$BUILDPLATFORM nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS base-amd64
FROM --platform=$BUILDPLATFORM ubuntu:22.04 AS base-arm64

# =============================================================================
# Stage 2: Build — install system packages + Python + uv
# =============================================================================
ARG TARGETARCH

FROM base-${TARGETARCH} AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv python3.12-dev \
    libgl1 libglib2.0-0 libxext6 git g++ tini \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.12 /usr/bin/python3

RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && cp /root/.local/bin/uv /usr/local/bin/uv

WORKDIR /app

# Copy project files first (for layer caching)
COPY pyproject.toml uv.lock* ./
COPY if_curator/ if_curator/
COPY entrypoint.sh scheduler.py ./

# Platform-conditional Python deps:
#   amd64:  install GPU extras (onnxruntime-gpu + CUDA torch)
#   arm64:  install CPU-only (onnxruntime + torch-cpu)
RUN if [ "$(uname -m)" = "x86_64" ]; then \
      uv sync --extra gpu --extra object && uv add croniter; \
    else \
      uv sync --extra object --no-binary torch && \
      UV_TORCH_INDEX_URL=https://download.pytorch.org/whl/cpu uv pip install torch && \
      uv add croniter; \
    fi \
    && uv cache clean

RUN chmod +x /app/entrypoint.sh

# =============================================================================
# Stage 3: Runtime — minimal image with appuser
# =============================================================================
FROM build AS runtime

RUN groupadd -g 568 apps && useradd -u 568 -g apps -m -s /bin/bash appuser \
    && mkdir -p /models/.insightface /models/huggingface \
    && chown -R appuser:apps /app /models

USER appuser
ENV HF_HOME=/models/huggingface INSIGHTFACE_HOME=/models

HEALTHCHECK CMD test -f /app/entrypoint.sh || exit 1
ENTRYPOINT ["tini", "--", "/app/entrypoint.sh"]

