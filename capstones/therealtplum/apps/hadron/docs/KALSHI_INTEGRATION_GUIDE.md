# Kalshi Integration: Complete Summary & Best Practices

**Last Updated:** November 29, 2025  
**Status:** Phase 1 Complete, Phase 2 In Progress

## Executive Summary

The Kalshi integration for Hadron v2 is **operational** with WebSocket ingest, normalization, and instrument auto-creation working. Phase 1 of the ticker parser is complete, and Phase 2 (Python ETL) integration testing has begun.

### Current State
- ✅ **Kalshi WebSocket Ingest**: 4 simultaneous connections, RSA-PSS authentication working
- ✅ **Kalshi Normalizer**: Handles ticker, trade, and orderbook events
- ✅ **Instrument Auto-Creation**: New Kalshi markets automatically added to database
- ✅ **Ticker Parser (Phase 1)**: Parses sports, elections, corporate, economic, entertainment tickers
- ✅ **REST API Client**: Python client with RSA-PSS authentication working
- 🔄 **Phase 2 ETL**: In progress - testing with real market data

---

## What We've Learned

### 1. Kalshi Architecture & Data Model

#### Market Structure
```
Series (Template)
  └─ Event (Real-world occurrence)
      └─ Markets (Binary outcomes)
          ├─ Moneyline (Team X wins)
          ├─ Spread (Team X wins by Y points)
          ├─ Totals (Over/Under)
          └─ Parlays (Combinations)
```

**Key Insights:**
- Markets are organized hierarchically: Series → Events → Markets
- Each market is a binary outcome (Yes/No)
- Prices are in cents (0-100) representing probability
- Market tickers encode metadata (league, date, teams, market type)

#### Ticker Format Patterns
- **Sports Games**: `KX{LEAGUE}GAME-{DATE}{TEAM1}{TEAM2}[-{OUTCOME}]`
  - Example: `KXNBAGAME-25NOV29TORCHA` = NBA game, Nov 29, 2025, Toronto at Charlotte
  - Date format: `YYMMMDD` (7 characters, not 8!)
- **Championship Winners**: `KX{LEAGUE}{CONFERENCE}-{YEAR}-{TEAM}`
  - Example: `KXNCAAFB12-25-KU` = NCAA Football Big 12 Championship, 2025, Kansas
- **Elections**: `KX{YEAR}{PARTY}RUN-{YEAR}-{CANDIDATE}`
- **Corporate**: `{COMPANY}{EVENT}-{DATE}`
- **Economic**: `FED-{DATE}-T{VALUE}`

### 2. Authentication & API Access

#### RSA-PSS Signing
- **Method**: RSA-PSS with SHA-256
- **Message Format**: `{timestamp}{method}{path}`
  - Example: `1234567890GET/markets`
- **Headers Required**:
  - `KALSHI-ACCESS-KEY`: API key ID
  - `KALSHI-ACCESS-SIGNATURE`: Base64-encoded signature
  - `KALSHI-ACCESS-TIMESTAMP`: Milliseconds since epoch

#### Best Practices
1. **Private Key Storage**: Store in `.kalshi_keys/` directory (gitignored)
2. **Key Rotation**: Support multiple API keys (currently 4, can scale to 10)
3. **Error Handling**: Implement retry logic with exponential backoff
4. **Rate Limiting**: Respect Kalshi's rate limits (documented in API docs)

### 3. WebSocket vs REST API

#### WebSocket (Real-Time)
- **Use For**: Live ticker updates, orderbook changes, trade events
- **Connection**: One per API key (Kalshi limitation)
- **Subscription**: Can subscribe to all markets or specific ones
- **Message Types**: `ticker`, `trades`, `orderbook_delta`, `orderbook_snapshot`

#### REST API (Batch/Historical)
- **Use For**: Market metadata, historical data, bulk operations
- **Endpoints**:
  - `/markets` - List/filter markets
  - `/events` - Event information
  - `/search/filters_by_sport` - Sports metadata
  - `/search/tags_by_categories` - Series categories

#### Best Practice
- **Hybrid Approach**: Use WebSocket for real-time data, REST for metadata enrichment
- **ETL Pattern**: Daily REST API calls to fetch/update market metadata
- **Real-Time Pattern**: WebSocket for live price updates

