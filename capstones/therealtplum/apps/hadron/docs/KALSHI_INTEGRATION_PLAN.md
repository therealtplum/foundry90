# Kalshi Integration Plan for Hadron v2

## Overview

This document outlines the strategy for integrating Kalshi into Hadron's real-time intelligence system. Kalshi is a prediction market exchange, which means it has different data structures and concepts than traditional equity markets (Polygon).

## Strategic Approach

### Phase 1: Understand Kalshi Data Model (Day 1)
**Goal**: Map Kalshi's data structures to Hadron's unified `HadronTick` format

**Key Differences**:
- **Polygon**: Trades, quotes, bars (equity market data)
- **Kalshi**: Markets, orders, trades (prediction market data)
- **Polygon**: Ticker symbols (AAPL, MSFT)
- **Kalshi**: Market IDs (e.g., "INX-2024-12-31-UP")
- **Polygon**: Price = dollar amount
- **Kalshi**: Price = probability (0-100) or contract price (cents)

**Tasks**:
1. Review existing Kalshi integration code in `kalshi-integration` branch
2. Document Kalshi WebSocket message formats
3. Map Kalshi market types to Hadron instrument types
4. Design normalization strategy for probability-based pricing

### Phase 2: Create Kalshi Ingest Module (Day 2-3)
**Goal**: Build a Kalshi-specific ingest module following Polygon's pattern

**Architecture Pattern** (from Polygon):
```
IngestManager (Polygon)
  ├─ WebSocket connection
  ├─ Authentication flow
  ├─ Subscription management
  └─ RawEvent emission
```

**Kalshi Ingest Requirements**:
- WebSocket connection to Kalshi API
- RSA signature authentication (different from Polygon!)
- Market subscription management
- Event type handling (trade, order, market update)
- Error handling and reconnection

**Files to Create**:
- `apps/hadron/src/ingest/kalshi.rs` - Kalshi-specific ingest module
- Update `apps/hadron/src/ingest/mod.rs` - Add Kalshi manager
- Update `apps/hadron/src/main.rs` - Spawn Kalshi ingest task

**Key Challenges**:
1. **Authentication**: Kalshi uses RSA signing, not simple API keys
   - Need to handle key loading from environment
   - Sign requests with RSA private key
   - Different auth flow than Polygon
2. **WebSocket Protocol**: May differ from Polygon
   - Need to understand Kalshi's message format
   - Handle different event types
   - Manage subscriptions differently

### Phase 3: Create Kalshi Normalizer (Day 3-4)
**Goal**: Normalize Kalshi events to `HadronTick` format

**Normalization Challenges**:

1. **Market ID → Instrument ID Mapping**
   - Kalshi uses market IDs like "INX-2024-12-31-UP"
   - Need to map to Hadron's `instrument_id` (UUID from database)
   - May need to create instruments on-the-fly for new markets
   - Or maintain a mapping table

2. **Price Normalization**
   - Kalshi prices are probabilities (0-100) or contract prices (cents)
   - Polygon prices are dollar amounts
   - Need to normalize to a common format
   - Options:
     - Store raw Kalshi price + metadata
     - Convert probability to "price" (0-100 scale)
     - Store both raw and normalized

3. **Event Type Mapping**
   - Kalshi: `trade`, `order`, `market_update`
   - Polygon: `T` (trade), `Q` (quote), `A` (aggregate)
   - Map to Hadron's `TickType` enum

4. **Volume/Size Handling**
   - Kalshi: Contract volume (number of contracts)
   - Polygon: Share volume
   - Need consistent representation

**Files to Create**:
- `apps/hadron/src/normalize/kalshi.rs` - Kalshi normalizer
- Update `apps/hadron/src/normalize/mod.rs` - Add Kalshi normalization logic

**Normalization Strategy**:
```rust
// Pseudo-code
fn normalize_kalshi_event(raw: RawEvent) -> Result<HadronTick> {
    // 1. Parse Kalshi event structure
    let kalshi_event = parse_kalshi_message(&raw.raw_payload)?;
    
    // 2. Map market ID to instrument_id
    let instrument_id = lookup_or_create_instrument(&kalshi_event.market_id)?;
    
    // 3. Normalize price (probability to price)
    let price = normalize_kalshi_price(kalshi_event.price, kalshi_event.market_type)?;
    
    // 4. Map event type
    let tick_type = map_kalshi_event_type(kalshi_event.event_type)?;
    
    // 5. Create HadronTick
    Ok(HadronTick {
        instrument_id,
        venue: "kalshi".to_string(),
        tick_type,
        price,
        size: kalshi_event.volume,
        timestamp: kalshi_event.timestamp,
        // ... metadata
    })
}
```

### Phase 4: Instrument Mapping & Database (Day 4-5)
**Goal**: Create unified instrument mapping between Polygon and Kalshi

**Database Schema Additions**:
```sql
-- Add venue column to instruments table (if not exists)
ALTER TABLE instruments ADD COLUMN IF NOT EXISTS venue VARCHAR(50);

-- Create mapping table for cross-venue instruments
CREATE TABLE IF NOT EXISTS instrument_venue_mapping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    venue VARCHAR(50) NOT NULL,
    venue_instrument_id VARCHAR(255) NOT NULL, -- Kalshi market ID, Polygon ticker, etc.
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(venue, venue_instrument_id)
);

-- Index for lookups
CREATE INDEX idx_instrument_venue_mapping_lookup 
    ON instrument_venue_mapping(venue, venue_instrument_id);
```

**Mapping Strategy**:
1. **Same Instrument, Different Venues**
   - Example: S&P 500 index
   - Polygon: Ticker "SPY" or index symbol
   - Kalshi: Market "INX-2024-12-31-UP" (prediction market)
   - Map both to same `instrument_id`

