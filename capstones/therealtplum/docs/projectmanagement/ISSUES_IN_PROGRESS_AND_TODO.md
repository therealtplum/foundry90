# In-Progress and To-Do Issues
**Date:** November 30, 2025  
**Status:** Active Planning Document

This document tracks issues that are currently in progress or prioritized for implementation, organized by epic and respecting parent/child relationships.

---

## 🔴 In Progress

*None currently identified as actively in progress - all issues appear to be in planning/backlog stage*

---

## 🟡 High Priority To-Do

### API Hardening Epic (#92)

All issues in this epic are high priority for production readiness:

1. **#118 - Add structured logging**
   - **Parent:** #92 (API Hardening)
   - **Status:** To-Do
   - **Why:** Critical for production debugging and observability
   - **Dependencies:** None
   - **Estimated Effort:** Medium (2-3 days)

2. **#119 - Add typed errors**
   - **Parent:** #92 (API Hardening)
   - **Status:** To-Do
   - **Why:** Better error handling and API responses
   - **Dependencies:** None
   - **Estimated Effort:** Medium (2-3 days)

3. **#120 - Add request ID middleware**
   - **Parent:** #92 (API Hardening)
   - **Status:** To-Do
   - **Why:** Essential for request tracing in production
   - **Dependencies:** None (can be done in parallel)
   - **Estimated Effort:** Small (1 day)

4. **#124 - Typed config struct**
   - **Parent:** #92 (API Hardening)
   - **Status:** To-Do
   - **Why:** Foundation for other improvements, better config management
   - **Dependencies:** None (should be done first)
   - **Estimated Effort:** Small (1 day)
   - **Recommendation:** Do this first as it's foundational

5. **#121 - Split routes by domain**
   - **Parent:** #92 (API Hardening)
   - **Status:** To-Do
   - **Why:** Code organization and maintainability
   - **Dependencies:** None
   - **Estimated Effort:** Medium (2-3 days)

6. **#123 - Add rate limiting**
   - **Parent:** #92 (API Hardening)
   - **Status:** To-Do
   - **Why:** Protect API from abuse
   - **Dependencies:** None
   - **Estimated Effort:** Medium (2-3 days)

7. **#122 - Add integration tests**
   - **Parent:** #92 (API Hardening)
   - **Status:** To-Do
   - **Why:** Ensure API reliability as we make changes
   - **Dependencies:** #124 (typed config) would help
   - **Estimated Effort:** Large (5+ days)
   - **Recommendation:** Do after other hardening items

**Suggested Implementation Order:**
1. #124 (Typed config) - Foundation
2. #118 (Structured logging) - Needed for debugging
3. #120 (Request ID) - Works with logging
4. #119 (Typed errors) - Improves error handling
5. #121 (Split routes) - Code organization
6. #123 (Rate limiting) - Security/protection
7. #122 (Integration tests) - Validation

---

## 🟢 Medium Priority To-Do

### Universe Epic (#91)

1. **#117 - Update API filters**
   - **Parent:** #91 (Universe)
   - **Status:** To-Do
   - **Current State:** `/instruments` endpoint exists but limited filtering
   - **Why:** Support filtering by asset_class, region, etc. for expanded universe
   - **Dependencies:** None
   - **Estimated Effort:** Small (1-2 days)

2. **#116 - Update frontend filters**
   - **Parent:** #91 (Universe)
   - **Status:** To-Do
   - **Why:** Support filtering in UI as universe expands
   - **Dependencies:** #117 (API filters should be done first)
   - **Estimated Effort:** Medium (2-3 days)

3. **#114 - Add macro event table**
   - **Parent:** #91 (Universe)
   - **Status:** To-Do
   - **Why:** Track macro events (FOMC, earnings, etc.) for trading context
   - **Dependencies:** Schema changes
   - **Estimated Effort:** Medium (3-4 days including ETL)
   - **Note:** Verify if existing tables (`macro_indicators`, `macro_data_points`) suffice

4. **#115 - Add prediction markets module**
   - **Parent:** #91 (Universe)
   - **Status:** To-Do (Partially done - Kalshi exists)
   - **Current State:** Kalshi WebSocket ingest in Hadron, Kalshi API endpoints exist
   - **Why:** Formalize prediction markets support in ETL/API
   - **Dependencies:** None
   - **Estimated Effort:** Medium (3-4 days)
   - **Note:** Clarify what "module" means - may already be mostly done

5. **#113 - Add crypto proxies**
   - **Parent:** #91 (Universe)
   - **Status:** To-Do
   - **Why:** Expand crypto coverage
   - **Dependencies:** None
   - **Estimated Effort:** Medium (2-3 days)
   - **Note:** Clarify what "proxies" means

6. **#112 - Add ETFs to universe**
   - **Parent:** #91 (Universe)
   - **Status:** To-Do (Partially done)
   - **Current State:** ETFs can be ingested, schema supports them
   - **Why:** Ensure ETFs are explicitly in ETL pipeline
   - **Dependencies:** None
   - **Estimated Effort:** Small (1 day)

**Suggested Implementation Order:**
1. #117 (API filters) - Foundation
2. #116 (Frontend filters) - Builds on API
3. #115 (Prediction markets module) - Formalize existing work
4. #112 (ETFs) - Quick win
5. #114 (Macro events) - More complex
6. #113 (Crypto proxies) - Clarify scope first

