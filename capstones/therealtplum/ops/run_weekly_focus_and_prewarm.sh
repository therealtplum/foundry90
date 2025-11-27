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
LOGFILE="${LOG_DIR}/weekly_focus_and_prewarm.log"

mkdir -p "$LOG_DIR"

echo "[weekly_focus_and_prewarm] $(TS) START weekly focus + prewarm" | tee -a "$LOGFILE"

# --- Ensure db + etl services are running ---

echo "[weekly_focus_and_prewarm] $(TS) Ensuring db + etl services are running..." | tee -a "$LOGFILE"
docker compose up -d db etl

echo "[weekly_focus_and_prewarm] $(TS) Waiting for Postgres to be ready..." | tee -a "$LOGFILE"
until docker exec fmhub_db pg_isready -U app -d fmhub >/dev/null 2>&1; do
  sleep 1
done
echo "[weekly_focus_and_prewarm] $(TS) Postgres is ready." | tee -a "$LOGFILE"

# --- Step 1: refresh instrument_focus_universe ---

echo "[weekly_focus_and_prewarm] $(TS) Running instrument_focus_universe ETL..." | tee -a "$LOGFILE"
docker compose run --rm etl python -m etl.instrument_focus_universe \
  2>&1 | tee -a "$LOGFILE"

# --- Step 2: prewarm insights for focus universe ---

echo "[weekly_focus_and_prewarm] $(TS) Running prewarm_instrument_insights..." | tee -a "$LOGFILE"
docker compose run --rm etl python -m etl.prewarm_instrument_insights \
  2>&1 | tee -a "$LOGFILE"

echo "[weekly_focus_and_prewarm] $(TS) END weekly focus + prewarm" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"