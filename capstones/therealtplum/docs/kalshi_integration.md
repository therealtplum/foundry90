# Kalshi Integration

This document describes the comprehensive Kalshi integration for the foundry90 capstone project.

## Overview

Kalshi is a regulated prediction market exchange where users can trade on the outcome of events. This integration provides:

1. **Instrument Ingestion** - Fetch and store Kalshi markets as instruments
2. **Real-time Market Data** - WebSocket streaming for live market updates
3. **User Account Integration** - Secure credential storage and account data access
4. **Scalable Architecture** - Designed to handle millions of instruments
5. **Human-Readable Display** - Ticker normalization and friendly display names
6. **Parlay Support** - Handling of multi-variant events

## Architecture

### Components

- **ETL Modules** (`apps/python-etl/etl/`):
  - `kalshi_instruments.py` - Fetches and stores Kalshi markets
  - `kalshi_market_data.py` - Fetches historical/current market data
  - `kalshi_websocket.py` - WebSocket service for real-time streaming
  - `kalshi_user_account.py` - User credentials and account data
  - `kalshi_ticker_utils.py` - Ticker normalization and display utilities

- **API Endpoints** (`apps/rust-api/src/kalshi.rs`):
  - `GET /kalshi/markets` - List markets with filtering/pagination
  - `GET /kalshi/markets/{ticker}` - Get specific market details
  - `GET /kalshi/users/{user_id}/account` - Get user account data
  - `GET /kalshi/users/{user_id}/balance` - Get user balance
  - `GET /kalshi/users/{user_id}/positions` - Get user positions

- **Database Schema** (`services/db/schema_kalshi.sql`):
  - `kalshi_user_credentials` - Encrypted credential storage
  - `kalshi_market_subscriptions` - User market subscriptions
  - `kalshi_parlays` - Parlay (multi-variant) event tracking
  - `kalshi_market_cache` - Real-time market data cache
  - Views and functions for filtering/pagination

## Data Model

### Instruments

Kalshi markets are stored in the `instruments` table:
- `ticker`: Kalshi market ticker (e.g., "PRES-2024-11-05-BIDEN")
- `name`: Market title/question (from API)
- `asset_class`: Currently `'other'` (prediction markets)
- `primary_source`: `'kalshi'`
- `external_ref`: JSONB containing:
  - `kalshi_ticker`: Original ticker
  - `series_ticker`: Series identifier
  - `event_ticker`: Event identifier
  - `market_status`: Market status
  - `subtitle`: Additional context
  - `event_type`: Event category (for filtering)

### Market Data

Real-time market data is cached in `kalshi_market_cache`:
- `market_ticker`: Market identifier
- `market_data`: Full JSONB market data
- `yes_price`: Current "yes" price (0-100, probability)
- `no_price`: Current "no" price (0-100, probability)
- `volume`: Trading volume
- `last_updated`: Timestamp of last update
- `expires_at`: Cache expiration (1 hour TTL)

Historical data is stored in `instrument_price_daily`:
- `close`: Yes price (probability 0-100)
- `volume`: Trading volume
- `data_source`: `'kalshi'`

### User Credentials

Encrypted credentials stored in `kalshi_user_credentials`:
- `user_id`: Unique user identifier
- `encrypted_credentials`: Fernet-encrypted API key/secret
- `api_key_id`: Reference to API key (not secret)
- `is_active`: Whether credentials are active

## WebSocket Streaming

The WebSocket service (`kalshi_websocket.py`) provides:

- **Real-time Updates**: Subscribes to market updates via WebSocket
- **Redis Caching**: Stores updates in Redis for fast access
- **Automatic Reconnection**: Handles connection failures with exponential backoff
- **Subscription Management**: Track which markets are subscribed

### Usage

```python
from etl.kalshi_websocket import KalshiWebSocketClient

client = KalshiWebSocketClient()
await client.start(tickers=["PRES-2024-11-05-BIDEN"])
```

The service runs as a background process and updates Redis cache.

## User Account Integration

### Storing Credentials

```python
from etl.kalshi_user_account import store_user_credentials

store_user_credentials(
    user_id="user123",
    api_key="kalshi_api_key",
    api_secret="kalshi_private_key",
    encryption_key=os.getenv("KALSHI_CREDENTIALS_ENCRYPTION_KEY"),
)
```

### Fetching Account Data

```python
from etl.kalshi_user_account import fetch_user_account_data

account_data = fetch_user_account_data("user123")
# Returns: {balance, positions, account, fetched_at}
```

### Authentication

Kalshi uses RSA-PSS signing for authenticated requests. The `KalshiAuthenticatedClient` class handles:
- Request signing with private key
- Header generation (`KALSHI-ACCESS-KEY`, `KALSHI-ACCESS-SIGNATURE`, `KALSHI-ACCESS-TIMESTAMP`)
- API calls for balance, positions, account info

**Note**: Full RSA-PSS implementation is a TODO - currently placeholder.

## Ticker Normalization

Kalshi tickers are often cryptic (e.g., "PRES-2024-11-05-BIDEN"). The `kalshi_ticker_utils` module provides:

