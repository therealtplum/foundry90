#!/usr/bin/env bash
set -euo pipefail

# Ensure docker is available when called from FMHubControl
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

TS() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

if ! command -v docker >/dev/null 2>&1; then
  echo "[FMHub] $(TS) ERROR: docker command not found on PATH."
  exit 127
fi

echo "[FMHub] $(TS) Starting stack..."

docker compose up -d

echo "[FMHub] $(TS) Stack started."