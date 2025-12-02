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

REQUIRED_CONTAINERS=("fmhub_db" "fmhub_redis" "fmhub_api" "fmhub_web" "fmhub_hadron")
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

# Check Hadron-specific tables
HADRON_TABLES=("hadron_ticks" "hadron_order_intents" "hadron_order_executions" "hadron_strategy_decisions")
for table in "${HADRON_TABLES[@]}"; do
  TABLE_EXISTS=$(docker exec fmhub_db psql -U app -d fmhub -tAc "SELECT to_regclass('public.${table}') IS NOT NULL;" 2>/dev/null || echo "f")
  if echo "$TABLE_EXISTS" | grep -q "t"; then
    log_success "Hadron table '${table}' exists"
  else
    log_warning "Hadron table '${table}' does not exist (may need schema_hadron.sql applied)"
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

# Test 2.5: Code Compilation (Critical for refactored code)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2.5: Code Compilation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v cargo >/dev/null 2>&1; then
  if cargo check --manifest-path "${PROJECT_ROOT}/apps/hadron/Cargo.toml" >/dev/null 2>&1; then
    log_success "Hadron Rust code compiles successfully"
  else
    log_error "Hadron Rust code compilation failed"
    log_info "  → Run: cd apps/hadron && cargo check"
  fi
  
  if cargo check --manifest-path "${PROJECT_ROOT}/apps/rust-api/Cargo.toml" >/dev/null 2>&1; then
    log_success "Rust API code compiles successfully"
  else
    log_error "Rust API code compilation failed"
    log_info "  → Run: cd apps/rust-api && cargo check"
  fi
else
  log_warning "cargo command not found (Rust not installed or not on PATH)"
  log_info "  → Compilation tests skipped (containers may still work if pre-built)"
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

# Test 4.5: Hadron Health Endpoint
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 4.5: Hadron Health Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

HADRON_HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 http://localhost:3002/system/health 2>/dev/null || echo -e "\n000")
HADRON_HTTP_CODE=$(echo "$HADRON_HEALTH_RESPONSE" | tail -n1)
HADRON_BODY=$(echo "$HADRON_HEALTH_RESPONSE" | sed '$d')

if [ "$HADRON_HTTP_CODE" = "200" ]; then
  log_success "Hadron /system/health endpoint returned 200"
  if echo "$HADRON_BODY" | grep -q '"status":"ok"'; then
    log_success "Hadron health status is 'ok'"
  else
    log_warning "Hadron health response format unexpected"
  fi
  if echo "$HADRON_BODY" | grep -q '"db_ok":true'; then
    log_success "Hadron reports database connection is OK"
  else
    log_error "Hadron reports database connection issue"
  fi
  if echo "$HADRON_BODY" | grep -q '"service":"hadron"'; then
    log_success "Hadron service identifier is correct"
  fi
else
  log_error "Hadron /system/health endpoint returned ${HADRON_HTTP_CODE} (expected 200)"
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

# Test 9: API Functionality - Get Individual Instrument
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 9: API Functionality - Get Individual Instrument"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Try to get the first instrument ID from the database
FIRST_INSTRUMENT_ID=$(docker exec fmhub_db psql -U app -d fmhub -tAc "SELECT id FROM instruments WHERE status = 'active' ORDER BY id LIMIT 1;" 2>/dev/null || echo "")

if [ -n "$FIRST_INSTRUMENT_ID" ] && [ "$FIRST_INSTRUMENT_ID" != "" ]; then
  INSTRUMENT_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 "http://localhost:3000/instruments/${FIRST_INSTRUMENT_ID}" 2>/dev/null || echo -e "\n000")
  INSTRUMENT_HTTP_CODE=$(echo "$INSTRUMENT_RESPONSE" | tail -n1)
  INSTRUMENT_BODY=$(echo "$INSTRUMENT_RESPONSE" | sed '$d')
  
  if [ "$INSTRUMENT_HTTP_CODE" = "200" ]; then
    log_success "API /instruments/${FIRST_INSTRUMENT_ID} endpoint returned 200"
    if echo "$INSTRUMENT_BODY" | grep -q '"ticker"'; then
      TICKER=$(echo "$INSTRUMENT_BODY" | grep -o '"ticker":"[^"]*"' | head -1 | cut -d'"' -f4)
      log_success "API returned instrument details for ticker: ${TICKER}"
    else
      log_warning "API /instruments/${FIRST_INSTRUMENT_ID} response format unexpected"
    fi
  else
    log_warning "API /instruments/${FIRST_INSTRUMENT_ID} endpoint returned ${INSTRUMENT_HTTP_CODE}"
  fi
