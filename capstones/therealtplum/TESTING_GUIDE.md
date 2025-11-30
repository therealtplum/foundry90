# Testing Guide - Verifying Functionality After Refactoring

This guide provides step-by-step instructions to verify all functionality still works after the performance refactoring changes.

---

## Quick Verification Checklist

- [ ] Code compiles without errors
- [ ] All services start successfully
- [ ] Health endpoints respond correctly
- [ ] Database connectivity works
- [ ] Hadron recorder processes ticks correctly
- [ ] Batch inserts work as expected
- [ ] Timeout-based flush mechanism works
- [ ] Regression test suite passes

---

## Quick Test (Recommended)

Run the comprehensive regression test suite:

```bash
cd capstones/therealtplum
./ops/run_regression.sh
```

This single command tests all critical functionality including infrastructure, APIs, Hadron components, and performance optimizations.

---

## 1. Compilation & Build Tests

### 1.1 Verify Hadron Compiles

```bash
cd capstones/therealtplum/apps/hadron
cargo check
```

**Expected:** Compiles with warnings only (no errors)

### 1.2 Verify Rust API Compiles

```bash
cd capstones/therealtplum/apps/rust-api
cargo check
```

**Expected:** Compiles successfully

### 1.3 Build Docker Images

```bash
cd capstones/therealtplum
docker compose build hadron
docker compose build api
```

**Expected:** Images build successfully

---

## 2. Service Startup Tests

### 2.1 Start All Services

```bash
cd capstones/therealtplum
docker compose up -d
```

**Expected:** All containers start without errors

### 2.2 Verify Container Status

```bash
docker compose ps
```

**Expected Output:**
```
NAME              STATUS
fmhub_db          Up
fmhub_redis        Up
fmhub_api          Up
fmhub_hadron       Up
fmhub_web          Up
```

### 2.3 Check Service Logs

```bash
# Check Hadron logs for startup messages
docker compose logs hadron | tail -20

# Check for any errors
docker compose logs hadron | grep -i error
```

**Expected:** 
- ✅ "Hadron Real-Time Intelligence System starting..."
- ✅ "Connected to Postgres"
- ✅ "Hadron Recorder started (batch_size=100, flush_interval=5s)"
- ✅ "Hadron Router started"
- ✅ "Hadron Engine (shard 0) started"
- ✅ "Hadron Normalizer started"
- ❌ No critical errors

---

## 3. Health Check Tests

### 3.1 API Health Check

```bash
curl http://localhost:3000/health
```

**Expected Response:**
```json
{
  "status": "ok",
  "db_ok": true
}
```

### 3.2 System Health Check

```bash
curl http://localhost:3000/system/health
```

**Expected:** Returns system health status with all components

### 3.3 Hadron Health Check

```bash
curl http://localhost:3002/system/health
```

**Expected Response:**
```json
{
  "status": "ok",
  "db_ok": true,
  "service": "hadron"
}
```

---

## 4. Database Connectivity Tests

### 4.1 Verify Database Connection

```bash
docker exec fmhub_db pg_isready -U app -d fmhub
```

**Expected:** `fmhub:5432 - accepting connections`

### 4.2 Verify Hadron Tables Exist

```bash
docker exec fmhub_db psql -U app -d fmhub -c "\dt hadron_*"
```

**Expected Tables:**
- `hadron_ticks`
- `hadron_order_intents`
- `hadron_order_executions`
- `hadron_strategy_decisions`

### 4.3 Check Table Structure

```bash
docker exec fmhub_db psql -U app -d fmhub -c "\d hadron_ticks"
```

**Expected:** Table structure matches schema with all required columns

---

## 5. Hadron Recorder Functionality Tests

### 5.1 Verify Recorder is Running

Check logs for recorder startup:

```bash
docker compose logs hadron | grep -i recorder
```

**Expected:** 
```
Hadron Recorder started (batch_size=100, flush_interval=5s)
```

### 5.2 Test Batch Insert Functionality

**Option A: Monitor Logs for Tick Processing**

```bash
# Watch Hadron logs in real-time
docker compose logs -f hadron | grep -E "(tick|flush|Recorder)"
```

**Option B: Insert Test Ticks via SQL (if you have test data)**

```bash
# Check if ticks are being inserted
docker exec fmhub_db psql -U app -d fmhub -c "
  SELECT COUNT(*) as total_ticks,
         COUNT(DISTINCT instrument_id) as unique_instruments,
         MIN(timestamp) as earliest,
         MAX(timestamp) as latest
  FROM hadron_ticks;
"
```

### 5.3 Verify Transaction-Based Batch Inserts

Check that multiple ticks are inserted in batches:

```bash
# Check recent inserts (should see batches of ~100)
docker exec fmhub_db psql -U app -d fmhub -c "
  SELECT 
    DATE_TRUNC('second', created_at) as insert_time,
    COUNT(*) as ticks_in_batch
  FROM hadron_ticks
  WHERE created_at > NOW() - INTERVAL '1 minute'
  GROUP BY DATE_TRUNC('second', created_at)
  ORDER BY insert_time DESC
  LIMIT 10;
"
```

**Expected:** Multiple ticks with the same `insert_time` (within 1 second), indicating batch inserts

### 5.4 Test Timeout-Based Flush

To test the 5-second timeout flush:

