#!/usr/bin/env bash
set -euo pipefail

# Match the other ops scripts exactly
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Resolve project root:
# - If FOUNDRY90_ROOT is set, use that.
# - Otherwise, assume this script lives in capstones/therealtplum/ops
#   and go one level up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${FOUNDRY90_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

cd "$PROJECT_ROOT"

echo "[rebuild_web_with_git] Detecting current git HEAD..."
export GIT_COMMIT="$(git rev-parse HEAD)"
export GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

echo "[rebuild_web_with_git] GIT_COMMIT=$GIT_COMMIT"
echo "[rebuild_web_with_git] GIT_BRANCH=$GIT_BRANCH"

echo "[rebuild_web_with_git] Bringing stack down..."
docker compose down

echo "[rebuild_web_with_git] Rebuilding web (no cache)..."
docker compose build --no-cache web

echo "[rebuild_web_with_git] Bringing stack up (detached)..."
docker compose up -d

echo "[rebuild_web_with_git] Done. Local web should now report:"
echo "  /api/version → commit=$GIT_COMMIT, branch=$GIT_BRANCH"