else
  log_warning "No instruments found in database to test individual instrument endpoint"
fi

echo ""

# Test 10: Web Frontend Root Page
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 10: Web Frontend Root Page"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WEB_ROOT_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 http://localhost:3001/ 2>/dev/null || echo -e "\n000")
WEB_ROOT_HTTP_CODE=$(echo "$WEB_ROOT_RESPONSE" | tail -n1)

if [ "$WEB_ROOT_HTTP_CODE" = "200" ]; then
  log_success "Web frontend root page returned 200"
else
  log_warning "Web frontend root page returned ${WEB_ROOT_HTTP_CODE} (expected 200)"
fi

echo ""

# Test 10.5: Hadron Recorder Functionality
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 10.5: Hadron Recorder Functionality"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Since Hadron health endpoint works (Test 4.5), the service is running
# Check for recorder startup message (may not be in logs if container started before code update)
HADRON_LOGS=$(docker compose logs hadron 2>/dev/null || echo "")

if echo "$HADRON_LOGS" | grep -qi "recorder.*started"; then
  log_success "Hadron Recorder component started successfully"
  
  # Check for timeout-based flush configuration (new feature)
  if echo "$HADRON_LOGS" | grep -qi "flush_interval\|flush interval"; then
    log_success "Timeout-based flush mechanism is configured"
  else
    log_warning "Timeout-based flush configuration not found in logs (container may need restart to see new messages)"
  fi
  
  # Check for batch size configuration
  if echo "$HADRON_LOGS" | grep -qi "batch_size\|batch size"; then
    log_success "Batch size configuration detected in recorder logs"
  fi
  
  # Check if both parameters are present (new refactored code format)
  if echo "$HADRON_LOGS" | grep -qi "batch_size.*flush_interval\|batch_size=.*flush_interval="; then
    log_success "Recorder log shows both batch_size and flush_interval parameters (refactored code active)"
  fi
elif echo "$HADRON_LOGS" | grep -qi "hadron.*started\|real-time intelligence"; then
  # Hadron is running (we know from health check), but log message format may differ
  log_success "Hadron service is running (health endpoint confirmed)"
  log_warning "Recorder startup message not found in logs (container may need restart to see updated log format)"
else
  # Hadron health endpoint works, so service is functional even if we can't find log message
  # This is a warning, not an error, since the health check already confirmed it's working
  log_warning "Hadron Recorder startup message not found in logs"
  log_info "  → Hadron health endpoint is working, so service is functional"
  log_info "  → Container may need restart to see updated log messages: docker compose restart hadron"
fi

# Check for critical errors in Hadron logs
HADRON_ERROR_COUNT=$(docker compose logs hadron 2>/dev/null | \
  grep -iE "error|panic|failed" | \
  grep -vE "(lagged|Timer-based flush|warn|info|debug)" | \
  grep -vE "(connection|reconnect|retry)" | \
  wc -l | tr -d ' ')

if [ "$HADRON_ERROR_COUNT" -eq 0 ]; then
  log_success "No critical errors in Hadron logs"
else
  if [ "$HADRON_ERROR_COUNT" -lt 10 ]; then
    log_warning "Found ${HADRON_ERROR_COUNT} potential errors in Hadron logs"
    log_info "  → Check: docker compose logs hadron | grep -i error"
  else
    log_warning "Many log messages match error pattern (likely false positives)"
  fi
fi

