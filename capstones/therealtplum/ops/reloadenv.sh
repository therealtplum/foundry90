#!/usr/bin/env bash
# Reload the capstone's .env file into your host shell

ENV_FILE="$(dirname "$0")/../.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ No .env file found at: $ENV_FILE"
  exit 1
fi

echo "🔄 Loading environment variables from $ENV_FILE ..."
set -a
source "$ENV_FILE"
set +a

echo "✅ Environment reloaded."