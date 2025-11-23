# Foundry90 – Weekly Exercises

Each week has:

- Core exercises (recommended)
- Stretch exercises (optional but powerful)
- One concrete deliverable

Your capstone is **not** meant to match anyone else’s – treat these as scaffolding.

---

## Week 1 – Next.js + TypeScript

**Goal:** Build a basic admin dashboard, learn routing, layouts, server/client components.

### Core exercises

- Create `/dashboard` route using the App Router.
- Add a layout with header/nav/footer.
- Build one Server Component that fetches mock data (from a local array or simple API).
- Build one Client Component that handles user interaction (toggle, filter, etc.).
- Create `/api/health` route returning JSON.
- Type all components & responses with proper TypeScript interfaces (no `any`).

### Stretch exercises

- Add a dark mode toggle via client state.
- Build a reusable `<Card />` component.
- Create a simple form that submits via a Next.js server action or API route.

### Deliverable

`Admin Dashboard v1` – a simple, but real, dashboard layout backed by a tiny API route.

---

## Week 2 – Rust Backend (Axum)

**Goal:** Build a small API with clean routing and error handling.

### Core exercises

- Create a new crate: `apps/rust-api`.
- Add Axum, Tokio, Serde, Thiserror, and Tracing (or similar logging).
- Implement routes:
  - `GET /health` – returns a simple JSON health object.
  - `GET /markets` – returns mock list of markets.
  - `GET /markets/:id` – returns a single mock market.
- Define a custom error enum using `thiserror`.
- Add structured logging with `tracing`.

### Stretch exercises

- Add middleware for request logging (including method, path, status).
- Add an extractor for a custom header (e.g., `X-Request-Id`).
- Implement one background task (e.g., periodic log or mock polling) using `tokio::spawn`.

### Deliverable

`Prediction API v1` – an Axum-based API that feels like a real service, even if the data is mocked.

---

## Week 3 – Python ETL

**Goal:** Build a simple ETL pipeline into Postgres.

### Core exercises

- Write a script that fetches sample event/market data from:
  - a public API, or
  - a local JSON file if an external API is annoying.
- Normalize and clean the data using pandas.
- Set up a Postgres table locally (via docker-compose or local install).
- Insert the transformed data into Postgres.
- Add logging for:
  - when the fetch starts/ends
  - how many records you processed
  - basic error cases.

### Stretch exercises

- Build a CLI wrapper with commands like:
  - `etl run`
  - `etl status`
- Add retry logic for failed network calls.
- Add a simple scheduling loop (e.g., run every N minutes).

### Deliverable

`ETL v1` – a Python script or package that can fetch, transform, and load data into Postgres reliably.

---

## Week 4 – Database

**Goal:** Design your capstone’s core schema.

### Core exercises

- Design tables for your domain (prediction markets suggested):
  - markets
  - events
  - prices
  - settlements
  - positions (or any domain-equivalent entities)
- Write migrations to create these tables.
- Add primary keys and foreign keys.
- Add at least 2–3 indexes:
  - obvious primary keys
  - indexes on common query filters (e.g., `market_id`, `status`).
- Write SQL queries for:
  - list of markets (with filters)
  - detailed view of a single market
  - recent prices for a market
  - anything you know you’ll need in the frontend.

### Stretch exercises

- Write a materialized view, e.g., “latest price per market”.
- Write a trigger (e.g., maintain a last_updated column).
- Add a data seeding script.

### Deliverable

`DB Schema v1` – your first serious schema with real queries and migrations.

---

## Week 5 – Environment & Monorepo

**Goal:** Get your whole stack into one repo with clean environment handling.

### Core exercises

- Create monorepo structure:

  ```text
  apps/
    web/
    rust-api/
    python-etl/
  services/
    db/