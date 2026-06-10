#!/bin/bash
set -e

# --- Configuration ---
COMMIT_MSG="automated update: $(date '+%Y-%m-%d %H:%M:%S')"

# --- Git Sync ---
echo "💾 Committing and pushing changes to GitHub..."

git add .

# Only proceed if there are actual changes to commit
if ! git diff-index --quiet HEAD --; then
    git commit -m "$COMMIT_MSG"
    git push
    echo "✅ Changes pushed. GitHub Actions will now build and deploy the image."
else
    echo "ℹ️  No changes detected; nothing to push."
fi

