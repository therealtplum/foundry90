# Financial/Macro Data Hub – Project Scope

## 1. Objective

Build a **Financial/Macro Data Hub** that:

- Ingests a curated set of **market** and **macroeconomic** data from external providers  
- Normalizes and stores this data in **Postgres**  
- Exposes it via a typed **Rust + Axum API**, with **Redis** caching for hot paths  
- Visualizes and interacts with it via:
  - a **web app** (Next.js)
  - with the backend designed so it can be reused by a **desktop macOS app** and **iOS app** later  
- Adds a scoped but real **LLM “analyst” integration** that explains charts and trends using the system’s own data

This is a **full-stack, multi-service capstone** meant to demonstrate architectural reasoning, service integration, and production-like engineering.

---

## 2. Users & Use Cases

### Primary user

A **macro/markets analyst** (e.g., at a small fund, treasury team, or family office) who wants:

- A single place to inspect key instruments (indices, ETFs, a few equities, BTC/ETH)  
- A small, opinionated set of macro indicators (CPI, unemployment, rates, GDP)  
- Basic visualizations (price and indicator charts, trends)  
- Human-readable explanations of what’s going on

### Primary use cases

- “Show me SPX, QQQ, BTC, 10Y yield, CPI and unemployment in one overview dashboard.”
- “Drill into a specific instrument or macro series and see its recent behavior.”
- “Get a quick English summary of what this chart is doing (trend, recent move).”

---

## 3. Data Scope & External Sources

The capstone deliberately keeps the data universe **small but coherent**.

### 3.1 Instruments & Market Data

**Provider:** Polygon (existing access)  
**Universe (initial):**

- Indices: `SPX`, `NDX`, `RUT`
- ETFs: `SPY`, `QQQ`
- Equities: e.g., `AAPL`, `MSFT`, `NVDA`, `TSLA` (exact list can be tuned)
- (Optional stretch) Crypto: `BTC`, `ETH` via Polygon or CoinGecko

**Data types (MVP):**

- **Daily OHLCV** bars for each instrument, for a fixed historical window (e.g., last 5–10 years where available)
- (Optional stretch) Recent intraday bars for the last 1–5 days

### 3.2 Macro Data

**Provider:** FRED (public API)

**Macro indicator set (MVP):**

- CPI (headline)
- CPI (core) – optional
- Unemployment rate
- Effective federal funds rate
- Real GDP (quarterly)
- (Optional stretch) 2Y and 10Y Treasury yields

**Data types:**

- Full available history per series
- Frequency normalized as stored (monthly, quarterly, etc.), but queryable by range.

---

## 4. System Components

### 4.1 Data & Storage

**Postgres** as system of record for:

- `instruments`
- `prices` (daily)
- `macro_indicators`
- `macro_data_points`

**Redis** for:

- Caching responses for hot endpoints (e.g., dashboard aggregates, commonly requested series).

No user accounts or write APIs in v1; all writes go through ETL.

---

### 4.2 ETL – Python

**Responsibilities:**

- **Instrument loading:**
  - Define and upsert a small curated universe of instruments.
- **Price ingestion:**
  - Fetch daily OHLCV from Polygon for the configured instrument universe and load into `prices`.
- **Macro ingestion:**
  - Fetch configured FRED series and load into `macro_indicators` / `macro_data_points`.
- **Idempotency:**
  - Re-running ETL should not create duplicates (use upserts keyed by natural keys like `(instrument_id, date)` or `(indicator_id, timestamp)`).

**Execution model (MVP):**

- ETL runs as a **Dockerized one-shot job**, e.g.:
  - `docker compose run etl python -m etl.jobs.full_refresh`
- In a production-like setting, this would map directly to **ECS scheduled tasks**.

---

### 4.3 API – Rust + Axum

**Responsibilities:**

- Provide a **read-only HTTP API** over the normalized data.
- Enforce types and invariants.
- Implement caching for key endpoints via Redis.

**MVP endpoints:**

- `GET /health`
  - Basic service + DB connectivity check.
- `GET /instruments`
  - List + simple filtering (e.g., `asset_class=equity|index|etf|crypto`).
- `GET /instruments/{id}`
  - Detailed metadata for a single instrument.
- `GET /prices/{instrument_id}?range=1m|3m|1y|max`
  - Time series for charts (daily resolution).
- `GET /macro/indicators`
  - List of macro indicators with metadata.
- `GET /macro/series/{id}?range=1y|5y|max`
  - Macro time series data.
- `GET /dashboard/overview`
  - Composite endpoint that returns:
    - a small bundle of preselected instruments and macro series with recent values and deltas
    - **this is a good candidate for Redis caching**