1. **Stop any tick sources** (if possible)
2. **Insert a small number of ticks** (less than batch_size=100)
3. **Wait 5-6 seconds**
4. **Check logs for flush message:**

```bash
docker compose logs hadron | grep -i "Timer-based flush"
```

**Expected:** 
```
Timer-based flush triggered with X ticks
```

---

## 6. Integration Tests

### 6.1 Run Regression Test Suite

```bash
cd capstones/therealtplum
./ops/run_regression.sh
```

**Expected:** All tests pass

**What it tests:**
- Container status
- Database connectivity
- Table existence
- API health endpoints
- Basic functionality

### 6.2 Manual Integration Test: Full Pipeline

1. **Ensure services are running:**
   ```bash
   docker compose up -d
   ```

2. **Verify Hadron is processing:**
   ```bash
   docker compose logs hadron | tail -50
   ```

3. **Check for any errors:**
   ```bash
   docker compose logs hadron | grep -iE "(error|panic|failed)"
   ```

4. **Verify data is being written:**
   ```bash
   # Wait a few minutes, then check
   docker exec fmhub_db psql -U app -d fmhub -c "
     SELECT 
       COUNT(*) as total_ticks,
       MAX(timestamp) as latest_tick
     FROM hadron_ticks;
   "
   ```

---

## 7. Performance Verification

### 7.1 Verify Batch Insert Performance

Compare insert patterns before/after (if you have baseline data):

```bash
# Check if we're seeing batch patterns (multiple rows with same created_at)
docker exec fmhub_db psql -U app -d fmhub -c "
  SELECT 
    created_at::timestamp(0) as batch_time,
    COUNT(*) as ticks_in_batch
  FROM hadron_ticks
  WHERE created_at > NOW() - INTERVAL '10 minutes'
  GROUP BY created_at::timestamp(0)
  ORDER BY batch_time DESC
  LIMIT 20;
"
```

**Expected:** Batches of ~100 ticks (or less if timeout flush occurred)

### 7.2 Monitor for Channel Lag

Check logs for lag warnings:

```bash
docker compose logs hadron | grep -i "lagged"
```

**Expected:** No lag warnings (or minimal lag during spikes)

---

## 8. Error Handling Tests

### 8.1 Test Graceful Shutdown

```bash
# Stop Hadron
docker compose stop hadron

# Check logs for graceful shutdown
docker compose logs hadron | tail -20
```

**Expected:**
- ✅ "Tick broadcast channel closed"
- ✅ Final flush of remaining ticks
- ✅ Clean shutdown

### 8.2 Test Database Reconnection

If database goes down temporarily:

```bash
# Stop database
docker compose stop db

# Wait a few seconds
sleep 5

# Restart database
docker compose start db

# Check Hadron logs for reconnection
docker compose logs hadron | tail -30
```

**Expected:** Hadron reconnects and continues processing

---

## 9. Web UI Verification

### 9.1 Access Web Interface

Open browser: http://localhost:3001

**Expected:** 
- ✅ Page loads
- ✅ No console errors
- ✅ API calls succeed

### 9.2 Check Browser Console

Open browser DevTools (F12) → Console tab

**Expected:** No critical errors

---

## 10. Comprehensive Test Suite

The regression test suite (`ops/run_regression.sh`) provides comprehensive testing of all functionality. It includes all the tests that were previously in `test_functionality.sh`, plus additional infrastructure and API tests.

**Usage:**
```bash
cd capstones/therealtplum
./ops/run_regression.sh
```

This single command tests:
- All infrastructure components (db, redis, api, web, hadron)
- Code compilation (when Rust is available)
- All API endpoints including Hadron
- Hadron-specific functionality (recorder, batch inserts, pipeline components)
- Performance optimizations (batch insert patterns, timeout flush)
- Database connectivity and schema validation
- Redis caching
- Web frontend

The test suite provides detailed pass/fail/warning reporting and generates a JSON results file at `logs/regression_results.json`.

---

## 11. Troubleshooting

### Issue: Hadron won't start

**Check:**
```bash
docker compose logs hadron
```

**Common causes:**
- Database not ready (wait a few seconds)
- Missing environment variables
- Port conflicts

### Issue: No ticks being inserted

**Check:**
1. Are data sources connected? (Polygon/Kalshi WebSocket)
2. Check normalizer logs:
   ```bash
   docker compose logs hadron | grep -i normalizer
   ```
3. Check for instrument lookup failures:
   ```bash
   docker compose logs hadron | grep -i "instrument not found"
   ```

### Issue: Batch inserts not working

**Verify:**
1. Check transaction usage in logs (should see batches)
2. Verify database has proper indexes
3. Check for database connection issues

---

## 12. Success Criteria

✅ **All tests pass if:**
- Code compiles without errors
- All services start successfully
- Health endpoints return "ok"
- Database connectivity works
- Recorder processes ticks
- Batches are inserted in transactions
- Timeout flush works
- No critical errors in logs
- Regression suite passes

---

## Quick Test Command

For a quick smoke test, run:

```bash
cd capstones/therealtplum && \
  cargo check --manifest-path apps/hadron/Cargo.toml && \
  docker compose ps | grep -q "Up" && \
  curl -s http://localhost:3002/system/health | grep -q "ok" && \
  echo "✅ Quick test passed!"
```

---

**Last Updated:** December 2025  
**Related:** See `PERFORMANCE_REVIEW.md` for details on changes made

