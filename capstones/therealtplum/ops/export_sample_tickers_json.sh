#!/usr/bin/env bash
set -euo pipefail

# Match the other ops scripts exactly
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

TS() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Resolve project root:
# - If FOUNDRY90_ROOT is set, use that.
# - Otherwise, assume this script lives in capstones/therealtplum/ops
#   and go one level up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${FOUNDRY90_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# Default to 100 sample tickers unless overridden in the environment
SAMPLE_TICKERS_LIMIT="${SAMPLE_TICKERS_LIMIT:-100}"

echo "[export_sample_tickers] $(TS) PROJECT_ROOT=$PROJECT_ROOT"
echo "[export_sample_tickers] $(TS) SAMPLE_TICKERS_LIMIT=$SAMPLE_TICKERS_LIMIT"

cd "$PROJECT_ROOT"

# Load POLYGON_API_KEY from .env if it exists and isn't already set
if [ -f "$PROJECT_ROOT/.env" ] && [ -z "${POLYGON_API_KEY:-}" ]; then
  export $(grep -E "^POLYGON_API_KEY=" "$PROJECT_ROOT/.env" | xargs)
fi

# Sanity check
if ! command -v docker >/dev/null 2>&1; then
  echo "[export_sample_tickers] $(TS) ERROR: docker command not found on PATH." >&2
  exit 127
fi

# Ensure db + etl containers are up (db for Postgres, etl for the image/volume)
echo "[export_sample_tickers] $(TS) Ensuring db + etl services are running..."
docker compose up -d db etl

# Wait for Postgres to be ready inside the fmhub_db container
echo "[export_sample_tickers] $(TS) Waiting for Postgres to be ready..."
until docker exec fmhub_db pg_isready -U app -d fmhub >/dev/null 2>&1; do
  sleep 1
done
echo "[export_sample_tickers] $(TS) Postgres is ready."

# Path inside the container where we mounted apps/web/data
EXPORT_PATH="/export/web-data/sample_tickers.json"

echo "[export_sample_tickers] $(TS) Running exporter in etl container..."
echo "[export_sample_tickers] $(TS) SAMPLE_TICKERS_OUTPUT_PATH=$EXPORT_PATH"

docker compose run --rm \
  -e SAMPLE_TICKERS_OUTPUT_PATH="$EXPORT_PATH" \
  -e SAMPLE_TICKERS_LIMIT="$SAMPLE_TICKERS_LIMIT" \
  -e POLYGON_API_KEY="${POLYGON_API_KEY:-}" \
  etl python -m etl.export_sample_tickers_json

echo "[export_sample_tickers] $(TS) Export complete."
echo "[export_sample_tickers] $(TS) Host file should now be updated at:"
echo "  $PROJECT_ROOT/apps/web/data/sample_tickers.json"