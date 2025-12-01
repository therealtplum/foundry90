#!/bin/bash
# Helper script to run the Rust API with correct environment variables

cd "$(dirname "$0")"

# Load environment variables from .env file in project root
if [ -f "../../.env" ]; then
    # Use set -a to automatically export all variables
    set -a
    source ../../.env
    set +a
fi

# Explicitly export FRED_API_KEY if it's in .env (for reliability)
if [ -f "../../.env" ] && grep -q "^FRED_API_KEY=" ../../.env; then
    export FRED_API_KEY=$(grep "^FRED_API_KEY=" ../../.env | cut -d '=' -f2- | tr -d '"' | tr -d "'")
fi

# Set default DATABASE_URL if not already set
export DATABASE_URL="${DATABASE_URL:-postgres://app:app@localhost:5433/fmhub}"
export REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6379}"

echo "Starting Rust API with:"
echo "  DATABASE_URL: $DATABASE_URL"
echo "  REDIS_URL: $REDIS_URL"
echo "  FRED_API_KEY: ${FRED_API_KEY:+set (hidden)}"
echo ""

echo "Starting Rust API with:"
echo "  DATABASE_URL: $DATABASE_URL"
echo "  REDIS_URL: $REDIS_URL"
echo ""

cargo run

