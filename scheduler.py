#!/usr/bin/env python3
"""
Simple in-container scheduler using croniter + sleep.
No cron daemon, no sudo, no root needed.
"""

import os
import sys
import subprocess
import time
from pathlib import Path

try:
    from croniter import croniter
except ImportError:
    print("❌ croniter not installed. Run: uv add croniter")
    sys.exit(1)

SCHEDULE = os.environ["CRON_SCHEDULE"]
MODELS_DIR = os.environ.get("HF_HOME", "/models/huggingface")
INSIGHTFACE_DIR = os.environ.get("INSIGHTFACE_HOME", "/models/insightface")

# Ensure all subprocess output appears in docker logs
RUN_ENV = {**os.environ, "PYTHONUNBUFFERED": "1"}


def check_models():
    """Log model download status before each run."""
    print("📦 Checking models...", flush=True)

    buffalo = Path(INSIGHTFACE_DIR) / "models" / "buffalo_l"
    if buffalo.exists():
        print("  ✅ InsightFace Buffalo_L: downloaded", flush=True)
    else:
        print("  ⬇️  InsightFace Buffalo_L: downloading (~300MB)...", flush=True)

    hf_hub = Path(MODELS_DIR) / "hub"
    if hf_hub.exists() and any(hf_hub.iterdir()):
        print("  ✅ HuggingFace models: downloaded", flush=True)
    else:
        print("  ⬇️  HuggingFace models: downloading (SigLIP ~1GB, YOLOv9c ~500MB)...", flush=True)

    print("🚀 Starting if-curator...", flush=True)


def calc_time_display(seconds):
    """Convert seconds to human-readable time."""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    if hours > 0:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


NOW = time.time()
cron = croniter(SCHEDULE, NOW)
next_run = cron.get_next(float)

while True:
    now = time.time()
    if now >= next_run:
        print(f"\n▶ [{time.strftime('%Y-%m-%d %H:%M:%S')}] Starting if-curator...", flush=True)
        check_models()
        result = subprocess.run(
            ["uv", "run", "if-curator"],
            env=RUN_ENV,
        )
        if result.returncode == 0:
            print("✅ Run complete.", flush=True)
        else:
            print(f"⚠️  Run exited with code {result.returncode}", flush=True)

        next_run = cron.get_next(float)
        wait = next_run - time.time()
        if wait > 0:
            print(f"▶ Next run: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(next_run))} (in {calc_time_display(wait)})", flush=True)
        continue

    wait = next_run - now
    print(f"▶ Next run: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(next_run))} (in {calc_time_display(wait)})", flush=True)
    time.sleep(min(wait, 3600))