2. **Kalshi-Only Instruments**
   - Prediction markets that don't exist in Polygon
   - Create new instruments in database
   - Store Kalshi market ID in mapping table

3. **Polygon-Only Instruments**
   - Equity stocks that don't have prediction markets
   - No mapping needed (Kalshi won't have them)

**Implementation**:
- Add `lookup_instrument_by_venue_id()` function
- Add `create_instrument_from_kalshi_market()` function
- Cache mappings in memory (similar to symbol cache)

### Phase 5: Multi-Venue Pipeline (Day 5-6)
**Goal**: Run both Polygon and Kalshi ingest simultaneously

**Architecture**:
```
┌─────────────────┐
│ Polygon Ingest  │──┐
└─────────────────┘  │
                      ├──> RawEvent Channel ──> Normalizer ──> HadronTick
┌─────────────────┐  │
│ Kalshi Ingest   │──┘
└─────────────────┘
```

**Implementation**:
1. Spawn both ingest managers in `main.rs`
2. Both write to same `RawEvent` channel
3. Normalizer routes based on `venue` field
4. All ticks flow through same pipeline

**Testing**:
- Verify both venues produce ticks
- Check venue identification is correct
- Ensure no conflicts or race conditions

### Phase 6: Cross-Venue Normalization (Day 6-7)
**Goal**: Handle same instrument from multiple venues

**Use Cases**:
1. **Price Reconciliation**
   - Same instrument (e.g., S&P 500) from Polygon and Kalshi
   - Polygon: Current index value ($4,500)
   - Kalshi: Probability market (will S&P close above $4,500?)
   - Need to correlate these

2. **Arbitrage Detection**
   - If same instrument has different prices on different venues
   - Detect and log opportunities
   - (Future: Auto-trade on arbitrage)

3. **Venue Priority**
   - Which venue is "source of truth"?
   - For equity data: Polygon
   - For prediction markets: Kalshi
   - Handle conflicts appropriately

## Implementation Order

### Week 1: Foundation
1. **Day 1**: Review Kalshi integration code, understand data model
2. **Day 2**: Create Kalshi ingest module (WebSocket, auth, basic connection)
3. **Day 3**: Implement Kalshi normalizer (map to HadronTick)
4. **Day 4**: Database schema for venue mapping
5. **Day 5**: Instrument lookup/creation logic

### Week 2: Integration
6. **Day 6**: Multi-venue pipeline (both Polygon and Kalshi running)
7. **Day 7**: Cross-venue normalization and testing

## Key Design Decisions

### 1. Venue Identification
**Decision**: Add `venue` field to `HadronTick` (already exists in `RawEvent`)

**Rationale**:
- Already in schema
- Easy to filter by venue
- Enables venue-specific strategies

### 2. Price Normalization
**Decision**: Store raw Kalshi price + normalized price

**Rationale**:
- Preserves original data
- Allows different normalization strategies
- Enables analysis of raw vs normalized

### 3. Instrument Mapping
**Decision**: Use database mapping table + in-memory cache

**Rationale**:
- Persistent across restarts
- Fast lookups (cached)
- Can be updated via ETL or admin interface

### 4. Authentication
**Decision**: Load RSA keys from environment variables

**Rationale**:
- Secure (not in code)
- Flexible (can rotate keys)
- Consistent with Polygon approach

## Success Criteria

### Phase 1 (Ingest)
- [ ] Kalshi WebSocket connects successfully
- [ ] Authentication works (RSA signing)
- [ ] Can subscribe to markets
- [ ] Receives trade/order events
- [ ] Events are emitted as `RawEvent`

### Phase 2 (Normalize)
- [ ] Kalshi events normalize to `HadronTick`
- [ ] Market IDs map to instrument_ids
- [ ] Prices are normalized correctly
- [ ] Event types map correctly
- [ ] Venue is set to "kalshi"

### Phase 3 (Pipeline)
- [ ] Both Polygon and Kalshi ingest run simultaneously
- [ ] Ticks from both venues flow through same pipeline
- [ ] No conflicts or race conditions
- [ ] Database persists ticks from both venues

### Phase 4 (Cross-Venue)
- [ ] Same instrument can be tracked from multiple venues
- [ ] Price reconciliation works
- [ ] Arbitrage detection (logging)
- [ ] Venue priority is respected

## Testing Strategy

### Unit Tests
- Kalshi message parsing
- Price normalization functions
- Instrument mapping logic
- Event type mapping

### Integration Tests
- End-to-end: Kalshi WebSocket → HadronTick
- Multi-venue: Both Polygon and Kalshi running
- Database: Instrument creation and mapping

### Manual Testing
- Connect to Kalshi WebSocket
- Subscribe to real markets
- Verify ticks appear in database
- Check venue identification

## Risks & Mitigations

### Risk 1: Kalshi API Changes
**Mitigation**: Version pinning, comprehensive error handling

### Risk 2: Authentication Complexity
**Mitigation**: Start with simple auth, iterate

### Risk 3: Price Normalization Ambiguity
**Mitigation**: Store both raw and normalized, analyze later

### Risk 4: Performance with Multiple Venues
**Mitigation**: Monitor channel depths, add metrics

## Next Steps After v2

1. **Real Order Routing**: Send orders to Kalshi (Phase 4.3)
2. **Multi-Sharding**: Distribute load across shards
3. **Advanced Strategies**: Venue-specific strategies
4. **Arbitrage Trading**: Auto-trade on cross-venue opportunities

## Resources

- Kalshi API Documentation: (to be researched)
- Existing Kalshi code: `kalshi-integration` branch
- Hadron Architecture: `apps/hadron/docs/status_and_roadmap.md`
- Polygon Integration: `apps/hadron/src/ingest/mod.rs`