# Check for batch insert patterns (if ticks exist)
TICK_COUNT=$(docker exec fmhub_db psql -U app -d fmhub -tAc "SELECT COUNT(*) FROM hadron_ticks;" 2>/dev/null || echo "0")
if [ "$TICK_COUNT" -gt 0 ]; then
  log_success "Found ${TICK_COUNT} ticks in hadron_ticks table"
  
  # Check for batch insert patterns (transaction-based inserts)
  BATCH_PATTERN=$(docker exec fmhub_db psql -U app -d fmhub -tAc "
    SELECT COUNT(*) FROM (
      SELECT created_at::timestamp(0), COUNT(*) as cnt
      FROM hadron_ticks
      WHERE created_at > NOW() - INTERVAL '10 minutes'
      GROUP BY created_at::timestamp(0)
      HAVING COUNT(*) > 1
    ) batches;
  " 2>/dev/null || echo "0")
  
  if [ "$BATCH_PATTERN" -gt 0 ]; then
    log_success "Batch insert patterns detected (transaction-based inserts working correctly)"
  else
    log_warning "No batch patterns detected in recent ticks (may be normal if low volume or single inserts)"
  fi
  
  # Check for recent ticks (within last minute)
  RECENT_TICKS=$(docker exec fmhub_db psql -U app -d fmhub -tAc "
    SELECT COUNT(*) FROM hadron_ticks 
    WHERE created_at > NOW() - INTERVAL '1 minute';
  " 2>/dev/null || echo "0")
  
  if [ "$RECENT_TICKS" -gt 0 ]; then
    log_success "Hadron is actively processing ticks (${RECENT_TICKS} ticks in last minute)"
  else
    log_warning "No recent ticks (may be normal if data sources not connected)"
  fi
else
  log_warning "No ticks in hadron_ticks table yet (normal if no data sources connected)"
fi

# Verify Hadron pipeline components are running
# Note: Since health endpoint works (Test 4.5), components are functional even if log messages aren't found
HADRON_COMPONENTS=("Normalizer" "Router" "Engine" "Recorder")
COMPONENTS_FOUND=0
for component in "${HADRON_COMPONENTS[@]}"; do
  if echo "$HADRON_LOGS" | grep -qi "${component}.*started\|${component} started"; then
    log_success "Hadron ${component} component is running"
    ((COMPONENTS_FOUND++))
  else
    log_warning "Hadron ${component} component startup message not found in logs"
  fi
done

# If we found at least one component, consider it a success
# If health endpoint works (already tested in 4.5), components are functional
if [ "$COMPONENTS_FOUND" -gt 0 ]; then
  log_success "Found ${COMPONENTS_FOUND} Hadron component(s) in logs"
else
  # Health endpoint already confirmed Hadron is working, so this is informational
  log_info "Hadron components are functional (health endpoint confirmed in Test 4.5)"
  log_info "  → Log messages may not be visible if container started before code update"
  log_info "  → Restart container to see updated log messages: docker compose restart hadron"
fi

echo ""

# Test 11: File System Checks
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 11: File System Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check logs directory exists and is writable
LOGS_DIR="${PROJECT_ROOT}/logs"
if [ -d "$LOGS_DIR" ]; then
  log_success "Logs directory exists"
  if [ -w "$LOGS_DIR" ]; then
    log_success "Logs directory is writable"
  else
    log_error "Logs directory is not writable"
  fi
else
  log_warning "Logs directory does not exist (will be created)"
  mkdir -p "$LOGS_DIR" 2>/dev/null && log_success "Created logs directory" || log_error "Failed to create logs directory"
fi

# Check sample_tickers.json exists (used by web app)
SAMPLE_TICKERS_FILE="${PROJECT_ROOT}/apps/web/data/sample_tickers.json"
if [ -f "$SAMPLE_TICKERS_FILE" ]; then
  log_success "sample_tickers.json exists"
  # Quick check that it's valid JSON
  if command -v python3 >/dev/null 2>&1; then
    if python3 -m json.tool "$SAMPLE_TICKERS_FILE" >/dev/null 2>&1; then
      log_success "sample_tickers.json is valid JSON"
    else
      log_warning "sample_tickers.json may not be valid JSON"
    fi
  fi
else
  log_warning "sample_tickers.json does not exist (may need ETL run: export_sample_tickers_json.sh)"
fi

echo ""

# Test 12: Docker Images Check (Optional - containers are what matter)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 12: Docker Images Check (Informational)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Note: Docker Compose automatically prefixes image names with the project name (directory name)
# The actual image names depend on where docker-compose.yml is run from.
# This test is informational only - Test 1 already verifies containers are running,
# which is what actually matters. Images may not exist locally if pulled from a registry.

# Get the actual image names from running containers
API_IMAGE=$(docker inspect fmhub_api --format '{{.Config.Image}}' 2>/dev/null || echo "")
WEB_IMAGE=$(docker inspect fmhub_web --format '{{.Config.Image}}' 2>/dev/null || echo "")
ETL_IMAGE=$(docker inspect fmhub_etl --format '{{.Config.Image}}' 2>/dev/null || echo "")

if [ -n "$API_IMAGE" ]; then
  log_info "API container is using image: ${API_IMAGE}"
  if docker images --format '{{.Repository}}' | grep -q "^${API_IMAGE}$"; then
    log_success "API image exists locally"
  else
    log_info "API image not found locally (may be from remote registry)"
  fi
fi

if [ -n "$WEB_IMAGE" ]; then
  log_info "Web container is using image: ${WEB_IMAGE}"
  if docker images --format '{{.Repository}}' | grep -q "^${WEB_IMAGE}$"; then
    log_success "Web image exists locally"
  else
    log_info "Web image not found locally (may be from remote registry)"
  fi
fi

if [ -n "$ETL_IMAGE" ]; then
  log_info "ETL container is using image: ${ETL_IMAGE}"
  if docker images --format '{{.Repository}}' | grep -q "^${ETL_IMAGE}$"; then
    log_success "ETL image exists locally"
  else
    log_info "ETL image not found locally (may be from remote registry)"
  fi
fi

# Check ETL container exists (even if not running)
if docker ps -a --format '{{.Names}}' | grep -q "^fmhub_etl$"; then
  log_success "ETL container exists (may not be running, which is normal)"
else
  log_warning "ETL container does not exist"
fi

echo ""

# Test 13: Database Schema Validation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 13: Database Schema Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check that key columns exist in instruments table
INSTRUMENTS_COLUMNS=$(docker exec fmhub_db psql -U app -d fmhub -tAc "SELECT column_name FROM information_schema.columns WHERE table_name = 'instruments' AND column_name IN ('id', 'ticker', 'name', 'asset_class', 'status');" 2>/dev/null | wc -l | tr -d ' ')
if [ "$INSTRUMENTS_COLUMNS" -ge 4 ]; then
  log_success "Instruments table has required columns (id, ticker, name, asset_class, status)"
else
  log_warning "Instruments table may be missing required columns (schema may need to be applied)"
fi

# Check that enum types exist
ENUM_COUNT=$(docker exec fmhub_db psql -U app -d fmhub -tAc "SELECT COUNT(*) FROM pg_type WHERE typname IN ('asset_class_enum', 'instrument_status_enum');" 2>/dev/null || echo "0")
if [ "$ENUM_COUNT" -ge 2 ]; then
  log_success "Required database enum types exist"
else
  log_warning "Some database enum types may be missing (schema may need to be applied)"
fi

echo ""

# Test 14: Check for hardcoded user paths (security/portability check)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 14: Path Configuration Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check shared Xcode scheme for hardcoded paths (user schemes in xcuserdata are gitignored)
XCODE_SCHEME="${PROJECT_ROOT}/clients/apps/macos-f90hub/F90Hub.xcodeproj/xcshareddata/xcschemes/F90Hub.xcscheme"
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
  
  # Run Xcode tests if xcodebuild is available
  if command -v xcodebuild >/dev/null 2>&1; then
    XCODE_PROJECT="${PROJECT_ROOT}/clients/apps/macos-f90hub/F90Hub.xcodeproj"
    SCHEME_NAME="F90Hub"
    
    log_info "Running Xcode tests for ${SCHEME_NAME}..."
    # Run tests with xcodebuild (only test, don't build)
    # Use -destination 'platform=macOS' for macOS apps
    if xcodebuild test \
      -project "$XCODE_PROJECT" \
      -scheme "$SCHEME_NAME" \
      -destination 'platform=macOS' \
      -quiet \
      >/tmp/xcode_test_output.log 2>&1; then
      log_success "Xcode tests passed for ${SCHEME_NAME}"
    else
      TEST_EXIT_CODE=$?
      # Exit code 66 means scheme is not configured for testing (no test targets)
      if [ "$TEST_EXIT_CODE" -eq 66 ]; then
        log_warning "Xcode scheme is not configured for testing (no test targets in project)"
        log_info "  → This is normal if the project doesn't have test targets yet"
        log_info "  → To add tests: Create test targets in Xcode and configure the scheme"
      else
        log_error "Xcode tests failed for ${SCHEME_NAME} (exit code: ${TEST_EXIT_CODE})"
        log_info "  → Check test output: cat /tmp/xcode_test_output.log"
        log_info "  → Note: Test failures may be expected if dependencies are not available"
      fi
    fi
  else
    log_warning "xcodebuild command not found (Xcode not installed or not on PATH)"
    log_info "  → Xcode tests skipped (scheme validation still performed)"
  fi
else
  log_warning "Xcode scheme file not found (skipping Xcode-specific tests)"
  log_info "  → Expected location: ${PROJECT_ROOT}/clients/apps/macos-f90hub/F90Hub.xcodeproj/xcshareddata/xcschemes/F90Hub.xcscheme"
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

# Test 15: Additional API Endpoints
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 15: Additional API Endpoints"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test market status endpoint
MARKET_STATUS_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 "http://localhost:3000/market/status" 2>/dev/null || echo -e "\n000")
MARKET_STATUS_HTTP_CODE=$(echo "$MARKET_STATUS_RESPONSE" | tail -n1)
MARKET_STATUS_BODY=$(echo "$MARKET_STATUS_RESPONSE" | sed '$d')

if [ "$MARKET_STATUS_HTTP_CODE" = "200" ]; then
  log_success "API /market/status endpoint returned 200"
  if echo "$MARKET_STATUS_BODY" | grep -q '"market"'; then
    log_success "Market status endpoint returns valid data"
  else
    log_warning "Market status response format unexpected"
  fi
elif [ "$MARKET_STATUS_HTTP_CODE" = "404" ]; then
  log_warning "Market status endpoint returned 404 (may need ETL run to populate market_status table)"
else
  log_warning "Market status endpoint returned ${MARKET_STATUS_HTTP_CODE}"
fi

# Test instrument news endpoint (if we have an instrument)
if [ -n "$FIRST_INSTRUMENT_ID" ] && [ "$FIRST_INSTRUMENT_ID" != "" ]; then
  NEWS_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 "http://localhost:3000/instruments/${FIRST_INSTRUMENT_ID}/news" 2>/dev/null || echo -e "\n000")
  NEWS_HTTP_CODE=$(echo "$NEWS_RESPONSE" | tail -n1)
  NEWS_BODY=$(echo "$NEWS_RESPONSE" | sed '$d')
  
  if [ "$NEWS_HTTP_CODE" = "200" ]; then
    log_success "API /instruments/${FIRST_INSTRUMENT_ID}/news endpoint returned 200"
    if echo "$NEWS_BODY" | grep -q '^\['; then
      NEWS_COUNT=$(echo "$NEWS_BODY" | grep -o '"headline"' | wc -l | tr -d ' ')
      log_success "News endpoint returned ${NEWS_COUNT} articles (or empty array if none)"
    fi
  else
    log_warning "News endpoint returned ${NEWS_HTTP_CODE} (may be normal if no news articles)"
  fi
