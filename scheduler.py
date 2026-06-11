#!/usr/bin/env python3
import os
import sys
import subprocess
import time
from croniter import croniter

SCHEDULE = os.environ.get("CRON_SCHEDULE", "0 3 * * SUN")
RUN_ENV = {**os.environ, "PYTHONUNBUFFERED": "1"}

def run_curator():
    print(f"\n▶ [{time.strftime('%Y-%m-%d %H:%M:%S')}] Starting if-curator...", flush=True)
    subprocess.run(["uv", "run", "python", "-m", "if_curator.cli"], env=RUN_ENV)

now = time.time()
cron = croniter(SCHEDULE, now)
next_run = cron.get_next(float)

print(f"▶ Scheduler active. Next run: {time.ctime(next_run)}")
while True:
    if time.time() >= next_run:
        run_curator()
        next_run = cron.get_next(float)
    time.sleep(60)

