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

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "[FMHub] $(TS) ERROR: Project root not found at: $PROJECT_ROOT"
  exit 1
fi

cd "$PROJECT_ROOT"

echo "[FMHub] $(TS) Rebuilding and starting stack..."

# Stop any existing containers
echo "[FMHub] $(TS) Stopping existing containers..."
docker compose down

# Build and start all services
echo "[FMHub] $(TS) Building and starting services..."
docker compose up -d --build

# Wait for services to be ready
echo "[FMHub] $(TS) Waiting for Postgres to be ready..."
until docker exec fmhub_db pg_isready -U app -d fmhub >/dev/null 2>&1; do
  sleep 1
done
echo "[FMHub] $(TS) Postgres is ready."

# Wait for Redis
echo "[FMHub] $(TS) Waiting for Redis to be ready..."
until docker exec fmhub_redis redis-cli ping >/dev/null 2>&1; do
  sleep 1
done
echo "[FMHub] $(TS) Redis is ready."

# Wait for API
echo "[FMHub] $(TS) Waiting for API to be ready..."
until curl -s http://localhost:3000/health >/dev/null 2>&1; do
  sleep 1
done
echo "[FMHub] $(TS) API is ready."

# Wait for Web
echo "[FMHub] $(TS) Waiting for Web to be ready..."
until curl -s http://localhost:3001 >/dev/null 2>&1; do
  sleep 1
done
echo "[FMHub] $(TS) Web is ready."

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
echo "[FMHub] $(TS) Running ETL pipeline..."

echo "[FMHub] $(TS) ETL step: polygon_instruments..."
docker compose run --rm etl python -m etl.polygon.polygon_instruments || echo "[FMHub] $(TS) WARNING: polygon_instruments failed"

echo "[FMHub] $(TS) ETL step: polygon_price_prev_daily..."
docker compose run --rm etl python -m etl.polygon.polygon_price_prev_daily || echo "[FMHub] $(TS) WARNING: polygon_price_prev_daily failed"

echo "[FMHub] $(TS) ETL step: polygon_news..."
docker compose run --rm etl python -m etl.polygon.polygon_news || echo "[FMHub] $(TS) WARNING: polygon_news failed"

echo "[FMHub] $(TS) ETL step: instrument_focus_universe..."
docker compose run --rm etl python -m etl.core.instrument_focus_universe || echo "[FMHub] $(TS) WARNING: instrument_focus_universe failed"

echo "[FMHub] $(TS) ETL step: export_sample_tickers_json..."
docker compose run --rm etl python -m etl.core.export_sample_tickers_json || echo "[FMHub] $(TS) WARNING: export_sample_tickers_json failed"

echo "[FMHub] $(TS) ETL step: prewarm_instrument_insights..."
docker compose run --rm etl python -m etl.core.prewarm_instrument_insights || echo "[FMHub] $(TS) WARNING: prewarm_instrument_insights failed"

echo "[FMHub] $(TS) =========================================="
echo "[FMHub] $(TS) Stack is running!"
echo "[FMHub] $(TS) Web app: http://localhost:3001"
echo "[FMHub] $(TS) API: http://localhost:3000"
echo "[FMHub] $(TS) API Health: http://localhost:3000/health"
echo "[FMHub] $(TS) System Health: http://localhost:3000/system/health"
echo "[FMHub] $(TS) =========================================="