---

## 🔵 Lower Priority / Needs Review

### Frontend Epic (#88)

- **#93-99, #126** - Various UI polish items
- **Status:** Some implemented (#126 has arrows), others need review
- **Action:** Review each individually to determine current relevance

### ETL Orchestration Epic (#89)

- **#100-105** - ETL improvements (scheduler, logging, history)
- **Status:** Needs review based on current ETL state
- **Action:** Review each issue individually

### Insight v2 Epic (#90)

- **#106-111** - Insight improvements
- **Status:** Current insight system exists, improvements needed
- **Action:** Review current implementation and prioritize

### Schema Epic (#83)

- **#37-43** - Schema improvements
- **Status:** Needs review against current schema
- **Action:** Audit current `schema.sql` and determine gaps

### News Epic (#85)

- **#30-36** - News improvements
- **Status:** News system exists, may need improvements
- **Action:** Review current `/instruments/{id}/news` endpoint

### Redis Epic (#86)

- **#23-28** - Redis improvements
- **Status:** Redis pool exists, caching minimal
- **Action:** Review each issue for relevance

### Market Data Epic (#87)

- **#14-22** - Market data improvements
- **Status:** Basic market data exists
- **Action:** Review against current implementation

### FMHub Epic (#84)

- **#44-45, #78-82** - iOS app improvements
- **Status:** Client-side features
- **Action:** Review based on iOS app roadmap

---

## Issue Relationships Summary

### Epic Hierarchy

```
#92 - API Hardening
  ├── #118 - Structured logging
  ├── #119 - Typed errors
  ├── #120 - Request ID middleware
  ├── #121 - Split routes
  ├── #122 - Integration tests
  ├── #123 - Rate limiting
  └── #124 - Typed config

#91 - Universe
  ├── #112 - Add ETFs
  ├── #113 - Add crypto proxies
  ├── #114 - Add macro event table
  ├── #115 - Add prediction markets module
  ├── #116 - Update frontend filters
  └── #117 - Update API filters

#90 - Insight v2
  ├── #106 - Aggregate news bundles
  ├── #107 - Create improved prompt
  ├── #108 - Add TLDR variant
  ├── #109 - Cache + persist insights
  ├── #110 - Add insights v2 endpoint
  └── #111 - Template versioning

#89 - ETL Orchestration
  ├── #100 - Add internal scheduler
  ├── #101 - Unified ETL entrypoint
  ├── #102 - Write to etl_runs
  ├── #103 - Add /system/etl_runs endpoint
  ├── #104 - Add ETL history to FMHub
  └── #105 - Improve ETL logging

#88 - Frontend
  ├── #93 - Standardize pill spacing
  ├── #94 - Increase scroll speed
  ├── #95 - Fix hover pause jitter
  ├── #96 - Improve popover typography
  ├── #97 - Add arrows + animations (see #126)
  ├── #98 - Highlight active ticker
  ├── #99 - Add fade transitions
  └── #126 - Restore price change arrows (IMPLEMENTED - CLOSE)

#87 - Market Data
  ├── #14 - Add daily_bars and latest_quotes tables
  ├── #15 - Add SQL indexes
  ├── #16 - Implement polygon_daily_bars ETL
  ├── #17 - Implement polygon_latest_quotes ETL
  ├── #18 - Add Rust query layer
  ├── #19 - Create /markets/tickers endpoint
  ├── #20 - Update health endpoint
  ├── #21 - Frontend ticker update
  └── #22 - Add arrow + color logic

#86 - Redis
  ├── #23 - Add connection pool (DONE)
  ├── #24 - Add PING to system health
  ├── #25 - Implement get_or_set_json helper
  ├── #26 - Cache insights
  ├── #27 - Cache markets/tickers
  ├── #28 - Add cache hit/miss logging
  └── #29 - Add docker healthcheck

#85 - News
  ├── #30 - Ensure ETL stores full fields
  ├── #31 - Add index for news lookup
  ├── #32 - Implement /instruments/{id}/news endpoint (DONE)
  ├── #33 - Frontend news list in popover
  ├── #34 - Improve insight generation
  ├── #35 - Add prompt template v1.5
  └── #36 - Cache news results

#84 - FMHub
  ├── #44 - Add /ops/run_etl endpoint
  ├── #45 - Add ETL trigger runners
  ├── #78 - Show service statuses
  ├── #79 - Show ETL timestamps
  ├── #80 - Add Run ETL buttons
  ├── #81 - Add success/failure alerts
  └── #82 - Add refresh button

#83 - Schema
  ├── #37 - Add missing indexes
  ├── #38 - Add etl_runs table
  ├── #39 - Add foreign keys
  ├── #40 - Add system metadata table
  ├── #41 - Cleanup migration order
  ├── #42 - Add constraints + not nulls
  └── #43 - Document schema
```

---

## Next Actions

1. **Close Issue #126** - Price change arrows are implemented
2. **Prioritize API Hardening Epic** - Start with #124 (typed config)
3. **Review older issues** (#14-45) - Determine if still relevant or already done
4. **Clarify scope** on #115 (prediction markets module) and #113 (crypto proxies)
5. **Create sprint plan** based on high-priority items

---

## Notes

- All parent/child relationships preserved for kanban board
- Epic labels drive board organization
- Estimates are rough and should be refined during planning
- Dependencies noted but may be flexible depending on approach

