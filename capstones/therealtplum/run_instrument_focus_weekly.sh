#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="./logs"
LOGFILE="${LOG_DIR}/instrument_focus_weekly.log"

mkdir -p "$LOG_DIR"

timestamp() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}

echo "[$(timestamp)] START weekly instrument_focus_universe" | tee -a "$LOGFILE"

# Ensure DB is up
docker compose pull db >/dev/null 2>&1 || true
docker compose up -d db

# Run ETL
docker compose run --rm etl python -m etl.instrument_focus_universe \
  2>&1 | tee -a "$LOGFILE"

echo "[$(timestamp)] END weekly instrument_focus_universe" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"