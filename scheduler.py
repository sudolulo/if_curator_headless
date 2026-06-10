#!/usr/bin/env python3
"""
Simple in-container scheduler using croniter + sleep.
No cron daemon, no sudo, no root needed.
"""

import os
import sys
import subprocess
import time

try:
    from croniter import croniter
except ImportError:
    print("❌ croniter not installed. Run: uv add croniter")
    sys.exit(1)

SCHEDULE = os.environ["CRON_SCHEDULE"]
NOW = time.time()

cron = croniter(SCHEDULE, NOW)
next_run = cron.get_next(float)

while True:
    now = time.time()
    if now >= next_run:
        print(f"\n▶ [{time.strftime('%Y-%m-%d %H:%M:%S')}] Starting if-curator...")
        result = subprocess.run(["uv", "run", "if-curator"])
        if result.returncode == 0:
            print(f"✅ Run complete.")
        else:
            print(f"⚠️  Run exited with code {result.returncode}")

        next_run = cron.get_next(float)
        wait = next_run - time.time()
        if wait > 0:
            print(f"▶ Next run: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(next_run))} (in {int(wait // 3600)}h {int((wait % 3600) // 60)}m)")
        continue

    wait = next_run - now
    print(f"▶ Next run: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(next_run))} (in {int(wait // 3600)}h {int((wait % 3600) // 60)}m)")
    time.sleep(min(wait, 3600))  # Check every hour at most, or sooner if needed

