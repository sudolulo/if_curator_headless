# if-curator-headless

Headless fork of [if-curator](https://github.com/ds-sebastian/if_curator) with automatic Frigate face training upload and Docker support.

## What Changed

Only `cli.py` was modified. Three functions were added, one was changed. All other modules (`config.py`, `immich_api.py`, `embeddings.py`, `diversity.py`, `image_processing.py`, `quality.py`, `cache.py`, `logging.py`) are identical to upstream.

### New functions in `cli.py`

**`auto_configure(people)`** — Non-interactive replacement for `interactive_configure()`. Fetches all named people from Immich, filters by env vars, and iterates through each without prompts.

**`_resolve_strategy(strategy, has_embedding)`** — Non-interactive replacement for `_get_strategy_choice()`. Maps `STRATEGY` env var to `(limit, selection_mode)` without prompting.

**`upload_to_frigate(jobs)`** — POSTs face crops to Frigate's `/api/faces/train/{name}/classify` API. Skipped if `FRIGATE_URL` is not set.

### Modified function: `main()`

- Added `AUTO_MODE` env var check to branch between `auto_configure()` and `interactive_configure()`
- Confirmation prompt skipped when `AUTO_MODE=true`
- `upload_to_frigate(jobs)` called after `execute_jobs()`

## New Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `AUTO_MODE` | `false` | Enable headless mode |
| `FRIGATE_URL` | *(empty)* | Frigate URL for auto-upload (skipped if empty) |
| `TRAINING_MODE` | `face` | `face` or `object` |
| `STRATEGY` | `auto` | `auto`, `standard`, or `broad` |
| `SKIP_PEOPLE` | *(empty)* | Comma-separated people to skip |
| `ONLY_PEOPLE` | *(empty)* | Comma-separated people to process (whitelist) |
| `MIN_FACE_COUNT` | `3` | Skip people with fewer assets |
| `OBJECT_CLASS` | `dog` | Object class (only with `TRAINING_MODE=object`) |

All original if-curator variables (`IMMICH_URL`, `API_KEY`, `FORCE_CPU`, `OUTPUT_DIR`, etc.) still work. See the [upstream README](https://github.com/ds-sebastian/if_curator) for those.

## Docker

Upstream has no Dockerfile. This fork adds Docker support with NVIDIA GPU acceleration and TrueNAS-compatible user mapping.

### Dockerfile

```dockerfile
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update &amp;&amp; apt-get install -y --no-install-recommends \
    software-properties-common \
    &amp;&amp; add-apt-repository ppa:deadsnakes/ppa -y \
    &amp;&amp; apt-get update &amp;&amp; apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    libgl1 \
    libglib2.0-0 \
    libxext6 \
    git \
    curl \
    g++ \
    &amp;&amp; rm -rf /var/lib/apt/lists/* \
    &amp;&amp; ln -sf /usr/bin/python3.12 /usr/bin/python \
    &amp;&amp; ln -sf /usr/bin/python3.12 /usr/bin/python3

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH=&quot;/root/.local/bin:${PATH}&quot;

WORKDIR /app

RUN git clone --depth 1 https://github.com/sudolulo/if_curator_headless.git . \
    &amp;&amp; uv sync --extra gpu \
    &amp;&amp; uv cache clean

RUN groupadd -g 568 apps \
    &amp;&amp; useradd -u 568 -g apps -m -s /bin/bash appuser \
    &amp;&amp; chown -R appuser:apps /app

USER appuser

ENV FORCE_CPU=false \
    HF_HOME=/models/huggingface \
    INSIGHTFACE_HOME=/models/insightface

ENTRYPOINT [&quot;uv&quot;, &quot;run&quot;, &quot;if-curator&quot;]
