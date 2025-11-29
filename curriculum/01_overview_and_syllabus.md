# Foundry90 – Overview & Syllabus

Foundry90 is a 90-day, three-phase program to turn you into a **full-stack, platform-capable engineer**.

You’ll work with:

- Next.js + TypeScript (App Router, server and client components)
- Rust (Axum + Tokio)
- Python (ETL, HTTP, Websockets)
- Postgres + Redis
- Docker, AWS ECS/RDS, Vercel
- Optional: SwiftUI native client

The goal is **breadth + glue + engineering judgment**, not narrow specialization.

---

## Program structure

### Phase 1 – Fundamentals in Context (Weeks 1–4)

Build fluency in each core piece, but always in service of *systems*, not toy scripts.

- **Week 1 – Next.js + TypeScript**
  - Routing, layouts, server vs client components, basic API routes, Tailwind.
  - Deliverable: `Admin Dashboard v1`.

- **Week 2 – Rust backend (Axum)**
  - Async, routing, modular design, error handling, logging.
  - Deliverable: `Prediction API v1`.

- **Week 3 – Python ETL**
  - HTTP + Websockets, pandas, scheduled jobs.
  - Deliverable: `ETL v1` into Postgres.

- **Week 4 – Postgres**
  - Schema design, indexing, migrations, queries.
  - Deliverable: `DB Schema v1`.

---

### Phase 2 – Glue & Ops (Weeks 5–8)

Learn how systems actually run and stay alive.

- **Week 5 – Environment management & monorepo**
  - Repo layout, workspaces, `.env`, scripts.
  - Deliverable: `Monorepo v1`.

- **Week 6 – Docker & docker-compose**
  - Containerizing each service, multi-service dev setup.
  - Deliverable: `Containerized Stack v1` (one command to bring everything up).

- **Week 7 – Deployment (Vercel + AWS)**
  - Vercel for frontend, ECS for backend, RDS for Postgres.
  - Deliverable: `Production Deployment v1`.

- **Week 8 – Observability**
  - Logging, health checks, basic monitoring/alerts.
  - Deliverable: `Monitoring v1`.

---

### Phase 3 – Systems & Capstone (Weeks 9–12)

Integrate everything into a real platform capstone.

- **Week 9 – Backend v2**
  - Caching, pagination, background tasks.
  - Deliverable: `API v2`.

- **Week 10 – Frontend v2**
  - Real market explorer (or your equivalent domain), admin tools, better UX.
  - Deliverable: `Frontend v2`.

- **Week 11 – SwiftUI client (optional but recommended)**
  - Native list/detail UI backed by your API.
  - Deliverable: `Native Client v1`.

- **Week 12 – Capstone integration**
  - Wire everything, polish, document, and create a demo.
  - Deliverable: `Capstone v1`.

---

## Learning outcomes

By Day 90, you should be able to:

- Design and implement a multi-service web system.
- Use Rust, Python, TypeScript, SQL, and Redis **together**.
- Deploy services to the cloud, monitor them, and debug issues.
- Make reasonable architectural decisions with trade-offs in mind.
- Build and present your own capstone: a small but realistic platform.

If you're unsure whether this is too advanced, read:

- [`prerequisites.md`](./prerequisites.md)
- [`glossary.md`](./glossary.md)

---

## Next Steps

1. Read [`prerequisites.md`](./prerequisites.md) to confirm this is right for you
2. Review [`02_readings.md`](./02_readings.md) to see what resources you'll use
3. Start [`03_weekly_exercises.md`](./03_weekly_exercises.md) – Week 1
4. Use [`06_rubric.md`](./06_rubric.md) to track your progress
5. Reference [`07_capstone_guide.md`](./07_capstone_guide.md) as you build your project