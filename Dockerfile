# ── Platform-conditional base ─────────────────────────────────────────────
#   amd64:  NVIDIA CUDA 13.3 (GPU acceleration when available, CPU fallback)
#   arm64:  Ubuntu 24.04 (CPU-only; no CUDA on ARM)

FROM --platform=$BUILDPLATFORM nvidia/cuda:13.3.0-cudnn-runtime-ubuntu22.04 AS base-amd64
FROM --platform=$BUILDPLATFORM ubuntu:24.04 AS base-arm64

# ── Build stage ───────────────────────────────────────────────────────────
ARG TARGETARCH

FROM base-${TARGETARCH} AS build

ENV DEBIAN_FRONTEND=noninteractive

# Both bases use Ubuntu 22.04 or 24.04 — neither has python3.13 natively.
# Add the deadsnakes PPA using curl+gpg (no gpg-agent, safe under QEMU).
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    && curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xBA6932366A755776" \
        | gpg --dearmor > /usr/share/keyrings/deadsnakes-archive-keyring.gpg \
    && . /etc/os-release \
    && echo "deb [signed-by=/usr/share/keyrings/deadsnakes-archive-keyring.gpg] https://ppa.launchpad.net/deadsnakes/ppa/ubuntu ${VERSION_CODENAME} main" \
        > /etc/apt/sources.list.d/deadsnakes.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    python3.13 python3.13-venv python3.13-dev \
    libgl1 libglib2.0-0 libxext6 g++ \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.13 /usr/bin/python3

RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && cp /root/.local/bin/uv /usr/local/bin/uv

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev \
    && uv cache clean

COPY winnow/ winnow/
COPY entrypoint.sh scheduler.py ./
RUN chmod +x /app/entrypoint.sh

# ── Runtime stage ─────────────────────────────────────────────────────────
#   Starts fresh from the base image — excludes build tools (g++,
#   python3.13-dev, curl, gnupg) that are not needed at runtime.

FROM base-${TARGETARCH} AS runtime

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    tini \
    && curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xBA6932366A755776" \
        | gpg --dearmor > /usr/share/keyrings/deadsnakes-archive-keyring.gpg \
    && . /etc/os-release \
    && echo "deb [signed-by=/usr/share/keyrings/deadsnakes-archive-keyring.gpg] https://ppa.launchpad.net/deadsnakes/ppa/ubuntu ${VERSION_CODENAME} main" \
        > /etc/apt/sources.list.d/deadsnakes.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    python3.13 python3.13-venv \
    libgl1 libglib2.0-0 libxext6 \
    && apt-get purge -y --auto-remove curl gnupg \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.13 /usr/bin/python3

# Copy app (with .venv) and uv from build stage
COPY --from=build /app /app
COPY --from=build /usr/local/bin/uv /usr/local/bin/uv

# Expose CUDA/cuDNN libraries from pip packages so onnxruntime-gpu
# can find libcublasLt.so.12 and libcudnn.so.9 at runtime (amd64 only)
ENV LD_LIBRARY_PATH="/app/.venv/lib/python3.13/site-packages/nvidia/cudnn/lib:/app/.venv/lib/python3.13/site-packages/nvidia/cuda_runtime/lib:${LD_LIBRARY_PATH}"

RUN groupadd -g 568 apps && useradd -u 568 -g apps -m -s /bin/bash appuser \
    && mkdir -p /models/.insightface /models/huggingface \
    && chown -R appuser:apps /app /models

WORKDIR /app
USER appuser
ENV HF_HOME=/models/huggingface INSIGHTFACE_HOME=/models

HEALTHCHECK CMD test -f /app/entrypoint.sh || exit 1
ENTRYPOINT ["tini", "--", "/app/entrypoint.sh"]