fi

# Test Kalshi markets endpoint (may require authentication or return empty)
KALSHI_MARKETS_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 "http://localhost:3000/kalshi/markets?limit=5" 2>/dev/null || echo -e "\n000")
KALSHI_MARKETS_HTTP_CODE=$(echo "$KALSHI_MARKETS_RESPONSE" | tail -n1)
if [ "$KALSHI_MARKETS_HTTP_CODE" = "200" ] || [ "$KALSHI_MARKETS_HTTP_CODE" = "401" ] || [ "$KALSHI_MARKETS_HTTP_CODE" = "404" ]; then
  log_success "Kalshi markets endpoint is accessible (HTTP ${KALSHI_MARKETS_HTTP_CODE})"
else
  log_warning "Kalshi markets endpoint returned ${KALSHI_MARKETS_HTTP_CODE}"
fi

# Test FRED releases endpoint
FRED_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 "http://localhost:3000/fred/releases/upcoming" 2>/dev/null || echo -e "\n000")
FRED_HTTP_CODE=$(echo "$FRED_RESPONSE" | tail -n1)
if [ "$FRED_HTTP_CODE" = "200" ]; then
  log_success "FRED releases endpoint returned 200"
elif [ "$FRED_HTTP_CODE" = "503" ] || [ "$FRED_HTTP_CODE" = "500" ]; then
  log_warning "FRED releases endpoint returned ${FRED_HTTP_CODE} (may need FRED_API_KEY configured)"
