# Foundry90 – Capstone Guide

The capstone is a **system you design and build** using the skills from the 90-day program.

The default example in this curriculum is a **prediction/event markets platform**, but you’re encouraged to adapt it to your own idea:

- event / prediction markets
- analytics dashboard for trading
- sports markets system
- pricing/risk platform
- or any small, realistic multi-service system

---

## Core requirements

Your capstone should:

- Have a web UI (Next.js or similar).
- Expose a backend API (Rust or similar).
- Use a real database (Postgres).
- Include some kind of data pipeline (Python or equivalent).
- Be containerized (Docker).
- Be deployable to the cloud.
- Have basic logging/observability.

You are **not** required to implement trading, balances, or real money logic. The focus is on **system design, integration, and operations**.

---

## Suggested feature set (prediction-market flavored)

If you follow the prediction market flavor, your system might include:

- Browse list of markets (events/contracts).
- View details for one market:
  - description
  - category
  - current prices/probabilities
  - basic history
- Real-time or near-real-time updates.
- Basic admin tools:
  - create/edit/close markets
  - view data quality issues
- Some notion of “state change over time,” like price history, resolved vs unresolved, etc.

You can swap “markets” for any primary entity in your domain.

---

## Architectural expectations

You’re aiming for a small but realistic multi-service architecture:

- Frontend:
  - Next.js, hitting your backend API.
- Backend:
  - Rust API, exposing typed JSON endpoints, talking to Postgres and optionally Redis.
- Data pipeline:
  - Python ETL that pulls data from external APIs or files into your DB.
- Infra:
  - Dockerized services.
  - Local dev via docker-compose.
  - Cloud deployment (Vercel + AWS or similar).
- Optional:
  - Native SwiftUI client.

---

## Milestones

Connect this to the weekly exercises:

- By end of Week 4:
  - You have a working UI prototype, a basic Rust API, an ETL script, and a real schema.
- By end of Week 8:
  - Your stack is containerized, deployed, and monitored.
- By end of Week 12:
  - Your capstone feels like a cohesive product:
    - data flows end-to-end
    - you can demo it
    - it has a README and at least one diagram.

---

## Deliverables at the end

Your capstone should minimally include:

- A top-level `README.md` in your capstone directory:
  - what the system does
  - how to run it locally
  - how to deploy it
- A working dev setup:
  - docker-compose or equivalent
- Deployed environment (even if small/cheap):
  - frontend
  - backend
  - DB
- At least one architecture diagram:
  - hand-drawn, Mermaid, or image – it doesn’t matter, as long as it communicates.

Optionally:

- A short demo script:
  - “Here’s the UI; here’s what happens when I click X; here’s the API; here are logs; here’s the data pipeline.”
- Notes on trade-offs:
  - Why this schema?
  - Why this shape of services?
  - What you would do differently with more time.

This is your project – it doesn't need to look like anyone else's. Foundry90 is about making your own engineering decisions and learning from them.

---

## Related Documentation

- **Weekly Exercises:** Follow [`03_weekly_exercises.md`](./03_weekly_exercises.md) to build your capstone incrementally
- **Architecture:** See [`05_architecture.md`](./05_architecture.md) for system design guidance
- **Repo Structure:** See [`04_repo_template.md`](./04_repo_template.md) for organization
- **Rubric:** Use [`06_rubric.md`](./06_rubric.md) to evaluate your progress
- **Starter Kit:** Get started with [`../starter-kit/README.md`](../starter-kit/README.md)