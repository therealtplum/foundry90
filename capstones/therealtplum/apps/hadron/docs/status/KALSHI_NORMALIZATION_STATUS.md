# Kalshi Instrument Normalization - Implementation Status

**Last Updated:** December 2025  
**Status:** Phase 1 Complete ✅, Phase 2 In Progress 🔄

---

## Overview

This document tracks the implementation status of the Kalshi Instrument Normalization feature. The original design proposal was documented in the historical reference `KALSHI_NORMALIZATION_DESIGN.md` (moved to status/archive/).

**Problem Statement:**
Kalshi has millions of instruments with cryptic ticker names. We need to normalize these into human-readable display names with structured metadata.

**Solution Architecture:**
Two-path approach with fast-path (Hadron real-time) and slow-path (Python ETL batch processing).

---

## Implementation Status by Phase

### ✅ Phase 1: Ticker Parser - COMPLETE

**Original Proposal:** Research Kalshi ticker patterns and implement parser for common patterns.

**Status:** ✅ **COMPLETE**

**Implementation:**
- ✅ **Research completed** - Analyzed Kalshi ticker patterns across multiple categories
- ✅ **Parser implemented** - `apps/python-etl/etl/kalshi_ticker_parser.py`
- ✅ **Unit tests** - `apps/python-etl/etl/kalshi_ticker_parser_test.py`
- ✅ **Edge cases handled** - Date parsing bug fixed, team code matching improved

**Capabilities:**
- ✅ Sports games (NBA, NHL, A-League, etc.)
- ✅ Elections (primaries, governors, chamber control)
- ✅ Corporate events (stock splits, FTC cases)
- ✅ Economic indicators (Fed rates)
- ✅ Entertainment (songs, genres)

**Known Limitations:**
- ⚠️ Championship winner tickers not yet parsed
- ⚠️ Team abbreviations dictionary is limited (will expand in Phase 2)
- ⚠️ Some edge cases may not be covered

**Documentation:**
- See `status/KALSHI_PARSER_PHASE1_COMPLETE.md` for detailed Phase 1 report

---

### 🔄 Phase 2: Python ETL - IN PROGRESS

**Original Proposal:** Implement Kalshi REST API client, integrate ticker parser, implement name generator, database upsert logic.

**Status:** 🔄 **IN PROGRESS**

**Completed:**
- ✅ **REST API Client** - Python client with RSA-PSS authentication working
- ✅ **Authentication** - RSA-PSS signing implemented and tested
- ✅ **Market Fetching** - Successfully fetched 5,000+ markets
- ✅ **Parser Integration** - Ticker parser integrated (Phase 1)

**In Progress:**
- 🔄 **Bulk Normalization Pipeline** - Testing with real market data
- 🔄 **Display Name Enrichment** - Generating human-readable names from parsed metadata
- 🔄 **Database Upsert** - Updating instruments table with normalized data

**Pending:**
- [ ] Name generator implementation (full version)
- [ ] Batch processing optimization
- [ ] Rate limiting for large-scale fetching
- [ ] ETL schedule integration

**Next Steps:**
- Complete display name generation logic
- Implement database upsert with parsed metadata
- Add to ETL schedule for daily runs

---

### ⏳ Phase 3: Database Schema - PENDING

**Original Proposal:** Add `display_name` column, create indexes, migration script.

**Status:** ⏳ **PENDING**

**Pending:**
- [ ] Add `display_name` column to `instruments` table (if not exists)
- [ ] Create indexes for search performance
- [ ] Migration script

**Notes:**
- Schema changes will be needed once Phase 2 name generation is complete
- Can use existing `external_ref` JSONB field in interim

---

### ✅ Phase 4: Hadron Fast-Path - COMPLETE

**Original Proposal:** Update instrument creation to set `needs_enrichment` flag, ensure ETL picks up flagged instruments.

**Status:** ✅ **COMPLETE**