### 4. Ticker Parsing Challenges

#### Date Parsing Bug (Fixed)
- **Issue**: Date was parsed as 8-9 characters instead of 7
- **Root Cause**: Assumed `YYMMMDD` was 8 chars (it's 7: 2+3+2)
- **Fix**: Changed from `remaining[:8]` to `remaining[:7]`
- **Impact**: Team codes were split incorrectly (e.g., `TORCHA` → `RC/HA` instead of `TOR/CHA`)

#### Team Code Matching
- **Challenge**: Team codes vary in length (2-4 characters)
- **Solution**: Sort codes by length (longest first) to prevent partial matches
- **Strategy**: Two-pass matching (startswith, then endswith)

#### Pattern Coverage
- **Working**: NBA, NHL, A-League, Elections, Corporate, Economic, Entertainment
- **Needs Work**: NCAA formats, Championship winners, Multivariate events

### 5. Price Normalization

#### Kalshi Price Format
- **Input**: Cents (0-100) representing probability
- **Output**: Decimal (0.0-1.0) for HadronTick
- **Conversion**: `price_decimal = price_cents / 100.0`

#### Price Extraction Priority
1. `price` field (last traded price)
2. Mid-price: `(yes_bid + yes_ask) / 2`
3. Fallback: `(bid + ask) / 2`

### 6. Instrument Auto-Creation

#### Current Implementation
- **Trigger**: When normalizer encounters unknown market ticker
- **Action**: Creates instrument with:
  - `ticker`: Kalshi market ticker
  - `asset_class`: `'other'` (prediction markets)
  - `primary_source`: `'kalshi'`
  - `name`: `"Kalshi Market: {ticker}"` (temporary, will be enriched by ETL)

#### Future Enhancement
- ETL will update `display_name` and `external_ref` with parsed metadata
- Fast-path (Hadron) creates minimal instrument
- Slow-path (ETL) enriches with human-readable names

---

## Best Practices

### 1. Code Organization

#### Rust (Hadron)
```
apps/hadron/src/
├── ingest/
│   ├── mod.rs          # Orchestrates Polygon + Kalshi
│   ├── polygon.rs      # Polygon WebSocket ingest
│   └── kalshi.rs       # Kalshi WebSocket ingest
├── normalize/
│   ├── mod.rs          # Routes by source/venue
│   ├── polygon.rs      # Polygon normalization
│   └── kalshi.rs       # Kalshi normalization
└── schemas.rs          # Shared data structures
```

#### Python (ETL)
```
apps/python-etl/etl/
├── kalshi_ticker_parser.py      # Phase 1: Ticker parsing
├── kalshi_ticker_parser_test.py # Unit tests
└── kalshi_test_ncaa_ku.py      # Phase 2: API integration test
```

### 2. Error Handling

#### WebSocket Reconnection
- Implement exponential backoff (1s, 2s, 4s, 8s, max 60s)
- Log reconnection attempts for debugging
- Gracefully handle authentication failures

#### API Request Failures
- Retry on 5xx errors (up to 3 attempts)
- Don't retry on 4xx errors (client errors)
- Respect rate limits (429 responses)

### 3. Security

#### Private Key Management
- ✅ Store in `.kalshi_keys/` (gitignored)
- ✅ Mount as read-only volume in Docker
- ✅ Never commit keys to git
- ✅ Use environment variables for paths

#### API Key Rotation
- Support multiple keys for redundancy
- Rotate keys periodically
- Monitor key usage/limits

### 4. Testing

#### Unit Tests
- Test ticker parser with known patterns
- Test edge cases (malformed tickers, missing fields)
- Test price normalization edge cases

#### Integration Tests
- Test REST API authentication
- Test WebSocket connection and subscription
- Test end-to-end data flow (WebSocket → Normalizer → Database)

### 5. Performance

#### WebSocket Connections
- One connection per API key (Kalshi limitation)
- Currently using 4 keys = 4 connections
- Can scale to 10 keys if needed

#### Database Queries
- Cache instrument lookups (market ticker → instrument_id)
- Batch inserts for bulk operations
- Use connection pooling

#### ETL Optimization
- Paginate through markets (1000 per page)
- Filter server-side when possible (use `series_ticker`, `status`, etc.)
- Process in batches to avoid memory issues

---

## What's Still To-Do

### Phase 2: Python ETL (In Progress)

#### Immediate Tasks
1. **Enhance Ticker Parser**
   - [ ] Add NCAA championship winner patterns
   - [ ] Add multivariate event patterns
   - [ ] Expand team abbreviations dictionary
   - [ ] Handle scalar markets (non-binary)

2. **REST API Integration**
   - [ ] Use `/search/filters_by_sport` to find NCAA basketball series
   - [ ] Filter markets by `series_ticker` for targeted fetching
   - [ ] Fetch market metadata (`title`, `subtitle`, `yes_sub_title`, `no_sub_title`)
   - [ ] Cross-reference API data with parsed ticker data

3. **Database Schema**
   - [ ] Add `display_name` column to `instruments` table (if not exists)
   - [ ] Update `external_ref` JSONB with parsed metadata
   - [ ] Create indexes for search performance

4. **ETL Pipeline**
   - [ ] Daily job to fetch all open markets
   - [ ] Parse tickers and generate display names
   - [ ] Upsert instruments with enriched data
   - [ ] Handle updates (market status changes, new markets)

### Phase 3: Production Hardening

1. **Monitoring & Observability**
   - [ ] Add metrics for WebSocket connection health
   - [ ] Track normalization success/failure rates
   - [ ] Monitor API rate limit usage
   - [ ] Alert on authentication failures

2. **Error Recovery**
   - [ ] Implement dead letter queue for failed normalizations
   - [ ] Add retry logic for transient failures
   - [ ] Handle partial data gracefully

3. **Performance Optimization**
   - [ ] Optimize database queries (indexes, query plans)
   - [ ] Implement connection pooling
   - [ ] Cache frequently accessed data

4. **Documentation**
   - [ ] API endpoint documentation
   - [ ] Deployment guide
   - [ ] Troubleshooting guide
   - [ ] Runbook for common issues

### Phase 4: Advanced Features

1. **Cross-Venue Normalization**
   - [ ] Map Kalshi markets to traditional instruments (if applicable)
   - [ ] Price reconciliation across venues
   - [ ] Arbitrage detection

2. **Market Relationship Tracking**
   - [ ] Track all markets for same event
   - [ ] Group related markets (moneyline, spread, totals)
   - [ ] Build market dependency graph

3. **Human-Readable Display**
   - [ ] Generate display names for all market types
   - [ ] Support for multivariate events
   - [ ] Rich metadata in UI (teams, dates, market types)

---

## Known Issues & Limitations

### Current Limitations

1. **Team Abbreviations**
   - Limited to common teams (NBA, NHL, A-League, some NCAA)
   - Need to expand using Kalshi API data
   - Some team codes may be ambiguous

2. **Ticker Pattern Coverage**
   - Championship winner tickers not yet parsed
   - Multivariate events not yet handled
   - Some edge cases may not be covered

3. **Market Type Detection**
   - Currently uses heuristics
   - Should use API metadata for accuracy
   - Some markets may be misclassified

4. **Display Names**
   - Currently generic: `"Kalshi Market: {ticker}"`
   - Will be enriched by ETL in Phase 2
   - Fast-path (Hadron) creates minimal instruments

### Known Bugs

1. **None Currently** - All identified bugs have been fixed

### Performance Considerations

1. **WebSocket Connections**
   - Limited to 1 connection per API key per asset class
   - Currently using 4 keys = 4 connections
   - May need more keys for higher throughput

2. **Database Writes**
   - Auto-creation happens on hot path (may be slow)
   - Consider batching or async writes
   - Monitor database performance

3. **ETL Processing**
   - Processing millions of markets may be slow
   - Consider parallel processing
   - Use database transactions for consistency

---

## Testing Results

### Phase 1: Ticker Parser
```
✅ KXNBAGAME-25NOV29TORCHA → Toronto at Charlotte, Nov 29, 2025
✅ KXALEAGUEGAME-25DEC05AUCWPH-AUC → Auckland vs Wellington Phoenix
✅ KX2028DRUN-28-AOC → 2028 Democratic primary, Alexandria Ocasio-Cortez
✅ APPLEFOLD-25DEC31 → Apple stock split, Dec 31, 2025
✅ FED-25DEC-T3.75 → Federal Reserve rate, Dec 2025, Target 3.75%
```

### Phase 2: REST API Integration
```
✅ RSA-PSS authentication working
✅ Successfully fetched 5,000+ markets
✅ Found 8 markets involving KU/Kansas
⚠️  Found championship winners, not game moneylines (filtering needs refinement)
⚠️  Parser doesn't handle championship winner tickers yet
```

### WebSocket Integration
```
✅ 4 simultaneous connections established
✅ Authentication successful
✅ Subscriptions confirmed
✅ Ticker messages received
✅ Normalization working
✅ Instruments auto-created
```

---

## File Structure

### Current Documentation
- `KALSHI_INTEGRATION_GUIDE.md` - **This document** (comprehensive overview)
- `KALSHI_WEBSOCKET_PROTOCOL.md` - Protocol reference (authentication, message formats)
- `KALSHI_NORMALIZATION_DESIGN.md` - Original design proposal (reference)
- `status/KALSHI_INTEGRATION_COMPLETE.md` - Integration completion summary
- `status/KALSHI_PARSER_PHASE1_COMPLETE.md` - Phase 1 parser completion
- `status/HADRON_STATUS.md` - Overall Hadron status and roadmap
- `POLYGON_API_LIMITATIONS.md` - Polygon API plan details

### Code Files
- `apps/hadron/src/ingest/kalshi.rs` - WebSocket ingest
- `apps/hadron/src/normalize/kalshi.rs` - Normalization logic
- `apps/python-etl/etl/kalshi_ticker_parser.py` - Ticker parser
- `apps/python-etl/etl/kalshi_test_ncaa_ku.py` - REST API test script

---

## References

### Kalshi API Documentation
- [API Reference](https://docs.kalshi.com/api-reference/)
- [WebSocket Quick Start](https://docs.kalshi.com/getting_started/quick_start_websockets)
- [Get Filters for Sports](https://docs.kalshi.com/api-reference/search/get-filters-for-sports)
- [Get Tags for Series Categories](https://docs.kalshi.com/api-reference/search/get-tags-for-series-categories)
- [Get Markets](https://docs.kalshi.com/api-reference/market/get-markets)
- [Get Events](https://docs.kalshi.com/api-reference/events/get-events)

### Internal Documentation
- `apps/hadron/docs/KALSHI_WEBSOCKET_PROTOCOL.md` - Protocol details
- `apps/hadron/docs/status/HADRON_STATUS.md` - Overall roadmap

---

## Quick Start Guide

### For Developers

1. **Set up environment variables** (`.env`):
   ```bash
   KALSHI_API_KEY_1=your_key_here
   KALSHI_PRIVATE_KEY_1_PATH=.kalshi_keys/hadron_1.pem
   # ... repeat for keys 2-10
   ```

2. **Start Hadron service**:
   ```bash
   docker compose up hadron
   ```

3. **Verify connections**:
   - Check logs for "Kalshi connection established"
   - Verify subscription confirmations
   - Monitor for ticker messages

4. **Test ticker parser**:
   ```bash
   python apps/python-etl/etl/kalshi_ticker_parser.py
   ```

5. **Test REST API**:
   ```bash
   python apps/python-etl/etl/kalshi_test_ncaa_ku.py
   ```

### For Operations

1. **Monitor WebSocket connections**: Check Hadron logs
2. **Monitor database**: Check `instruments` table for new Kalshi markets
3. **Monitor API usage**: Track rate limit headers in responses
4. **Troubleshoot**: See `KALSHI_WEBSOCKET_PROTOCOL.md` for common issues

---

## Conclusion

The Kalshi integration is **production-ready** for real-time data ingestion and normalization. Phase 1 of the ticker parser is complete, and Phase 2 (Python ETL) is in progress. The system is designed to scale to millions of instruments with a hybrid fast-path/slow-path approach.

**Next Priority**: Complete Phase 2 ETL to enrich instruments with human-readable display names and comprehensive metadata.

