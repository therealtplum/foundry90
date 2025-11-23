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
  web/         # Next.js frontend (to be initialized)
  rust-api/    # Rust API service (to be scaffolded)
  python-etl/  # ETL pipeline (to be scaffolded)

services/
  db/          # DB migrations, seeds

infra/
  docker/      # Dockerfiles and infra notes

docs/
  architecture.md
  design-decisions.md
```

---

## 🚧 Status

This capstone is currently scaffolded and will be developed through the Foundry90 program milestones:

- Week 1–3 → foundations  
- Week 4–6 → local monorepo + basic system  
- Week 7–9 → cloud infra + ETL  
- Week 10–12 → full integration + polish  

---

## 🧭 How to Run (placeholder)

This will be updated once the initial services are in place.

---

## 📝 Notes to Self

- Maintain clean commits with explanatory messages  
- Document design decisions as they occur  
- Focus on simplicity and readability  
