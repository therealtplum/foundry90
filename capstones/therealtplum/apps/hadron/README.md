# Hadron Real-Time Intelligence System

Hadron is the real-time data processing and decision engine for Foundry90. It ingests market data, normalizes it, routes it through priority queues, runs strategies, and produces order intents.

## Architecture

Hadron follows a pipeline architecture:

```
Ingest → Normalize → Router → Engine → Coordinator → Gateway → Recorder
```

### Components

- **Ingest**: Connects to external data sources (Polygon WebSocket, Kalshi WebSocket)
- **Normalize**: Converts raw events to canonical `HadronTick` format
- **Router**: Classifies ticks by priority (FAST/WARM/COLD) and assigns to shards
- **Engine**: Maintains instrument state and runs strategies
- **Coordinator**: Merges strategy decisions into order intents
- **Gateway**: Routes orders to venues (simulation mode in Phase 1)
- **Recorder**: Persists ticks and executions to Postgres

## Phase 1 Status

✅ **Core Pipeline MVP** - Complete

- Single-shard engine
- Polygon WebSocket ingest (15-minute delayed)
- Kalshi WebSocket ingest (real-time, 4 connections)
- Kalshi normalization and instrument auto-creation
- Simple SMA strategy
- Simulation-only order gateway
- Health endpoint
- Database persistence

## Configuration

Environment variables:

- `POLYGON_API_KEY`: Required for Polygon WebSocket connection
- `HADRON_API_KEY_1` through `HADRON_API_KEY_4`: Additional Polygon API keys (optional)
- `KALSHI_API_KEY_1` through `KALSHI_API_KEY_10`: Kalshi API keys (optional)
- `KALSHI_PRIVATE_KEY_1_PATH` through `KALSHI_PRIVATE_KEY_10_PATH`: Kalshi private key paths
- `DATABASE_URL`: Postgres connection string (default: `postgres://app:app@localhost:5433/fmhub`)
- `HADRON_SIMULATION_MODE`: Enable simulation mode (default: `true`)
- `HADRON_NUM_SHARDS`: Number of shards (default: `1`)
- `HADRON_WEBSOCKET_MODE`: Polygon WebSocket mode - `delayed` (default) or `realtime`
- `PORT`: Health endpoint port (default: `3002`)
- `RUST_LOG`: Logging level (default: `info`)

## Database Schema

Hadron uses the following tables (see `services/db/schema_hadron.sql`):

- `hadron_ticks`: Real-time normalized tick data
- `hadron_order_intents`: Order intents from strategies
- `hadron_order_executions`: Order execution confirmations
- `hadron_strategy_decisions`: Strategy decisions (for audit)

## Running

### Local Development

```bash
cd apps/hadron
cargo run
```

### Docker

```bash
docker compose up hadron
```

## Health Endpoint

```bash
curl http://localhost:3002/system/health
```

Returns:
```json
{
  "status": "ok",
  "db_ok": true,
  "service": "hadron"
}
```

## Documentation

See `docs/README.md` for comprehensive documentation index.

**Key Documents:**
- `docs/status/HADRON_STATUS.md` - Overall system status and roadmap
- `docs/KALSHI_INTEGRATION_GUIDE.md` - Kalshi integration guide
- `docs/status/KALSHI_NORMALIZATION_STATUS.md` - Normalization implementation status

## Next Steps (Phase 2+)

- [ ] Multi-strategy framework with registry
- [ ] Dynamic priority routing based on positions/volatility
- [ ] Multi-shard support
- [ ] Real venue order routing (Kalshi order execution)
- [ ] Kalshi normalization Phase 2 (ETL bulk processing)
- [ ] Metrics and observability dashboard
- [ ] Replay mode for backtesting

