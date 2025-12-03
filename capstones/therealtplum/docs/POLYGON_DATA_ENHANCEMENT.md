# Polygon Data Enhancement

This document describes the enhancements made to fetch more comprehensive market data from Polygon.io for better charting and analysis.

## Overview

Previously, the system only fetched the previous day's price data using Polygon's `/prev` endpoint, which resulted in charts with very few data points (often just 2-3 days). This enhancement adds:

1. **Historical Data Backfill** - Fetches up to 1 year (configurable) of historical daily OHLCV data
2. **Real-time Streaming** - WebSocket connection to Polygon for live market data updates

## Components

### 1. Historical Backfill (`polygon_backfill_historical.py`)

**Purpose:** Backfill historical daily price data for focus universe instruments.

**Features:**
- Uses Polygon's `/v2/aggs/ticker/{ticker}/range/1/day/{start}/{end}` endpoint
- Fetches up to 50,000 bars per request (Polygon's limit)
- Intelligently fills gaps:
  - **Forward fill:** From latest_date to today
  - **Backward fill:** From earliest_date backwards (up to 2 years)
- Prioritizes instruments with the least historical data
- Respects rate limits with configurable sleep between requests

**Usage:**
```bash
# Run backfill for focus instruments
./ops/backfill_historical.sh

# Or directly:
docker compose run --rm etl python -m etl.polygon.polygon_backfill_historical
```

**Configuration (Environment Variables):**
- `BACKFILL_MAX_INSTRUMENTS` - Max instruments to process per run (default: 100)
- `BACKFILL_DAYS` - Number of days to backfill (default: 365)
- `BACKFILL_SLEEP_SECS` - Sleep between API requests (default: 0.1)
- `BACKFILL_BATCH_SIZE` - Batch size for DB inserts (default: 500)

**Data Source:** `polygon_historical`

### 2. Real-time Streaming (`polygon_streaming.py`)

**Purpose:** Stream real-time market data via Polygon WebSocket API.

**Features:**
- Connects to `wss://socket.polygon.io/stocks`
- Subscribes to minute bars (aggregates) for focus universe instruments
- Automatically loads top 50 instruments from focus universe
- Flushes data to database every 60 seconds (configurable)
- Handles authentication and reconnection

**Usage:**
```bash
# Run streaming service (runs continuously)
docker compose run --rm etl python -m etl.polygon.polygon_streaming
```

**Configuration (Environment Variables):**
- `STREAMING_FLUSH_INTERVAL` - Seconds between DB flushes (default: 60)
- `STREAMING_BATCH_SIZE` - Batch size for DB inserts (default: 100)

**Data Source:** `polygon_streaming`

**Note:** Streaming data is aggregated into daily bars. For true intraday data, consider creating a separate `instrument_price_intraday` table.

## API Endpoints Used

### Historical Aggregates
- **Endpoint:** `GET /v2/aggs/ticker/{ticker}/range/1/day/{start}/{end}`
- **Parameters:**
  - `adjusted=true` - Use adjusted prices
  - `sort=asc` - Sort ascending by time
  - `limit=50000` - Maximum bars per request
- **Returns:** Array of OHLCV bars with timestamps

### WebSocket Streaming
- **URL:** `wss://socket.polygon.io/stocks`
- **Authentication:** Send `{"action": "auth", "params": API_KEY}`
- **Subscription:** `{"action": "subscribe", "params": "A.SPY,A.QQQ,..."}` (A = aggregates/bars)
- **Events:** Real-time bar updates with OHLCV data

## Data Flow

1. **Backfill Process:**
   ```
   Focus Universe → Select Instruments → Fetch Historical Bars → Upsert to DB
   ```

2. **Streaming Process:**
   ```
   Focus Universe → Load Tickers → Connect WebSocket → Subscribe → 
   Receive Bars → Aggregate → Flush to DB (every 60s)
   ```

## Database Schema

Both scripts write to the existing `instrument_price_daily` table:
- `instrument_id` - Foreign key to instruments
- `price_date` - Trading date (DATE)
- `open`, `high`, `low`, `close` - OHLC prices
- `adj_close` - Adjusted close price
- `volume` - Trading volume
- `data_source` - `'polygon_historical'` or `'polygon_streaming'`

The table has a unique constraint on `(instrument_id, price_date, data_source)`, allowing multiple sources for the same date.

## Rate Limits & Best Practices

### Polygon API Limits
- **Free Tier:** 5 API calls per minute
- **Starter Tier:** 200 API calls per minute
- **Developer Tier:** 1,000 API calls per minute

### Recommendations
1. **Backfill:** Run during off-hours to avoid rate limits
2. **Streaming:** Use a dedicated service/container that runs continuously
3. **Sleep Intervals:** Adjust `BACKFILL_SLEEP_SECS` based on your API tier
4. **Batch Processing:** Process instruments in smaller batches to avoid timeouts

## Future Enhancements

1. **Intraday Data Table:** Create separate table for minute/hourly bars
2. **Incremental Backfill:** Only fetch missing dates instead of full ranges
3. **Multi-timeframe Support:** Fetch weekly/monthly aggregates for longer-term analysis
4. **Error Recovery:** Better handling of API errors and retries
5. **Data Quality Checks:** Validate data before inserting (e.g., check for negative prices)

## Troubleshooting

### Backfill Issues
- **No data returned:** Check if ticker is valid and has historical data on Polygon
- **Rate limit errors:** Increase `BACKFILL_SLEEP_SECS`
- **Timeout errors:** Polygon may be slow, increase request timeout

### Streaming Issues
- **Connection drops:** WebSocket may disconnect, implement reconnection logic
- **Missing data:** Check if tickers are subscribed correctly
- **Database errors:** Ensure DB connection is stable for long-running process

