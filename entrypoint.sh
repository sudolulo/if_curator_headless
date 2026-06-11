#!/bin/bash
set -e
export PYTHONUNBUFFERED=1

check_models() {
    echo "📦 Checking models..."
    # Paths updated to point to persistent root /models
    if [ -d "/models/.insightface/models/buffalo_l" ]; then
        echo "  ✅ InsightFace Buffalo_L: present"
    else
        echo "  ⬇️  InsightFace Buffalo_L: downloading..."
    fi
    echo "🚀 Starting if-curator..."
}

AUTO="${AUTO_MODE:-false}"
if [ "$AUTO" != "true" ] && [ ! -t 0 ]; then
    echo "❌ AUTO_MODE must be true for non-interactive execution."
    exit 1
fi

check_models
if [ -n "${CRON_SCHEDULE:-}" ]; then
    echo "▶ Switching to scheduled mode..."
    exec uv run python3 /app/scheduler.py
else
    echo "▶ Running once..."
    uv run python -m if_curator.cli
fi