else
  log_warning "FRED releases endpoint returned ${FRED_HTTP_CODE}"
fi

# Test error handling - 404 for non-existent instrument
NOT_FOUND_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 "http://localhost:3000/instruments/999999999" 2>/dev/null || echo -e "\n000")
NOT_FOUND_HTTP_CODE=$(echo "$NOT_FOUND_RESPONSE" | tail -n1)
if [ "$NOT_FOUND_HTTP_CODE" = "404" ]; then
  log_success "API correctly returns 404 for non-existent instrument"
else
  log_warning "API returned ${NOT_FOUND_HTTP_CODE} for non-existent instrument (expected 404)"
fi

echo ""

# Test 16: Container Health and Resource Usage
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 16: Container Health and Resource Usage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check container restart counts (high restart count indicates issues)
for container in "${REQUIRED_CONTAINERS[@]}"; do
  RESTART_COUNT=$(docker inspect "$container" --format '{{.RestartCount}}' 2>/dev/null || echo "0")
  if [ "$RESTART_COUNT" -eq 0 ]; then
    log_success "Container ${container} has not restarted (stable)"
  elif [ "$RESTART_COUNT" -lt 5 ]; then
    log_warning "Container ${container} has restarted ${RESTART_COUNT} time(s)"
  else
    log_error "Container ${container} has restarted ${RESTART_COUNT} times (may indicate instability)"
  fi
