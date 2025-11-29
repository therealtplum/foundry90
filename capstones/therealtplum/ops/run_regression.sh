#!/usr/bin/env bash
set -uo pipefail

# Make sure common locations are on PATH (for docker, curl, etc.)
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

TS() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Root of the therealtplum capstone.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${FOUNDRY90_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if ! command -v docker >/dev/null 2>&1; then
  echo "[REGRESSION] $(TS) ❌ ERROR: docker command not found on PATH."
  exit 127
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "[REGRESSION] $(TS) ❌ ERROR: curl command not found on PATH."
  exit 127
fi

cd "$PROJECT_ROOT"

echo "[REGRESSION] $(TS) 🧪 Starting regression test suite..."
echo ""

# Track results
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
log_success() {
  echo "[REGRESSION] $(TS) ✅ SUCCESS: $1"
  ((PASSED++))
}

log_error() {
  echo "[REGRESSION] $(TS) ❌ ERROR: $1"
  ((FAILED++))
}

log_warning() {
  echo "[REGRESSION] $(TS) ⚠️  WARNING: $1"
  ((WARNINGS++))
}

log_info() {
  echo "[REGRESSION] $(TS) ℹ️  INFO: $1"
}

# Test 1: Docker containers are running
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: Docker Container Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

REQUIRED_CONTAINERS=("fmhub_db" "fmhub_redis" "fmhub_api" "fmhub_web")
MISSING_CONTAINERS=()

for container in "${REQUIRED_CONTAINERS[@]}"; do
  if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    log_success "Container ${container} is running"
  else
    log_error "Container ${container} is not running"
    MISSING_CONTAINERS+=("$container")
  fi
done

if [ ${#MISSING_CONTAINERS[@]} -gt 0 ]; then
  log_warning "Some containers are missing. Attempting to start..."
  docker compose up -d "${MISSING_CONTAINERS[@]}" 2>/dev/null || true
  sleep 3
fi

echo ""

# Test 2: Database connectivity
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: Database Connectivity"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker exec fmhub_db pg_isready -U app -d fmhub >/dev/null 2>&1; then
  log_success "PostgreSQL is ready and accepting connections"
else
  log_error "PostgreSQL is not ready"
  echo ""
  exit 1
fi

# Check key tables exist
REQUIRED_TABLES=("instruments" "instrument_focus_universe" "instrument_insights" "news_articles")
for table in "${REQUIRED_TABLES[@]}"; do
  TABLE_EXISTS=$(docker exec fmhub_db psql -U app -d fmhub -tAc "SELECT to_regclass('public.${table}') IS NOT NULL;" 2>/dev/null || echo "f")
  if echo "$TABLE_EXISTS" | grep -q "t"; then
    log_success "Table '${table}' exists"
  else
    log_warning "Table '${table}' does not exist (may need ETL run)"
  fi
done

# Check data in instruments table
INSTRUMENT_COUNT=$(docker exec fmhub_db psql -U app -d fmhub -tAc "SELECT COUNT(*) FROM instruments;" 2>/dev/null || echo "0")
if [ "$INSTRUMENT_COUNT" -gt 0 ]; then
  log_success "Database has ${INSTRUMENT_COUNT} instruments"
else
  log_warning "Database has no instruments (may need ETL run)"
fi

echo ""

# Test 3: Redis connectivity
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3: Redis Connectivity"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker exec fmhub_redis redis-cli PING >/dev/null 2>&1; then
  log_success "Redis is responding to PING"
  
  # Test set/get
  TEST_KEY="regression_test_$(date +%s)"
  if docker exec fmhub_redis redis-cli SET "${TEST_KEY}" "test" >/dev/null 2>&1 && \
     docker exec fmhub_redis redis-cli GET "${TEST_KEY}" >/dev/null 2>&1; then
    docker exec fmhub_redis redis-cli DEL "${TEST_KEY}" >/dev/null 2>&1 || true
    log_success "Redis read/write operations working"
  else
    log_warning "Redis read/write test failed"
  fi
else
  log_error "Redis is not responding"
fi

echo ""

# Test 4: API Health Endpoint
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 4: API Health Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 http://localhost:3000/health 2>/dev/null || echo -e "\n000")
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)
BODY=$(echo "$HEALTH_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  log_success "API /health endpoint returned 200"
  if echo "$BODY" | grep -q '"status":"ok"'; then
    log_success "API health status is 'ok'"
  else
    log_warning "API health response format unexpected"
  fi
  if echo "$BODY" | grep -q '"db_ok":true'; then
    log_success "API reports database connection is OK"
  else
    log_warning "API reports database connection issue"
  fi
else
  log_error "API /health endpoint returned ${HTTP_CODE} (expected 200)"
fi

echo ""

# Test 5: API System Health Endpoint
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 5: API System Health Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SYSTEM_HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 10 http://localhost:3000/system/health 2>/dev/null || echo -e "\n000")
SYSTEM_HTTP_CODE=$(echo "$SYSTEM_HEALTH_RESPONSE" | tail -n1)
SYSTEM_BODY=$(echo "$SYSTEM_HEALTH_RESPONSE" | sed '$d')

if [ "$SYSTEM_HTTP_CODE" = "200" ]; then
  log_success "API /system/health endpoint returned 200"
  
  # Parse JSON (basic checks)
  if echo "$SYSTEM_BODY" | grep -q '"api":"up"'; then
    log_success "System health reports API is up"
  else
    log_warning "System health reports API status is not 'up'"
  fi
  
  if echo "$SYSTEM_BODY" | grep -q '"db":"up"'; then
    log_success "System health reports database is up"
  else
    log_error "System health reports database is down"
  fi
  
  if echo "$SYSTEM_BODY" | grep -q '"redis":"up"'; then
    log_success "System health reports Redis is up"
  else
    log_error "System health reports Redis is down"
  fi
else
  log_error "API /system/health endpoint returned ${SYSTEM_HTTP_CODE} (expected 200)"
fi

echo ""

# Test 6: Web Frontend
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 6: Web Frontend"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WEB_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 http://localhost:3001/api/version 2>/dev/null || echo -e "\n000")
WEB_HTTP_CODE=$(echo "$WEB_RESPONSE" | tail -n1)
WEB_BODY=$(echo "$WEB_RESPONSE" | sed '$d')

if [ "$WEB_HTTP_CODE" = "200" ]; then
  log_success "Web frontend /api/version endpoint returned 200"
  if echo "$WEB_BODY" | grep -q '"status":"ok"'; then
    log_success "Web frontend is responding correctly"
  else
    log_warning "Web frontend response format unexpected"
  fi
else
  log_error "Web frontend /api/version endpoint returned ${WEB_HTTP_CODE} (expected 200)"
fi

echo ""

# Test 7: API Functionality - List Instruments
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 7: API Functionality - List Instruments"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

INSTRUMENTS_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 "http://localhost:3000/instruments?limit=5" 2>/dev/null || echo -e "\n000")
INSTRUMENTS_HTTP_CODE=$(echo "$INSTRUMENTS_RESPONSE" | tail -n1)
INSTRUMENTS_BODY=$(echo "$INSTRUMENTS_RESPONSE" | sed '$d')

if [ "$INSTRUMENTS_HTTP_CODE" = "200" ]; then
  log_success "API /instruments endpoint returned 200"
  # Check if response is a JSON array
  if echo "$INSTRUMENTS_BODY" | grep -q '^\['; then
    INSTRUMENT_COUNT=$(echo "$INSTRUMENTS_BODY" | grep -o '"ticker"' | wc -l | tr -d ' ')
    if [ "$INSTRUMENT_COUNT" -gt 0 ]; then
      log_success "API returned ${INSTRUMENT_COUNT} instruments"
    else
      log_warning "API returned empty instruments list (may need ETL run)"
    fi
  else
    log_warning "API /instruments response format unexpected"
  fi
else
  log_error "API /instruments endpoint returned ${INSTRUMENTS_HTTP_CODE} (expected 200)"
fi

echo ""

# Test 8: API Functionality - Focus Ticker Strip
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 8: API Functionality - Focus Ticker Strip"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

FOCUS_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 "http://localhost:3000/focus/ticker-strip?limit=5" 2>/dev/null || echo -e "\n000")
FOCUS_HTTP_CODE=$(echo "$FOCUS_RESPONSE" | tail -n1)
FOCUS_BODY=$(echo "$FOCUS_RESPONSE" | sed '$d')

if [ "$FOCUS_HTTP_CODE" = "200" ]; then
  log_success "API /focus/ticker-strip endpoint returned 200"
  # Check if response is a JSON array
  if echo "$FOCUS_BODY" | grep -q '^\['; then
    FOCUS_COUNT=$(echo "$FOCUS_BODY" | grep -o '"ticker"' | wc -l | tr -d ' ')
    if [ "$FOCUS_COUNT" -gt 0 ]; then
      log_success "API returned ${FOCUS_COUNT} focus tickers"
    else
      log_warning "API returned empty focus ticker strip (may need ETL run)"
    fi
  else
    log_warning "API /focus/ticker-strip response format unexpected"
  fi
else
  log_warning "API /focus/ticker-strip endpoint returned ${FOCUS_HTTP_CODE} (may need ETL run)"
fi

echo ""

# Test 9: Check for hardcoded user paths (security/portability check)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 9: Path Configuration Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check shared Xcode scheme for hardcoded paths (user schemes in xcuserdata are gitignored)
XCODE_SCHEME="${PROJECT_ROOT}/clients/FMHubControl/FMHubControl/FMHubControl.xcodeproj/xcshareddata/xcschemes/FMHubControl.xcscheme"
if [ -f "$XCODE_SCHEME" ]; then
  # Check for hardcoded /Users/ paths (common macOS user path pattern)
  # Note: User-specific schemes in xcuserdata/ can have hardcoded paths (they're gitignored)
  HARDCODED_PATHS=$(grep -c "/Users/[^/]*/" "$XCODE_SCHEME" 2>/dev/null | tr -d '[:space:]' || echo "0")
  if [ "${HARDCODED_PATHS:-0}" -eq 0 ]; then
    log_success "Shared Xcode scheme does not contain hardcoded user paths"
  else
    log_error "Shared Xcode scheme contains ${HARDCODED_PATHS} hardcoded user path(s)"
    log_info "  → User-specific schemes in xcuserdata/ can have hardcoded paths (gitignored)"
  fi
  
  # Check that FOUNDRY90_ROOT is properly configured (disabled or empty in shared scheme)
  if grep -q 'key = "FOUNDRY90_ROOT"' "$XCODE_SCHEME"; then
    log_success "Shared Xcode scheme has FOUNDRY90_ROOT environment variable configured"
  else
    log_warning "Shared Xcode scheme missing FOUNDRY90_ROOT environment variable"
  fi
else
  log_warning "Xcode scheme file not found (skipping Xcode-specific tests)"
fi

# Check shell scripts use FOUNDRY90_ROOT pattern
SCRIPT_DIR="${PROJECT_ROOT}/ops"
HARDCODED_SCRIPT_PATHS=0
for script in "${SCRIPT_DIR}"/*.sh; do
  if [ -f "$script" ]; then
    # Check for hardcoded paths that aren't using FOUNDRY90_ROOT or relative paths
    if grep -qE "FOUNDRY90_ROOT|cd.*\$\(.*pwd\)|\$\(cd" "$script"; then
      # Script uses proper path resolution
      continue
    elif grep -qE "/Users/[^/]*/Documents|/home/[^/]*/" "$script"; then
      ((HARDCODED_SCRIPT_PATHS++))
      log_error "Script $(basename "$script") contains hardcoded user path"
    fi
  fi
done

if [ "$HARDCODED_SCRIPT_PATHS" -eq 0 ]; then
  log_success "All shell scripts use FOUNDRY90_ROOT or relative paths"
fi

# Check that FOUNDRY90_ROOT is used in key scripts
KEY_SCRIPTS=("run_full_etl.sh" "run_regression.sh" "export_sample_tickers_json.sh")
for script in "${KEY_SCRIPTS[@]}"; do
  if [ -f "${SCRIPT_DIR}/${script}" ]; then
    if grep -q "FOUNDRY90_ROOT" "${SCRIPT_DIR}/${script}"; then
      log_success "Script ${script} uses FOUNDRY90_ROOT environment variable"
    else
      log_warning "Script ${script} may not use FOUNDRY90_ROOT"
    fi
  fi
done

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Regression Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Passed: ${PASSED}"
echo "❌ Failed: ${FAILED}"
echo "⚠️  Warnings: ${WARNINGS}"
echo ""

# Write results to JSON file for API to read
REGRESSION_RESULTS_FILE="${PROJECT_ROOT}/logs/regression_results.json"
mkdir -p "$(dirname "$REGRESSION_RESULTS_FILE")"

CURRENT_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "$REGRESSION_RESULTS_FILE" <<EOF
{
  "last_run_utc": "${CURRENT_UTC}",
  "passed": ${PASSED},
  "failed": ${FAILED},
  "warnings": ${WARNINGS},
  "success": $([ $FAILED -eq 0 ] && echo "true" || echo "false")
}
EOF

if [ $FAILED -eq 0 ]; then
  if [ $WARNINGS -eq 0 ]; then
    echo "[REGRESSION] $(TS) ✅ All tests passed with no issues!"
    exit 0
  else
    echo "[REGRESSION] $(TS) ⚠️  All critical tests passed, but there are warnings."
    exit 0
  fi
else
  echo "[REGRESSION] $(TS) ❌ Regression test failed with ${FAILED} error(s)."
  exit 1
fi

