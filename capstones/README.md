# therealtplum Capstone – Foundry90

This folder contains my personal implementation of the Foundry90 capstone.

The goal is to build a **fully integrated prediction markets / event-driven system** using:

- **Next.js** – frontend UI + admin tools  
- **Rust + Axum** – backend API service  
- **Python** – ETL + data ingestion and normalization  
- **Postgres** – system of record  
- **Redis** – caching layer  
- **Docker Compose** – local dev environment  
- **AWS (ECS/RDS)** – deployment target  

This capstone emphasizes:

- architectural clarity  
- predictable data flows  
- reliability and observability  
- production-like structure  
- iterating from skeleton → full system  

---

## 📂 Structure

```
apps/
  web/         # Next.js frontend (✅ implemented)
  rust-api/    # Rust API service (✅ implemented)
  python-etl/  # ETL pipeline (✅ implemented)
  hadron/      # Real-time intelligence engine (✅ implemented)

services/
  db/          # DB migrations, seeds (✅ implemented)

docs/
  architecture.md
  design-decisions.md
  runbook_v2.md  # Operations guide
```

---

## 🚧 Status

**Current State:** ✅ **Operational** - Core system is built and running

**Implemented:**
- ✅ Next.js frontend with instrument browser and dashboard
- ✅ Rust API service with health endpoints and instrument data
- ✅ Python ETL pipeline for Polygon data ingestion
- ✅ Hadron real-time intelligence engine (Polygon + Kalshi integration)
- ✅ PostgreSQL database with full schema
- ✅ Redis caching layer
- ✅ Docker Compose local development environment

**See `docs/runbook_v2.md` for operations guide and how to run the system.**

---

## 🧭 How to Run

See `docs/runbook_v2.md` for complete operations guide.

**Quick Start:**
```bash
cd capstones/therealtplum
docker compose up -d
./ops/run_full_etl.sh
```

**Services:**
- Web UI: http://localhost:3001
- API: http://localhost:3000
- Hadron: http://localhost:3002/system/health

---

## 📝 Notes to Self

- Maintain clean commits with explanatory messages  
- Document design decisions as they occur  
- Focus on simplicity and readability  