**Design constraints:**

- Clean module layout (`routes`, `db`, `models`, `cache`, `config`).
- Configured via environment variables (DB URL, Redis URL, LLM API key, etc.).
- Stateless; suitable as a single backend for web, macOS, and iOS clients.

---

### 4.4 Frontends – Web, macOS, iOS

**Primary capstone implementation:**  
- **Web frontend** using **Next.js** in `apps/web`.

**Design goal for other clients:**  
- The Rust API should be designed so it can be reused directly by:
  - a future **macOS desktop app** (e.g., SwiftUI/macOS client calling the same HTTP API)
  - a future **iOS app** (SwiftUI/UIKit client using the same endpoints)

MVP scope focuses on the **web** client, but the API and data contracts should be:

- well-documented
- stable enough that building macOS/iOS clients later is straightforward.

#### Web UI (MVP):

1. **Dashboard (`/`)**
   - Cards for key instruments (SPX, QQQ, BTC, etc.) and macro indicators (CPI, unemployment, Fed funds).
   - Each card shows:
     - Latest value
     - Change over a configured lookback (e.g., 1m).
   - One or two small charts or sparklines.

2. **Instruments browser (`/instruments`)**
   - Table with ticker, name, asset class, region.
   - Search/filter and click-through to detail.

3. **Instrument detail (`/instruments/[id]`)**
   - Price chart with range selector.
   - Basic return stats (e.g., 1m/3m/1y).
   - Related macro context listed in a sidebar.

4. **Macro explorer (`/macro` and `/macro/[id]`)**
   - List of macro indicators.
   - Detail page for each series with a chart and metadata.

---

## 5. LLM Integration

The LLM integration should be **narrow, data-aware, and clearly scoped**.

### 5.1 MVP LLM Feature – “Explain This Chart”

**User experience:**

- On an instrument or macro detail page, the user can click:
  - **“Explain this chart”**
- The frontend calls a backend LLM endpoint:
  - e.g., `POST /llm/explain` with payload `{ type: "instrument" | "macro", id, range }`.

**Backend behavior:**

1. The Rust API:
   - Fetches the relevant time series from Postgres for the specified `id` and `range`.
   - Computes a handful of simple features:
     - trend (up/down/flat over range)
     - % change over range
     - max drawdown or notable moves
     - volatility-ish metric (e.g., std dev of returns)
   - Builds a prompt for the LLM:
     - includes a compact, structured summary of the data and stats
     - sets clear instructions: non-hype, concise, factual.

2. The API calls an LLM provider (e.g., OpenAI) **only if**:
   - An LLM API key is configured via env var.
   - Otherwise it returns a helpful error or a stubbed explanation.

3. The LLM returns a short natural-language explanation which is passed back to the frontend and rendered under the chart.

**Non-goals for MVP:**

- No free-form natural-language querying across the whole dataset.
- No multi-turn conversational agent.
- No portfolio simulation or recommendation logic.

---

## 6. Non-Goals (v1)

To keep the capstone scoped and finishable:

- No user authentication or role-based access in v1.
- No write APIs (no user annotations, alerts, or saved views).
- No real-time streaming (no websockets, Kafka, or tick-level feeds).
- No advanced quant analytics or forecasting (beyond simple derived stats).
- No native macOS or iOS clients implemented in v1
  - but APIs should be designed so these could be added later using the same backend.

These can be addressed in later iterations but are intentionally **out of scope** for the initial capstone.

---

## 7. “Done” Definition for the Capstone

The capstone is considered **complete** when:

1. **ETL:**  
   - A Dockerized Python ETL job can be run to populate/refresh Postgres with:
     - daily OHLCV for the selected Polygon instruments
     - historical data for the selected FRED macro series

2. **Database & API:**  
   - Postgres schema exists for instruments, prices, macro indicators, and macro data points.  
   - Rust API provides all MVP endpoints and can serve them from real data.  
   - Redis is used to cache at least one composite or high-traffic endpoint (e.g., dashboard overview).

3. **Web Frontend:**  
   - Next.js app can:
     - Show a dashboard overview
     - Browse instruments and macro indicators
     - Show detail pages with charts backed by real API calls

4. **LLM Integration:**  
   - “Explain this chart” works for at least:
     - one instrument detail page
     - one macro indicator detail page  
   - The explanation is generated by an LLM using stats derived from the actual stored data.

5. **Documentation:**  
   - `README.md`, `architecture.md`, and this `scope.md` are up to date.  
   - Basic runbook for:
     - local setup
     - running ETL
     - bringing up the API and web app via Docker.