#!/usr/bin/env bash
set -euo pipefail

# Make sure common locations are on PATH (for docker, etc.)
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

TS() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Root of the therealtplum capstone.
# Resolution order:
# 1. If FOUNDRY90_ROOT is set, use that.
# 2. Otherwise, assume this script lives in capstones/therealtplum/ops and go one level up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${FOUNDRY90_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if ! command -v docker >/dev/null 2>&1; then
  echo "[FMHub] $(TS) ERROR: docker command not found on PATH."
  exit 127
fi

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "[FMHub] $(TS) ERROR: Project root not found at: $PROJECT_ROOT"
  exit 1
fi

cd "$PROJECT_ROOT"

echo "[FMHub] $(TS) Running full ETL..."

# --- Ensure DB container is up and ready ---

echo "[FMHub] $(TS) Ensuring Postgres container is running..."
docker compose up -d db

echo "[FMHub] $(TS) Waiting for Postgres to be ready..."
until docker exec fmhub_db pg_isready -U app -d fmhub >/dev/null 2>&1; do
  sleep 1
done
echo "[FMHub] $(TS) Postgres is ready."

# --- Schema check + auto-load ---

echo "[FMHub] $(TS) Checking if schema is present..."
SCHEMA_PRESENT=$(
  docker exec fmhub_db \
    psql -U app -d fmhub -tAc "SELECT to_regclass('public.instruments') IS NOT NULL;" \
    || echo "f"
)

if echo "$SCHEMA_PRESENT" | grep -q "t"; then
  echo "[FMHub] $(TS) Schema already present (public.instruments exists)."
else
  echo "[FMHub] $(TS) No schema detected. Loading services/db/schema.sql..."
  docker exec -i fmhub_db psql -U app -d fmhub < services/db/schema.sql
  echo "[FMHub] $(TS) Schema loaded successfully."
fi

# --- ETL steps ---

echo "[FMHub] $(TS) ETL step: polygon_instruments..."
docker compose run --rm etl python -m etl.polygon.polygon_instruments

echo "[FMHub] $(TS) ETL step: polygon_price_prev_daily..."
docker compose run --rm etl python -m etl.polygon.polygon_price_prev_daily

echo "[FMHub] $(TS) ETL step: instrument_focus_universe..."
docker compose run --rm etl python -m etl.core.instrument_focus_universe

echo "[FMHub] $(TS) ETL step: export_sample_tickers_json..."
docker compose run --rm etl python -m etl.core.export_sample_tickers_json

echo "[FMHub] $(TS) ETL step: polygon_news..."
docker compose run --rm etl python -m etl.polygon.polygon_news

echo "[FMHub] $(TS) ETL step: prewarm_instrument_insights..."
docker compose run --rm etl python -m etl.core.prewarm_instrument_insights

echo "[FMHub] $(TS) Full ETL completed."