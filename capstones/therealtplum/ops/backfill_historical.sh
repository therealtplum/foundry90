#!/usr/bin/env bash
set -euo pipefail

# Make sure common locations are on PATH (for docker, etc.)
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

TS() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Root of the therealtplum capstone.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${FOUNDRY90_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if ! command -v docker >/dev/null 2>&1; then
  echo "[FMHub] $(TS) ERROR: docker command not found on PATH."
  exit 127
fi

cd "$PROJECT_ROOT"

echo "[FMHub] $(TS) Starting historical data backfill..."

# --- Ensure DB container is up and ready ---
echo "[FMHub] $(TS) Ensuring Postgres container is running..."
docker compose up -d db

echo "[FMHub] $(TS) Waiting for Postgres to be ready..."
until docker exec fmhub_db pg_isready -U app -d fmhub >/dev/null 2>&1; do
  sleep 1
done

# --- Backfill historical data ---
echo "[FMHub] $(TS) Running polygon_backfill_historical..."
docker compose run --rm etl python -m etl.polygon.polygon_backfill_historical

echo "[FMHub] $(TS) Historical backfill completed."
