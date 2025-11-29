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
  infra/
    docker/
  ```

- Set up workspace configurations:
  - `package.json` with pnpm workspaces for Node.js apps
  - `Cargo.toml` with workspace members for Rust apps
- Create `.env.example` file documenting all required environment variables
- Set up environment variable loading in each app:
  - Next.js: `.env.local` or `.env`
  - Rust: Use `dotenv` crate or environment variables
  - Python: Use `python-dotenv` or environment variables
- Create a root-level `README.md` explaining:
  - How to set up the monorepo
  - How to run each service
  - Required environment variables

### Stretch exercises

- Add a `Makefile` or scripts directory with common commands:
  - `make dev` – start all services
  - `make test` – run tests across all apps
  - `make clean` – clean build artifacts
- Set up shared TypeScript types between frontend and backend (if applicable)
- Create a shared constants file or module for common values

### Deliverable

`Monorepo v1` – a well-organized monorepo with all services, proper environment handling, and clear documentation.

---

## Week 6 – Docker & docker-compose

**Goal:** Containerize each service and run the full stack with one command.

### Core exercises

- Create a `Dockerfile` for each app:
  - `apps/web/Dockerfile` – multi-stage build for Next.js
  - `apps/rust-api/Dockerfile` – build Rust binary
  - `apps/python-etl/Dockerfile` – Python runtime with dependencies
- Create or update `docker-compose.yml` at the root:
  - Define all services (web, rust-api, python-etl, db, redis)
  - Set up service dependencies (e.g., API depends on DB)
  - Configure environment variables
  - Expose necessary ports
- Test that `docker-compose up` brings up the entire stack
- Verify services can communicate with each other (e.g., API can reach DB)

### Stretch exercises

- Use multi-stage builds to optimize image sizes
- Add health checks to services in `docker-compose.yml`
- Create separate `docker-compose.override.yml` for local development
- Add volume mounts for hot-reloading during development
- Set up a `.dockerignore` file for each service

### Deliverable

`Containerized Stack v1` – one command (`docker-compose up`) brings up your entire system locally.

---

## Week 7 – Deployment (Vercel + AWS)

**Goal:** Deploy your system to production (or a staging environment).

### Core exercises

- **Frontend (Vercel):**
  - Connect your Next.js app to Vercel
  - Configure environment variables in Vercel dashboard
  - Set up build settings and deploy
  - Verify the deployed frontend can reach your API

- **Backend (AWS ECS or similar):**
  - Create an ECS task definition (or use your cloud provider's equivalent)
  - Set up a container registry (ECR, Docker Hub, etc.)
  - Push your Rust API image
  - Deploy the API service
  - Configure environment variables and secrets

- **Database (AWS RDS or similar):**
  - Create a managed Postgres instance (RDS, or your provider's equivalent)
  - Run migrations against the production database
  - Configure connection strings and security groups

- **Basic security:**
  - Use secrets management (AWS Secrets Manager, Vercel env vars)
  - Ensure database is not publicly accessible
  - Use HTTPS for all services

### Stretch exercises

- Set up a CI/CD pipeline (GitHub Actions, GitLab CI, etc.)
- Configure custom domain names
- Set up staging and production environments separately
- Add database backups
- Implement blue-green or canary deployment strategy

### Deliverable

`Production Deployment v1` – your system running in the cloud, accessible via public URLs.

---

## Week 8 – Observability

**Goal:** Add logging, health checks, and basic monitoring to understand what your system is doing.

### Core exercises

- **Structured logging:**
  - Ensure all services log in a structured format (JSON recommended)
  - Include request IDs or correlation IDs for tracing requests
  - Log important events: errors, API calls, ETL runs

- **Health checks:**
  - Add `/health` endpoints to all services
  - Include checks for:
    - Service is running
    - Database connectivity
    - Redis connectivity (if used)
  - Return appropriate HTTP status codes

- **Basic monitoring:**
  - Set up log aggregation (CloudWatch, Datadog, or similar)
  - Create a simple dashboard showing:
    - Request rates
    - Error rates
    - Response times
  - Set up at least one alert (e.g., error rate threshold)

- **Error tracking:**
  - Integrate error tracking (Sentry, Rollbar, or similar) or use log-based error detection

### Stretch exercises

- Add distributed tracing (OpenTelemetry, Jaeger, etc.)
- Create custom metrics (e.g., ETL processing time, cache hit rate)
- Set up uptime monitoring (Pingdom, UptimeRobot, etc.)
- Build a simple status page
- Add performance profiling for slow endpoints

### Deliverable

`Monitoring v1` – you can answer "What is my system doing?" and "Why did this break?" with logs and metrics.

---

## Week 9 – Backend v2

**Goal:** Enhance your API with caching, pagination, and background tasks.

### Core exercises

- **Caching:**
  - Integrate Redis into your Rust API
  - Cache frequently accessed data (e.g., market lists, popular queries)
  - Implement cache invalidation strategy
  - Add cache hit/miss metrics

- **Pagination:**
  - Add pagination to list endpoints (e.g., `/markets?page=1&limit=20`)
  - Return pagination metadata (total count, page info)
  - Handle edge cases (invalid page numbers, etc.)

- **Background tasks:**
  - Implement at least one background task using Tokio:
    - Periodic data refresh
    - Cache warming
    - Cleanup jobs
  - Ensure tasks are properly managed (can be stopped, don't leak resources)

- **Error handling improvements:**
  - Return appropriate HTTP status codes
  - Provide helpful error messages
  - Log errors with context

### Stretch exercises

- Add rate limiting
- Implement request queuing for heavy operations
- Add WebSocket support for real-time updates
- Create a job queue system (using Redis or a dedicated queue)
- Add API versioning

### Deliverable

`API v2` – a production-ready API with caching, pagination, and background processing.

---

## Week 10 – Frontend v2

**Goal:** Build a polished, feature-rich frontend that feels like a real product.

### Core exercises

- **Core features:**
  - Build your main domain feature (e.g., market explorer, dashboard, etc.)
  - Implement list and detail views
  - Add filtering and search
  - Create forms for creating/editing entities

- **Data fetching:**
  - Use Server Components for initial data loading
  - Implement client-side data fetching for real-time updates
  - Add loading states and error boundaries
  - Handle empty states gracefully

- **UI/UX improvements:**
  - Improve visual design (use a component library or custom styles)
  - Add responsive design (mobile-friendly)
  - Implement proper navigation
  - Add feedback for user actions (toasts, confirmations)

- **Admin tools:**
  - Create an admin section (if applicable)
  - Add basic CRUD operations
  - Include data quality views or system status

### Stretch exercises

- Add data visualization (charts, graphs)
- Implement real-time updates (WebSockets or polling)
- Add keyboard shortcuts
- Create a design system or component library
- Add accessibility features (ARIA labels, keyboard navigation)
- Implement optimistic updates

### Deliverable

`Frontend v2` – a polished web application that demonstrates your domain expertise and good UX.

---

## Week 11 – SwiftUI Client (Optional but Recommended)

**Goal:** Build a native iOS/macOS client that consumes your API.

### Core exercises

- **Setup:**
  - Create a new SwiftUI app (iOS or macOS)
  - Set up API client to communicate with your Rust API
  - Handle authentication if needed (API keys, tokens, etc.)

- **Core UI:**
  - Build a list view showing your main entities (markets, events, etc.)
  - Create a detail view for individual items
  - Implement navigation between views
  - Add pull-to-refresh

- **Data handling:**
  - Fetch data from your API
  - Parse JSON responses
  - Handle loading and error states
  - Cache data locally (UserDefaults or Core Data)

### Stretch exercises

- Add search functionality
- Implement offline support
- Add push notifications (if applicable)
- Create a watchOS or tvOS version
- Add Swift Charts for data visualization
- Implement background refresh

### Deliverable

`Native Client v1` – a working SwiftUI app that demonstrates your API is truly platform-agnostic.

---

## Week 12 – Capstone Integration

**Goal:** Polish, document, and present your complete capstone project.

### Core exercises

- **Integration:**
  - Ensure all services work together end-to-end
  - Test the full data flow: ETL → DB → API → Frontend
  - Fix any integration issues
  - Verify deployment is working

- **Documentation:**
  - Write a comprehensive `README.md` in your capstone directory:
    - What the system does
    - Architecture overview
    - How to run locally
    - How to deploy
    - Environment variables
  - Create at least one architecture diagram (Mermaid, draw.io, or hand-drawn)
  - Document key design decisions

- **Polish:**
  - Fix known bugs
  - Improve error messages
  - Add helpful user feedback
  - Ensure code is reasonably clean and organized

- **Demo preparation:**
  - Prepare a demo script
  - Test the demo flow
  - Create screenshots or a short video (optional)

### Stretch exercises

- Write a blog post about your capstone
- Create a presentation deck
- Add performance optimizations
- Implement additional features you wanted but didn't have time for
- Set up automated testing (unit tests, integration tests)
- Add API documentation (OpenAPI/Swagger)

### Deliverable

`Capstone v1` – a complete, documented, deployable system that you're proud to show off.

---

## Notes

- **Pacing:** These exercises are designed for ~10-15 hours per week. Adjust as needed.
- **Flexibility:** You can swap exercises or focus more on areas that interest you.
- **Domain adaptation:** If you're not building a prediction markets platform, adapt the exercises to your domain (sports, analytics, trading, etc.).
- **Help:** If you're stuck, check the [readings](./02_readings.md), review [architecture guidance](./05_architecture.md), or look at example capstones in `capstones/`.

Remember: The goal is to learn systems thinking and engineering judgment, not to perfectly follow a checklist. Make it your own!