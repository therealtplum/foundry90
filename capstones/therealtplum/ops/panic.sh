#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

TS() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

if ! command -v docker >/dev/null 2>&1; then
  echo "[FMHub] $(TS) ERROR: docker command not found on PATH."
  exit 127
fi

echo "[FMHub] $(TS) PANIC: tearing down FMHub stack..."

# Stop containers
docker compose down || true

# Kill any stray fmhub-api binaries (cargo run)
pkill -f fmhub-api || true

echo "[FMHub] $(TS) PANIC completed. Stack should be offline."