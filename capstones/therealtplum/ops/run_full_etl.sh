#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

TS() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

if ! command -v docker >/dev/null 2>&1; then
  echo "[FMHub] $(TS) ERROR: docker command not found on PATH."
  exit 127
fi

echo "[FMHub] $(TS) Running full ETL..."

docker compose run --rm etl python -m etl.polygon_instruments
docker compose run --rm etl python -m etl.polygon_news
docker compose run --rm etl python -m etl.instrument_focus_universe
docker compose run --rm etl python -m etl.prewarm_instrument_insights

echo "[FMHub] $(TS) Full ETL completed."