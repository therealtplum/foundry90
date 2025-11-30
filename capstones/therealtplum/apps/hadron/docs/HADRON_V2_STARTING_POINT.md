# Hadron v2: Starting Point & First Steps

## Where to Start

### Step 1: Review Existing Kalshi Code (30 minutes)
**Action**: Check out the `kalshi-integration` branch and review what's already built

```bash
git checkout kalshi-integration
# Review these files:
# - apps/python-etl/etl/kalshi_websocket.py
# - apps/python-etl/etl/kalshi_rsa_signing.py
# - apps/python-etl/etl/kalshi_instruments.py
# - apps/rust-api/src/kalshi.rs (if exists)
```

**What to Look For**:
- How does Kalshi WebSocket authentication work?
- What message formats does Kalshi use?
- What event types are available?
- How are market IDs structured?
- What's the price format?

### Step 2: Understand Hadron Architecture (30 minutes)
**Action**: Review the current Hadron implementation

**Key Files**:
- `apps/hadron/src/ingest/mod.rs` - Polygon ingest (your template)
- `apps/hadron/src/normalize/mod.rs` - Polygon normalizer (your template)
- `apps/hadron/src/schemas.rs` - Data structures (already venue-agnostic!)
- `apps/hadron/src/main.rs` - Pipeline orchestration

**Key Insights**:
- Hadron already has `venue` field in `RawEvent` and `HadronTick` ✅
- Normalizer already routes by `source`/`venue` ✅
- Pipeline is venue-agnostic ✅
- You just need to add Kalshi-specific modules!

### Step 3: Create Kalshi Ingest Module (2-3 hours)
**Action**: Build `apps/hadron/src/ingest/kalshi.rs`

**Pattern to Follow**:
```rust
// Similar structure to Polygon ingest
pub struct KalshiIngestManager {
    tx: mpsc::Sender<RawEvent>,
    api_key: String,  // Or RSA key path
    connection_id: String,
}

impl KalshiIngestManager {
    pub async fn start(&self) -> Result<()> {
        // 1. Connect to Kalshi WebSocket
        // 2. Authenticate (RSA signing)
        // 3. Subscribe to markets
        // 4. Emit RawEvent for each message
    }
}
```

**Key Differences from Polygon**:
- Authentication: RSA signing instead of API key in message
- Message format: May be different (need to research)
- Subscription: Market IDs instead of tickers

### Step 4: Add Kalshi Normalizer (2-3 hours)
**Action**: Add Kalshi normalization to `apps/hadron/src/normalize/mod.rs`

**Pattern**:
```rust
async fn normalize(&mut self, raw_event: &RawEvent) -> Result<Option<HadronTick>> {
    match (raw_event.source.as_str(), raw_event.venue.as_str()) {
        ("polygon", "polygon_ws") => self.normalize_polygon_trade(raw_event).await,
        ("kalshi", "kalshi_ws") => self.normalize_kalshi_event(raw_event).await,  // NEW
        _ => {
            warn!("Unknown source/venue: {}/{}", raw_event.source, raw_event.venue);
            Ok(None)
        }
    }
}
```

**Key Challenges**:
- Map Kalshi market ID → instrument_id
- Normalize probability-based pricing
- Map Kalshi event types to `TickType`

### Step 5: Wire It Up (1 hour)
**Action**: Update `apps/hadron/src/main.rs` to spawn Kalshi ingest

**Pattern**:
```rust
// After Polygon ingest setup...
if let Ok(kalshi_key) = env::var("KALSHI_API_KEY") {
    let kalshi_tx = raw_tx.clone();
    tokio::spawn(async move {
        let kalshi_manager = KalshiIngestManager::new(kalshi_tx, kalshi_key);
        kalshi_manager.start().await.unwrap();
    });
}
```

## How to Think About This

### 1. **Pluggable Architecture** ✅
Hadron is already designed for multiple venues! The `venue` field exists, the normalizer routes by venue, and the pipeline is venue-agnostic. You're not building a new system—you're plugging in a new data source.

### 2. **Follow the Pattern**
Polygon integration is your template:
- **Ingest**: WebSocket connection → authentication → subscription → `RawEvent` emission
- **Normalize**: Parse venue-specific format → map to `HadronTick`
- **Pipeline**: Everything else is automatic!

### 3. **Start Simple, Iterate**
- **MVP**: Just get Kalshi events flowing through the pipeline
- **Then**: Add proper normalization
- **Then**: Add instrument mapping
- **Then**: Cross-venue features

### 4. **Leverage Existing Code**
The `kalshi-integration` branch has Python code for:
- WebSocket connection
- RSA signing
- Market data fetching

You can:
- Use it as reference for Rust implementation
- Understand Kalshi's API structure
- See what data is available

### 5. **Database First**
Before you can normalize, you need:
- Instruments in database
- Mapping from Kalshi market ID → instrument_id

Options:
- Pre-populate via ETL (from `kalshi_instruments.py`)
- Create on-the-fly (slower, but works)
- Hybrid: Pre-populate common markets, create others on-the-fly

## Recommended First Day Plan

### Morning (3-4 hours)
1. **Review** (30 min): Check out `kalshi-integration` branch, read Kalshi API docs
2. **Research** (30 min): Understand Kalshi WebSocket protocol, message formats
3. **Design** (30 min): Sketch out Kalshi ingest module structure
4. **Implement** (2-3 hours): Build basic Kalshi ingest (connect, auth, receive messages)

### Afternoon (3-4 hours)
1. **Test** (1 hour): Verify Kalshi WebSocket connection works, messages received
2. **Normalize** (2 hours): Add Kalshi normalization (basic mapping first)
3. **Wire Up** (1 hour): Add to main.rs, test end-to-end

### End of Day Goal
- Kalshi WebSocket connected ✅
- Messages received ✅
- Basic normalization working ✅
- Ticks flowing through pipeline ✅

## Key Questions to Answer First

1. **Kalshi WebSocket URL?**
   - What's the endpoint?
   - Is it WSS (secure)?

2. **Authentication Flow?**
   - How does RSA signing work?
   - What's the message format?
   - When do you authenticate?

3. **Message Format?**
   - JSON? Binary?
   - Array of events? Single events?
   - What fields are in trade events?

4. **Subscription Model?**
   - How do you subscribe to markets?
   - Can you subscribe to multiple at once?
   - What's the subscription message format?

5. **Event Types?**
   - What events does Kalshi send?
   - Trade events? Order book updates?
   - Market status changes?

## Resources

- **Kalshi Integration Plan**: `apps/hadron/docs/KALSHI_INTEGRATION_PLAN.md`
- **Hadron Status**: `apps/hadron/docs/status_and_roadmap.md`
- **Existing Kalshi Code**: `kalshi-integration` branch
- **Polygon Template**: `apps/hadron/src/ingest/mod.rs`

## Next Steps After First Day

1. **Instrument Mapping**: Create database schema and lookup logic
2. **Price Normalization**: Handle probability-based pricing properly
3. **Multi-Venue Testing**: Run both Polygon and Kalshi simultaneously
4. **Cross-Venue Features**: Price reconciliation, arbitrage detection