### Display Name Formatting

```python
from etl.kalshi_ticker_utils import format_ticker_display_name

display_name = format_ticker_display_name(
    "PRES-2024-11-05-BIDEN",
    market_data={"title": "Will Biden win the 2024 election?"}
)
# Returns: "Will Biden win the 2024 election?"
```

### Ticker Parsing

```python
from etl.kalshi_ticker_utils import parse_kalshi_ticker

parsed = parse_kalshi_ticker("PRES-2024-11-05-BIDEN")
# Returns: {
#     "event_type": "PRES",
#     "year": "2024",
#     "month": "11",
#     "day": "05",
#     "outcome": "BIDEN"
# }
```

### Categorization

```python
from etl.kalshi_ticker_utils import categorize_ticker

category = categorize_ticker("PRES-2024-11-05-BIDEN")
# Returns: "Politics"
```

## Parlays (Multi-Variant Events)

Parlays in Kalshi are combinations of multiple events. The system handles them via:

1. **Database Table**: `kalshi_parlays` stores parlay definitions
2. **Detection**: `is_parlay()` function identifies parlays
3. **Display**: `format_parlay_display()` creates readable descriptions

Example:
```python
from etl.kalshi_ticker_utils import format_parlay_display

parlay = {
    "markets": ["PRES-2024-BIDEN", "SENATE-2024-DEM"],
    "outcomes": ["YES", "YES"]
}
display = format_parlay_display(parlay)
# Returns: "Biden Election 2024: YES + Senate 2024: YES"
```

## Scalability

### Filtering and Pagination

The API supports filtering and pagination:

```bash
# List markets with filters
GET /kalshi/markets?category=Politics&status=active&limit=50&offset=0&search=Biden

# Database function for efficient queries
SELECT * FROM get_kalshi_markets_filtered(
    p_category := 'Politics',
    p_status := 'active',
    p_limit := 50,
    p_offset := 0,
    p_search := 'Biden'
);
```

### Caching Strategy

- **Redis**: Real-time WebSocket updates (1 hour TTL)
- **Database Cache**: `kalshi_market_cache` table for persistence
- **API Cache**: Redis caching for hot endpoints

### Indexing

Database indexes for performance:
- `instruments` table: `primary_source`, `status`, `ticker`
- `kalshi_market_cache`: `market_ticker`, `expires_at`
- `kalshi_user_credentials`: `user_id`, `is_active`
- GIN index on `component_markets` JSONB for parlay queries

## Configuration

### Environment Variables

```bash
# Kalshi API
KALSHI_BASE_URL=https://api.elections.kalshi.com/trade-api/v2
KALSHI_WS_URL=wss://api.elections.kalshi.com/trade-api/ws/v2
KALSHI_WS_DEMO_URL=wss://demo-api.kalshi.co/trade-api/ws/v2
KALSHI_USE_DEMO=false

# Credentials encryption
KALSHI_CREDENTIALS_ENCRYPTION_KEY=your_encryption_key_here

# Rate limiting
KALSHI_MAX_INSTRUMENTS=500
KALSHI_SLEEP_SECS=0.1
KALSHI_BATCH_SIZE=100

# Redis
REDIS_URL=redis://localhost:6379
```

## Usage

### Running ETL Jobs

```bash
# Fetch instruments
docker compose run --rm etl python -m etl.kalshi_instruments

# Fetch market data
docker compose run --rm etl python -m etl.kalshi_market_data

# Start WebSocket service (runs continuously)
docker compose run --rm etl python -m etl.kalshi_websocket
```

### API Endpoints

```bash
# List markets
curl http://localhost:3000/kalshi/markets?limit=10

# Get market details
curl http://localhost:3000/kalshi/markets/PRES-2024-11-05-BIDEN

# Get user account (requires authentication)
curl http://localhost:3000/kalshi/users/user123/account
```

## Database Setup

Apply the Kalshi schema extensions:

```bash
cd capstones/therealtplum
docker exec -i fmhub_db psql -U app -d fmhub < services/db/schema_kalshi.sql
```

## Security Considerations

1. **Credential Encryption**: All user credentials are encrypted at rest using Fernet
2. **API Key Storage**: Only encrypted credentials stored; API key ID for reference
3. **Authentication**: RSA-PSS signing required for authenticated endpoints
4. **Access Control**: User credentials are isolated by `user_id`

## Future Enhancements

1. **Full RSA-PSS Implementation**: Complete authentication signing
2. **Historical Price Tracking**: Store price history for charts
3. **Order Book Data**: Store order book depth if needed
4. **WebSocket Authentication**: Support authenticated WebSocket connections
5. **Trading Integration**: Place orders (future phase)
6. **Alert System**: Notify users of market updates
7. **Parlay Builder UI**: Visual interface for creating parlays

## Notes

- Kalshi markets are binary (yes/no) prediction markets
- Prices represent probabilities (0-100) rather than dollar amounts
- The system is designed to scale to millions of instruments
- WebSocket service should run as a separate service/container
- User credentials require proper key management in production
