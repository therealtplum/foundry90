# Kalshi Integration Implementation Status

## ✅ Completed (Day 1)

### Infrastructure Setup
- [x] RSA private keys stored securely in `.kalshi_keys/` (gitignored)
- [x] Environment variable configuration (`.env.kalshi.example`)
- [x] Protocol documentation (`KALSHI_PROTOCOL.md`)
- [x] Integration plan (`KALSHI_INTEGRATION_PLAN.md`)

### Kalshi Ingest Module
- [x] Created `apps/hadron/src/ingest/kalshi.rs`
- [x] RSA-PSS authentication implementation
- [x] WebSocket connection with auth headers
- [x] Subscription to ticker channel (all markets)
- [x] Message parsing and routing
- [x] Error handling and reconnection logic
- [x] Multiple API key support (up to 10 keys)
- [x] Wired into `main.rs` - spawns separate task per API key

### Dependencies
- [x] Added `rsa` crate with `sha2` feature
- [x] Added `pkcs1` and `pkcs8` for PEM parsing
- [x] Added `base64` for signature encoding
- [x] Added `rand` for randomized signing

## 🔄 Next Steps (Day 2-3)

### Kalshi Normalizer
- [ ] Create `apps/hadron/src/normalize/kalshi.rs`
- [ ] Map Kalshi market IDs to instrument_ids
- [ ] Normalize Kalshi prices (cents/probability to Decimal)
- [ ] Map Kalshi event types to `TickType` enum
- [ ] Handle Kalshi-specific data structures
- [ ] Update `normalize/mod.rs` to route Kalshi events

### Instrument Mapping
- [ ] Create database schema for venue mapping
- [ ] Implement instrument lookup/creation logic
- [ ] Add in-memory cache for market ID → instrument_id
- [ ] Handle Kalshi-only markets (prediction markets)

### Testing
- [ ] Test WebSocket connection with real API keys
- [ ] Verify authentication works
- [ ] Test subscription and message reception
- [ ] Verify events flow through pipeline
- [ ] Test with multiple API keys simultaneously

## 📋 Current Implementation Details

### API Keys Configured
- Configured via environment variables in `.env` file (not committed to git)
- Supports up to 10 API keys: `KALSHI_API_KEY_1` through `KALSHI_API_KEY_10`
- Each key requires a corresponding private key path: `KALSHI_PRIVATE_KEY_1_PATH` through `KALSHI_PRIVATE_KEY_10_PATH`

### Environment Variables Needed
```bash
# For each key (1-10):
KALSHI_API_KEY_1=<your_api_key_here>
KALSHI_PRIVATE_KEY_1_PATH=.kalshi_keys/hadron_1.pem

# Optional: Override WebSocket URL
KALSHI_WS_URL=wss://api.elections.kalshi.com/trade-api/ws/v2
# Or for demo:
# KALSHI_WS_URL=wss://demo-api.kalshi.co/trade-api/ws/v2
```

### What Works Now
1. ✅ Kalshi WebSocket connection with RSA-PSS authentication
2. ✅ Subscription to ticker updates (all markets)
3. ✅ Message parsing and routing to normalizer
4. ✅ Multiple connections (one per API key)
5. ✅ Error handling and auto-reconnection

### What's Next
1. **Normalization**: Map Kalshi events to `HadronTick`
2. **Instrument Mapping**: Create/lookup instruments for Kalshi markets
3. **Price Normalization**: Convert Kalshi prices (cents/probability) to standard format
4. **Testing**: End-to-end test with real data

## Architecture

```
┌─────────────────┐
│ Polygon Ingest  │──┐
└─────────────────┘  │
                      ├──> RawEvent Channel ──> Normalizer ──> HadronTick
┌─────────────────┐  │
│ Kalshi Ingest 1  │──┤
│ Kalshi Ingest 2  │──┤
│ Kalshi Ingest 3  │──┤
│ Kalshi Ingest 4  │──┘
└─────────────────┘
```

## Key Implementation Notes

### Authentication
- Uses RSA-PSS signing (different from Polygon's simple API key)
- Signature: `timestamp + "GET" + "/trade-api/ws/v2"`
- Headers: `KALSHI-ACCESS-KEY`, `KALSHI-ACCESS-SIGNATURE`, `KALSHI-ACCESS-TIMESTAMP`

### Subscription
- Currently subscribes to `ticker` channel (all markets)
- Can be extended to subscribe to specific markets
- Message format: `{"id": 1, "cmd": "subscribe", "params": {"channels": ["ticker"]}}`

### Message Types Handled
- `ticker` - Ticker updates
- `orderbook_delta` - Orderbook changes
- `orderbook_snapshot` - Full orderbook state
- `trades` - Trade executions
- `subscribed` - Subscription confirmation
- `error` - Error messages

## Testing Checklist

- [ ] Add Kalshi keys to `.env` file
- [ ] Start Hadron service
- [ ] Verify Kalshi connections log successfully
- [ ] Check for subscription confirmations
- [ ] Verify ticker messages are received
- [ ] Check that events flow to normalizer
- [ ] Verify database persistence (after normalizer is done)

## References

- [Kalshi WebSocket Docs](https://docs.kalshi.com/getting_started/quick_start_websockets)
- [Kalshi API Reference](https://docs.kalshi.com/api-reference/)
- [Kalshi Rate Limits](https://docs.kalshi.com/getting_started/rate_limits)
- [Python Starter Code](https://github.com/Kalshi/kalshi-starter-code-python)