**Implementation:**
- ✅ **Fast-path auto-creation** - Hadron creates minimal instruments when new Kalshi markets are seen
- ✅ **Instrument creation** - `src/normalize/kalshi.rs` creates instruments with placeholder names
- ✅ **External ref structure** - Stores `kalshi_ticker` and metadata in `external_ref` JSONB field

**Current Behavior:**
- When Hadron sees a new Kalshi market, it creates an instrument with:
  - `ticker`: Kalshi market ticker
  - `name`: `"Kalshi Market: {ticker}"` (temporary)
  - `asset_class`: `'other'`
  - `primary_source`: `'kalshi'`
  - `external_ref`: Contains ticker and metadata

**Future Enhancement:**
- Phase 2 ETL will enrich these instruments with human-readable display names

---

### ⏳ Phase 5: API & UI Updates - PENDING

**Original Proposal:** Update Rust API, macOS app, and web frontend to use `display_name`.

**Status:** ⏳ **PENDING**

**Pending:**
- [ ] Update Rust API to return `display_name` in responses
- [ ] Update macOS app to use `display_name`
- [ ] Update web frontend to use `display_name`

**Notes:**
- Waiting on Phase 2 completion (display names in database)
- Phase 3 schema changes may be needed first

---

## Current Implementation Details

### Fast-Path (Hadron - Real-Time)

**Location:** `apps/hadron/src/normalize/kalshi.rs`

**Behavior:**
- Auto-creates instruments for new Kalshi markets seen in WebSocket stream
- Creates minimal instrument record immediately
- Stores ticker in `external_ref` JSONB field
- Uses placeholder name: `"Kalshi Market: {ticker}"`

**Code Example:**
```rust
// Instrument creation in fast-path
// See apps/hadron/src/normalize/kalshi.rs for implementation
```

### Slow-Path (Python ETL - Batch)

**Location:** `apps/python-etl/etl/`

**Components:**
- `kalshi_ticker_parser.py` - Ticker parser (Phase 1 complete)
- `kalshi_test_ncaa_ku.py` - REST API test script
- (Future) `kalshi_instruments.py` - Full ETL pipeline

**Current Status:**
- Parser is complete and tested
- REST API client is working
- Bulk normalization pipeline in progress

---

## Files Reference

### Implementation Files
- `apps/python-etl/etl/kalshi_ticker_parser.py` - Ticker parser implementation
- `apps/python-etl/etl/kalshi_ticker_parser_test.py` - Unit tests
- `apps/python-etl/etl/kalshi_test_ncaa_ku.py` - REST API integration test
- `apps/hadron/src/normalize/kalshi.rs` - Fast-path instrument creation

### Documentation Files
- `status/KALSHI_PARSER_PHASE1_COMPLETE.md` - Phase 1 completion report
- `KALSHI_INTEGRATION_GUIDE.md` - Comprehensive Kalshi integration guide
- `status/archive/KALSHI_NORMALIZATION_DESIGN.md` - Original design proposal (archived)

---

## Roadmap

### Immediate (Next 1-2 weeks)
- [ ] Complete Phase 2 bulk normalization pipeline
- [ ] Implement display name generation
- [ ] Test with full market dataset

### Short Term (Next 1 month)
- [ ] Complete Phase 3 database schema updates
- [ ] Integrate into ETL schedule
- [ ] Begin Phase 5 API/UI updates

### Long Term (Future)
- [ ] Expand ticker pattern coverage
- [ ] Build comprehensive team abbreviation dictionary
- [ ] Market relationship tracking
- [ ] Performance optimization for millions of instruments

---

## Related Documents

- **Kalshi Integration Guide**: `KALSHI_INTEGRATION_GUIDE.md` - Comprehensive current state and best practices
- **Phase 1 Report**: `status/KALSHI_PARSER_PHASE1_COMPLETE.md` - Detailed Phase 1 completion report
- **Hadron Status**: `status/HADRON_STATUS.md` - Overall Hadron system status

---

**Last Updated:** December 2025  
**Next Review:** After Phase 2 completion

