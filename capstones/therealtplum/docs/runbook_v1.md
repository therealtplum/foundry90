# FMHub Run Book — Updated and Correct (Current)

## 0. Navigate to Repo Root
```
cd ~/Documents/python/projects/foundry90/capstones/therealtplum
```

---

# 🚀 Fresh Startup (Full Reset — Preferred)

Use your all‑in‑one alias:

```
foundry90_reset
```

This performs:
- full container teardown (`docker compose down -v`)
- full rebuild (`--no-cache`)
- stack startup (`docker compose up -d`)
- waits for Postgres (`pg_isready`)
- loads database schema
- runs full ETL pipeline:
  - polygon_instruments
  - polygon_news
  - instrument_focus_universe
  - prewarm_instrument_insights (or stub)
- prints status as it goes

This replaces all old multi-step instructions.

---

# ⚙️ Manual Startup (If Needed)

### 1. Bring stack up manually
```
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

### 2. Confirm Postgres readiness
```
docker exec fmhub_db pg_isready -U app -d fmhub
```

### 3. Load schema manually
```
docker exec -i fmhub_db psql -U app -d fmhub < services/db/schema.sql
```

### 4. Run ETL manually
```
docker compose run --rm etl python -m etl.polygon_instruments
docker compose run --rm etl python -m etl.polygon_news
docker compose run --rm etl python -m etl.instrument_focus_universe
docker compose run --rm etl python -m etl.prewarm_instrument_insights
```

---

# 🧪 Local Rust API Build (Optional)

Only needed when testing Rust locally (not for Docker API build):

```
cd apps/rust-api/
cargo clean
cargo build
```

---

# 🌐 Verify Services

### API
http://localhost:3000/health

### Web UI
http://localhost:3001

---

# 🛑 Clean Shutdown
```
docker compose down -v
```

---

# 🏷️ Correct Alias Block (Place in ~/.zshrc)

```
export foundry90_root="$HOME/Documents/python/projects/foundry90/capstones/therealtplum"

alias foundry90_start='cd "$foundry90_root" && docker compose up -d'
alias foundry90_build='cd "$foundry90_root" && docker compose build --no-cache'
alias foundry90_etl='cd "$foundry90_root" && docker compose run --rm etl'
alias foundry90_reset="... your full reset command ..."

alias treeclean='find . -name "__pycache__" -prune -exec rm -rf {} \;'
```

---

# ✔️ Summary
This version fixes:
- wrong web/API ports
- outdated ETL instructions
- outdated docker commands
- missing schema-loading behavior
- incorrect sequence of startup steps
- alias block inconsistencies

This file is now the authoritative FMHub run book.
