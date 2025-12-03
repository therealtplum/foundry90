# FMHub Runbook v2 — Comprehensive Operations Guide

## Table of Contents
1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Environment Setup](#environment-setup)
4. [Service Architecture](#service-architecture)
5. [Startup Procedures](#startup-procedures)
6. [ETL Operations](#etl-operations)
7. [Database Operations](#database-operations)
8. [Development Workflows](#development-workflows)
9. [Troubleshooting](#troubleshooting)
10. [Useful Aliases](#useful-aliases)

---

## Quick Start

### Full Reset (Recommended for Fresh Start)
```bash
cd capstones/therealtplum
docker compose down -v
docker compose build --no-cache
docker compose up -d
./ops/run_full_etl.sh
```

### Quick Start (If Services Already Built)
```bash
cd capstones/therealtplum
docker compose up -d
```

---

## Prerequisites

- Docker and Docker Compose installed
- Required environment variables set (see [Environment Setup](#environment-setup))
- Access to Polygon.io API (for ETL operations)
- Optional: OpenAI API key (for LLM insights)

---

## Environment Setup

### Required Environment Variables

Create a `.env` file in `capstones/therealtplum/` with:

```bash
# Required for ETL
POLYGON_API_KEY=your_polygon_api_key_here

# Required for LLM insights (optional, falls back to cache-only if not set)
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_MODEL=gpt-4.1-mini

# Optional: Vercel integration (for system health checks)
VERCEL_API_TOKEN=your_vercel_token
VERCEL_PROJECT_ID=your_project_id
VERCEL_TEAM_ID=your_team_id
SKIP_VERCEL_COMPARE=false

# Optional: ETL tuning
PRICE_PREV_MAX_INSTRUMENTS=2000
PRICE_PREV_SLEEP_SECS=0.02
PRICE_PREV_BATCH_SIZE=500
```

### Loading Environment Variables

Use the provided script to reload environment variables into your shell:
```bash
./ops/reloadenv.sh
```

---

## Service Architecture

### Services Overview

| Service | Container Name | Port | Description |
|---------|---------------|------|-------------|
| **db** | `fmhub_db` | 5433:5432 | PostgreSQL 16 database |
| **redis** | `fmhub_redis` | 6379:6379 | Redis 7 cache |
| **api** | `fmhub_api` | 3000:3000 | Rust/Axum API server |
| **web** | `fmhub_web` | 3001:3000 | Next.js frontend |
| **etl** | `fmhub_etl` | N/A | Python ETL container (one-shot jobs) |
| **hadron** | `fmhub_hadron` | 3002:3002 | Hadron real-time intelligence engine |

### Service Dependencies

```
web → api → db, redis
api → db, redis
etl → db
hadron → db, redis
```

---

## Startup Procedures

### Method 1: Full Reset (Clean Slate)

**Use this when:**
- Starting fresh
- After schema changes
- When experiencing data inconsistencies
- After pulling major updates

```bash
cd capstones/therealtplum

# 1. Tear down everything (including volumes)
docker compose down -v

# 2. Rebuild all images from scratch
docker compose build --no-cache

# 3. Start all services
docker compose up -d

# 4. Wait for Postgres (automatic in run_full_etl.sh)
# 5. Run full ETL pipeline
./ops/run_full_etl.sh
```

### Method 2: Standard Startup

**Use this when:**
- Services are already built
- Just restarting after a stop
- No schema or code changes

```bash
cd capstones/therealtplum
docker compose up -d
```

### Method 3: Database-Only Startup

**Use this for:**
- Local development without full stack
- Testing ETL jobs independently

```bash
cd capstones/therealtplum
make db-up
# or
docker compose up -d db redis
```

### Verifying Services

**API Health Check:**
```bash
curl http://localhost:3000/health
```

**System Health (includes frontend check):**
```bash
curl http://localhost:3000/system/health
```

**Web UI:**
Open http://localhost:3001 in your browser

**Database Connection:**
```bash
docker exec fmhub_db pg_isready -U app -d fmhub
```

---

## ETL Operations

### Available ETL Modules

1. **`polygon_instruments`** — Fetches instrument metadata from Polygon.io
2. **`polygon_news`** — Fetches news articles (currently stub)
3. **`polygon_price_prev_daily`** — Fetches previous day's price data
4. **`instrument_focus_universe`** — Calculates focus universe based on latest prices
5. **`prewarm_instrument_insights`** — Pre-generates LLM insights for focus instruments
6. **`export_sample_tickers_json`** — Exports sample tickers to JSON for web app

### Running ETL Jobs

#### Full ETL Pipeline (Recommended)
```bash
./ops/run_full_etl.sh
```

This script:
- Ensures DB is running and ready
- Auto-loads schema if missing
- Runs all core ETL modules in order:
  1. `polygon_instruments`
  2. `polygon_news`
  3. `instrument_focus_universe`
  4. `prewarm_instrument_insights`

#### Individual ETL Modules

```bash
# Instruments
docker compose run --rm etl python -m etl.polygon.polygon_instruments

# News (stub)
docker compose run --rm etl python -m etl.polygon.polygon_news

# Price data
docker compose run --rm etl python -m etl.polygon.polygon_price_prev_daily

# Focus universe
docker compose run --rm etl python -m etl.core.instrument_focus_universe

# Prewarm insights
docker compose run --rm etl python -m etl.core.prewarm_instrument_insights

# Export sample tickers
docker compose run --rm etl python -m etl.core.export_sample_tickers_json
# or use the wrapper script:
./ops/export_sample_tickers_json.sh
```

#### Weekly Maintenance

Run focus universe refresh and insight prewarming:
```bash
./ops/run_weekly_focus_and_prewarm.sh
```

This logs to `logs/weekly_focus_and_prewarm.log`

---

## Database Operations

### Using the Makefile

The project includes a `Makefile` with convenient database commands:

```bash
# Start only DB + Redis
make db-up

# Stop DB + Redis
make db-down

# Apply schema.sql to running database
make db-apply-schema

# Open psql shell
make db-shell

# Drop and recreate database (with confirmation)
make db-reset

# Nuke entire Postgres volume (with confirmation)
make db-nuke
```

### Manual Database Operations

**Load Schema:**
```bash
docker exec -i fmhub_db psql -U app -d fmhub < services/db/schema.sql
```

**Check Schema:**
```bash
docker exec fmhub_db psql -U app -d fmhub -c "\dt"
```

**Open psql Shell:**
```bash
docker compose exec db psql -U app -d fmhub
```

**Check Database Size:**
```bash
docker exec fmhub_db psql -U app -d fmhub -c "SELECT pg_size_pretty(pg_database_size('fmhub'));"
```

**View Recent Focus Snapshots:**
```bash
docker exec fmhub_db psql -U app -d fmhub -c "SELECT id, snapshot_date, instrument_count FROM instrument_focus_snapshots ORDER BY snapshot_date DESC LIMIT 5;"
```

---

## Development Workflows

### Rebuilding Individual Services

**Rebuild API:**
```bash
docker compose build --no-cache api
docker compose up -d api
```

**Rebuild Web:**
```bash
docker compose build --no-cache web
docker compose up -d web
```

**Rebuild ETL:**
```bash
docker compose build --no-cache etl
```

### Rebuilding Web with Git Info

Use the provided script to rebuild web with current git commit/branch:
```bash
./ops/rebuild_web_with_git.sh
```

### Local Rust API Development

If developing the Rust API locally (outside Docker):

```bash
cd apps/rust-api
cargo clean
cargo build
# or
cargo run
```

**Note:** Ensure DB is accessible at `localhost:5433` when running locally.

### Viewing Logs

**All Services:**
```bash
docker compose logs -f
```

**Specific Service:**
```bash
docker compose logs -f api
docker compose logs -f web
docker compose logs -f db
docker compose logs -f etl
```

**ETL Job Logs:**
```bash
tail -f logs/weekly_focus_and_prewarm.log
tail -f logs/instrument_focus_weekly.log
```

### Clean Shutdown

**Graceful Shutdown:**
```bash
docker compose down
```

**Full Teardown (including volumes):**
```bash
docker compose down -v
```

**Emergency Panic (kills everything):**
```bash
./ops/panic.sh
```

---

## Troubleshooting

### Services Won't Start

1. **Check Docker is running:**
   ```bash
   docker ps
   ```

2. **Check for port conflicts:**
   ```bash
   lsof -i :3000  # API
   lsof -i :3001  # Web
   lsof -i :5433  # DB
   lsof -i :6379  # Redis
   ```

3. **Check container logs:**
   ```bash
   docker compose logs
   ```

### Database Connection Issues

1. **Verify Postgres is ready:**
   ```bash
   docker exec fmhub_db pg_isready -U app -d fmhub
   ```

2. **Check if schema exists:**
   ```bash
   docker exec fmhub_db psql -U app -d fmhub -c "SELECT to_regclass('public.instruments') IS NOT NULL;"
   ```
   Should return `t` (true). If `f` (false), load schema:
   ```bash
   make db-apply-schema
   ```

3. **Reset database if corrupted:**
   ```bash
   make db-reset
   make db-apply-schema
   ```

### ETL Failures

1. **Check POLYGON_API_KEY is set:**
   ```bash
   docker compose run --rm etl env | grep POLYGON_API_KEY
   ```

2. **Check ETL container logs:**
   ```bash
   docker compose logs etl
   ```

3. **Run ETL with verbose output:**
   ```bash
   docker compose run --rm etl python -m etl.polygon.polygon_instruments
   ```

### API Not Responding

1. **Check API health:**
   ```bash
   curl http://localhost:3000/health
   ```

2. **Check API logs:**
   ```bash
   docker compose logs -f api
   ```

3. **Verify API can connect to DB:**
   ```bash
   docker compose logs api | grep -i "connected\|error"
   ```

### Web UI Not Loading

1. **Check web container:**
   ```bash
   docker compose logs web
   ```

2. **Verify API is accessible from web:**
   ```bash
   docker compose exec web curl http://localhost:3000/health
   ```
   (Note: This checks internal networking. External access uses `http://localhost:3000`)

3. **Rebuild web:**
   ```bash
   docker compose build --no-cache web
   docker compose up -d web
   ```

### Environment Variable Issues

1. **Reload environment:**
   ```bash
   ./ops/reloadenv.sh
   ```

2. **Verify variables are set:**
   ```bash
   docker compose config | grep -A 5 "POLYGON_API_KEY\|OPENAI_API_KEY"
   ```

3. **Restart services after env changes:**
   ```bash
   docker compose down
   docker compose up -d
   ```

### Container Stuck or Unresponsive

1. **Force remove and restart:**
   ```bash
   docker compose down
   docker compose up -d
   ```

2. **Nuclear option:**
   ```bash
   ./ops/panic.sh
   docker compose down -v
   docker compose build --no-cache
   docker compose up -d
   ```

---

## Useful Aliases

Add these to your `~/.zshrc` or `~/.bashrc`:

```bash
# Set this to your capstone root
export FOUNDRY90_ROOT="/path/to/foundry90/capstones/therealtplum"

# Navigation
alias f90='cd "$FOUNDRY90_ROOT"'

# Docker Compose shortcuts
alias f90-up='cd "$FOUNDRY90_ROOT" && docker compose up -d'
alias f90-down='cd "$FOUNDRY90_ROOT" && docker compose down'
alias f90-logs='cd "$FOUNDRY90_ROOT" && docker compose logs -f'
alias f90-restart='cd "$FOUNDRY90_ROOT" && docker compose restart'

# Full reset (teardown, rebuild, start, ETL)
alias f90-reset='cd "$FOUNDRY90_ROOT" && \
  docker compose down -v && \
  docker compose build --no-cache && \
  docker compose up -d && \
  sleep 5 && \
  ./ops/run_full_etl.sh'

# ETL operations
alias f90-etl='cd "$FOUNDRY90_ROOT" && ./ops/run_full_etl.sh'
alias f90-etl-weekly='cd "$FOUNDRY90_ROOT" && ./ops/run_weekly_focus_and_prewarm.sh'

# Database operations
alias f90-db-shell='cd "$FOUNDRY90_ROOT" && make db-shell'
alias f90-db-schema='cd "$FOUNDRY90_ROOT" && make db-apply-schema'

# Cleanup
alias f90-clean='cd "$FOUNDRY90_ROOT" && find . -name "__pycache__" -prune -exec rm -rf {} \;'
alias f90-panic='cd "$FOUNDRY90_ROOT" && ./ops/panic.sh'
```

**Note:** Replace `/path/to/foundry90/capstones/therealtplum` with your actual path.

---

## Summary of Key Commands

| Task | Command |
|------|---------|
| **Full Reset** | `docker compose down -v && docker compose build --no-cache && docker compose up -d && ./ops/run_full_etl.sh` |
| **Start Services** | `docker compose up -d` |
| **Stop Services** | `docker compose down` |
| **Run Full ETL** | `./ops/run_full_etl.sh` |
| **Check API Health** | `curl http://localhost:3000/health` |
| **Open DB Shell** | `make db-shell` |
| **View Logs** | `docker compose logs -f` |
| **Rebuild Service** | `docker compose build --no-cache <service>` |

---

## Additional Resources

- **Architecture Docs:** `docs/architecture.md`
- **Scope:** `docs/scope.md`
- **Ops Scripts:** `ops/` directory
- **Makefile:** `Makefile` (database utilities)

---

**Last Updated:** 2025
**Version:** 2.0