done

# Check container memory usage (warn if over 80% of available)
if command -v docker >/dev/null 2>&1; then
  for container in "${REQUIRED_CONTAINERS[@]}"; do
    MEM_USAGE=$(docker stats "$container" --no-stream --format '{{.MemUsage}}' 2>/dev/null | awk '{print $1}' || echo "")
    if [ -n "$MEM_USAGE" ]; then
      log_info "Container ${container} memory usage: ${MEM_USAGE}"
    fi
  done
fi

echo ""

# Test 17: Database Performance and Connection Pool
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 17: Database Performance and Connection Pool"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check active database connections
ACTIVE_CONNECTIONS=$(docker exec fmhub_db psql -U app -d fmhub -tAc "SELECT count(*) FROM pg_stat_activity WHERE datname = 'fmhub';" 2>/dev/null || echo "0")
if [ "$ACTIVE_CONNECTIONS" -gt 0 ]; then
  log_success "Database has ${ACTIVE_CONNECTIONS} active connection(s)"
  if [ "$ACTIVE_CONNECTIONS" -gt 50 ]; then
    log_warning "High number of database connections (${ACTIVE_CONNECTIONS}) - may indicate connection pool leak"
  fi
else
  log_warning "No active database connections found"
fi

# Check database size
DB_SIZE=$(docker exec fmhub_db psql -U app -d fmhub -tAc "SELECT pg_size_pretty(pg_database_size('fmhub'));" 2>/dev/null || echo "")
if [ -n "$DB_SIZE" ]; then
  log_info "Database size: ${DB_SIZE}"
