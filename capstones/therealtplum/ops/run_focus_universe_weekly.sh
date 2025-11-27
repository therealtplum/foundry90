#!/usr/bin/env bash
set -euo pipefail

# Match the other ops scripts exactly
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

TS() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Resolve project root:
# 1. If FOUNDRY90_ROOT is set, use that.
# 2. Otherwise, assume this script lives in capstones/therealtplum/ops and go one level up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${FOUNDRY90_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

cd "$PROJECT_ROOT"

LOG_DIR="$PROJECT_ROOT/logs"
LOGFILE="${LOG_DIR}/instrument_focus_weekly.log"

mkdir -p "$LOG_DIR"

echo "[focus_weekly] $(TS) START weekly instrument_focus_universe" | tee -a "$LOGFILE"

# Ensure DB container is up
echo "[focus_weekly] $(TS) Ensuring Postgres container is running..." | tee -a "$LOGFILE"
docker compose pull db >/dev/null 2>&1 || true
docker compose up -d db

echo "[focus_weekly] $(TS) Running instrument_focus_universe ETL..." | tee -a "$LOGFILE"
docker compose run --rm etl python -m etl.instrument_focus_universe \
  2>&1 | tee -a "$LOGFILE"

echo "[focus_weekly] $(TS) END weekly instrument_focus_universe" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"