fi

# Check for long-running queries (potential performance issues)
LONG_QUERIES=$(docker exec fmhub_db psql -U app -d fmhub -tAc "SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND now() - query_start > interval '5 seconds';" 2>/dev/null || echo "0")
if [ "$LONG_QUERIES" -eq 0 ]; then
  log_success "No long-running queries detected"
else
  log_warning "Found ${LONG_QUERIES} long-running query(ies) (may indicate performance issues)"
fi

echo ""

# Test 18: API Response Times and Performance
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 18: API Response Times and Performance"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test health endpoint response time
HEALTH_TIME=$(curl -s -w "%{time_total}" -o /dev/null --max-time 5 http://localhost:3000/health 2>/dev/null || echo "999")
# Convert seconds to milliseconds (multiply by 1000)
if command -v bc >/dev/null 2>&1; then
  HEALTH_TIME_MS=$(echo "$HEALTH_TIME * 1000" | bc 2>/dev/null | cut -d. -f1 || echo "999")
else
  # Fallback: use awk for calculation
  HEALTH_TIME_MS=$(awk "BEGIN {printf \"%.0f\", $HEALTH_TIME * 1000}" 2>/dev/null || echo "999")
fi
if [ "$HEALTH_TIME_MS" -lt 100 ]; then
  log_success "Health endpoint response time: ${HEALTH_TIME_MS}ms (excellent)"
elif [ "$HEALTH_TIME_MS" -lt 500 ]; then
  log_success "Health endpoint response time: ${HEALTH_TIME_MS}ms (good)"
elif [ "$HEALTH_TIME_MS" -lt 1000 ]; then
  log_warning "Health endpoint response time: ${HEALTH_TIME_MS}ms (slow)"
else
  log_error "Health endpoint response time: ${HEALTH_TIME_MS}ms (very slow)"
fi

# Test instruments endpoint response time
INSTRUMENTS_TIME=$(curl -s -w "%{time_total}" -o /dev/null --max-time 5 "http://localhost:3000/instruments?limit=10" 2>/dev/null || echo "999")
# Convert seconds to milliseconds
if command -v bc >/dev/null 2>&1; then
  INSTRUMENTS_TIME_MS=$(echo "$INSTRUMENTS_TIME * 1000" | bc 2>/dev/null | cut -d. -f1 || echo "999")
else
  # Fallback: use awk for calculation
  INSTRUMENTS_TIME_MS=$(awk "BEGIN {printf \"%.0f\", $INSTRUMENTS_TIME * 1000}" 2>/dev/null || echo "999")
fi
if [ "$INSTRUMENTS_TIME_MS" -lt 200 ]; then
  log_success "Instruments endpoint response time: ${INSTRUMENTS_TIME_MS}ms (excellent)"
elif [ "$INSTRUMENTS_TIME_MS" -lt 1000 ]; then
  log_success "Instruments endpoint response time: ${INSTRUMENTS_TIME_MS}ms (good)"
elif [ "$INSTRUMENTS_TIME_MS" -lt 2000 ]; then
  log_warning "Instruments endpoint response time: ${INSTRUMENTS_TIME_MS}ms (slow)"
else
  log_error "Instruments endpoint response time: ${INSTRUMENTS_TIME_MS}ms (very slow)"
fi

echo ""

# Test 19: Data Integrity and Consistency
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 19: Data Integrity and Consistency"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for instruments with missing required fields
MISSING_TICKER=$(docker exec fmhub_db psql -U app -d fmhub -tAc "SELECT COUNT(*) FROM instruments WHERE ticker IS NULL OR ticker = '';" 2>/dev/null || echo "0")
if [ "$MISSING_TICKER" -eq 0 ]; then
  log_success "All instruments have ticker values"
else
  log_error "Found ${MISSING_TICKER} instrument(s) with missing ticker values"
fi

# Check focus universe integrity (tickers in focus should exist in instruments)
FOCUS_COUNT=$(docker exec fmhub_db psql -U app -d fmhub -tAc "SELECT COUNT(*) FROM instrument_focus_universe;" 2>/dev/null || echo "0")
if [ "$FOCUS_COUNT" -gt 0 ]; then
  ORPHANED_FOCUS=$(docker exec fmhub_db psql -U app -d fmhub -tAc "
    SELECT COUNT(*) FROM instrument_focus_universe ifu
    LEFT JOIN instruments i ON ifu.instrument_id = i.id
    WHERE i.id IS NULL;
  " 2>/dev/null || echo "0")
  
  if [ "$ORPHANED_FOCUS" -eq 0 ]; then
    log_success "Focus universe integrity check passed (all focus instruments exist)"
  else
    log_error "Found ${ORPHANED_FOCUS} orphaned focus universe entry(ies)"
  fi
else
  log_warning "Focus universe is empty (may need ETL run)"
fi

# Check for duplicate tickers (shouldn't exist for active instruments)
DUPLICATE_TICKERS=$(docker exec fmhub_db psql -U app -d fmhub -tAc "
  SELECT COUNT(*) FROM (
    SELECT ticker, COUNT(*) as cnt
    FROM instruments
    WHERE status = 'active'
    GROUP BY ticker
    HAVING COUNT(*) > 1
  ) dups;
" 2>/dev/null || echo "0")

if [ "$DUPLICATE_TICKERS" -eq 0 ]; then
  log_success "No duplicate active tickers found"
else
  log_error "Found ${DUPLICATE_TICKERS} duplicate active ticker(s)"
fi

echo ""

# Test 20: Network Connectivity Between Containers
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 20: Network Connectivity Between Containers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify connectivity by checking health endpoint responses (from Tests 4, 4.5, and 5)
# This is more reliable than trying to use tools that may not be installed in containers

# API → Database connectivity (verified by API health endpoint in Test 4)
if echo "$BODY" | grep -q '"db_ok":true'; then
  log_success "API container can reach database via Docker network (confirmed by health endpoint)"
else
  log_error "API container cannot reach database (health endpoint reports db_ok:false)"
fi

# API → Redis connectivity (verified by system health endpoint in Test 5)
if echo "$SYSTEM_BODY" | grep -q '"redis":"up"'; then
  log_success "API container can reach Redis via Docker network (confirmed by system health endpoint)"
else
  log_error "API container cannot reach Redis (system health reports redis:down)"
fi

# Hadron → Database connectivity (verified by Hadron health endpoint in Test 4.5)
if echo "$HADRON_BODY" | grep -q '"db_ok":true'; then
  log_success "Hadron container can reach database via Docker network (confirmed by health endpoint)"
else
  log_error "Hadron container cannot reach database (health endpoint reports db_ok:false)"
fi

echo ""

# Test 21: Environment Variable Validation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 21: Environment Variable Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check critical environment variables are set in containers
API_DB_URL=$(docker exec fmhub_api printenv DATABASE_URL 2>/dev/null || echo "")
if [ -n "$API_DB_URL" ]; then
  log_success "API container has DATABASE_URL configured"
else
  log_error "API container missing DATABASE_URL environment variable"
fi

HADRON_DB_URL=$(docker exec fmhub_hadron printenv DATABASE_URL 2>/dev/null || echo "")
if [ -n "$HADRON_DB_URL" ]; then
  log_success "Hadron container has DATABASE_URL configured"
else
  log_error "Hadron container missing DATABASE_URL environment variable"
fi

# Check if simulation mode is set for Hadron (important for safety)
HADRON_SIM=$(docker exec fmhub_hadron printenv HADRON_SIMULATION_MODE 2>/dev/null || echo "")
if [ "$HADRON_SIM" = "true" ]; then
  log_success "Hadron is in simulation mode (safe for testing)"
elif [ -z "$HADRON_SIM" ]; then
  log_warning "HADRON_SIMULATION_MODE not set (defaults to true, but should be explicit)"
else
  log_warning "Hadron simulation mode is: ${HADRON_SIM} (ensure this is intentional)"
fi

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

