"""
ETL job to backfill historical daily OHLCV data from Polygon API.

Uses the /v2/aggs/ticker/{ticker}/range endpoint to fetch historical aggregates.
This can backfill up to 2 years of daily data per API call (Polygon limit).
"""

import os
import json
import logging
import time
from datetime import datetime, timedelta, timezone

import requests
import psycopg2
from psycopg2.extras import execute_batch

POLYGON_API_KEY = os.getenv("POLYGON_API_KEY")
if not POLYGON_API_KEY:
    raise RuntimeError("POLYGON_API_KEY environment variable is required for polygon_backfill_historical ETL")

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

logging.basicConfig(
    level=logging.INFO,
    format="[polygon_backfill_historical] %(message)s",
)
log = logging.getLogger(__name__)

# How many instruments to process in one run
MAX_INSTRUMENTS = int(os.getenv("BACKFILL_MAX_INSTRUMENTS", "100"))

# Number of days to backfill (default: 365 days = 1 year)
BACKFILL_DAYS = int(os.getenv("BACKFILL_DAYS", "365"))

# Small sleep between requests to be nice to Polygon
REQUEST_SLEEP_SECS = float(os.getenv("BACKFILL_SLEEP_SECS", "0.1"))

# Flush to DB every N price rows
BATCH_SIZE = int(os.getenv("BACKFILL_BATCH_SIZE", "500"))

DATA_SOURCE = "polygon_historical"


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def get_instruments_to_backfill(cur, limit: int):
    """
    Get instruments from focus universe that need historical backfill.
    Prioritizes instruments with the least historical data.
    """
    cur.execute("""
        WITH latest_focus AS (
            SELECT as_of_date
            FROM instrument_focus_universe
            GROUP BY as_of_date
            HAVING COUNT(*) >= 500
            ORDER BY as_of_date DESC
            LIMIT 1
        ),
        focus_instruments AS (
            SELECT fu.instrument_id, i.ticker, fu.activity_rank_global
            FROM instrument_focus_universe fu
            JOIN latest_focus lf ON fu.as_of_date = lf.as_of_date
            JOIN instruments i ON i.id = fu.instrument_id
            ORDER BY fu.activity_rank_global ASC
            LIMIT %s
        ),
        data_counts AS (
            SELECT 
                fi.instrument_id,
                fi.ticker,
                COUNT(p.price_date) as existing_days,
                MIN(p.price_date) as earliest_date,
                MAX(p.price_date) as latest_date
            FROM focus_instruments fi
            LEFT JOIN instrument_price_daily p 
                ON p.instrument_id = fi.instrument_id 
                AND p.data_source = %s
            GROUP BY fi.instrument_id, fi.ticker
        )
        SELECT 
            dc.instrument_id,
            dc.ticker,
            dc.existing_days,
            dc.earliest_date,
            dc.latest_date
        FROM data_counts dc
        ORDER BY dc.existing_days ASC, dc.ticker ASC;
    """, (limit, DATA_SOURCE))
    
    rows = cur.fetchall()
    log.info(f"Found {len(rows)} instruments to potentially backfill")
    return rows


def fetch_historical_aggregates(ticker: str, start_date: str, end_date: str) -> list[dict] | None:
    """
    Call Polygon /v2/aggs/ticker/{ticker}/range to get historical daily bars.
    
    Args:
        ticker: Stock ticker symbol
        start_date: Start date in YYYY-MM-DD format
        end_date: End date in YYYY-MM-DD format
    
    Returns:
        List of dicts with keys (open, high, low, close, volume, timestamp_ms)
        or None if error occurs.
    """
    url = f"https://api.polygon.io/v2/aggs/ticker/{ticker}/range/1/day/{start_date}/{end_date}"
    params = {
        "adjusted": "true",
        "sort": "asc",
        "limit": "50000",  # Max limit per request
        "apiKey": POLYGON_API_KEY,
    }

    try:
        resp = requests.get(url, params=params, timeout=30)
        resp.raise_for_status()
    except requests.exceptions.ReadTimeout:
        log.warning(f"ticker={ticker}: Read timeout from Polygon aggregates endpoint, skipping.")
        return None
    except requests.exceptions.RequestException as e:
        log.warning(f"ticker={ticker}: request error from Polygon aggregates endpoint: {e}")
        return None

    try:
        data = resp.json()
    except json.JSONDecodeError as e:
        log.warning(f"ticker={ticker}: failed to decode JSON: {e}")
        return None

    status = data.get("status")
    if status not in ("OK", "DELAYED"):
        log.warning(f"ticker={ticker}: non-OK status from Polygon aggregates: {status}")
        return None
    
    # DELAYED status is OK for historical data (means data is delayed but available)
    if status == "DELAYED":
        log.info(f"ticker={ticker}: Received DELAYED status (data available but delayed)")

    results = data.get("results") or []
    if not results:
        log.info(f"ticker={ticker}: no results in aggregates response")
        return None

    bars = []
    for r in results:
        try:
            bars.append({
                "open": float(r.get("o")),
                "high": float(r.get("h")),
                "low": float(r.get("l")),
                "close": float(r.get("c")),
                "volume": float(r.get("v")) if r.get("v") is not None else None,
                "timestamp_ms": int(r.get("t")),
            })
        except Exception as e:
            log.warning(f"ticker={ticker}: error parsing aggregate result: {e}")
            continue

    log.info(f"ticker={ticker}: fetched {len(bars)} historical bars from {start_date} to {end_date}")
    return bars


def ms_to_date_utc(ts_ms: int):
    """Convert Polygon millisecond timestamp to a DATE (UTC)."""
    dt = datetime.fromtimestamp(ts_ms / 1000.0, tz=timezone.utc)
    return dt.date()


def upsert_price_rows(cur, rows):
    """
    Upsert into instrument_price_daily using the unique constraint.
    """
    if not rows:
        return

    sql = """
        INSERT INTO instrument_price_daily (
            instrument_id,
            price_date,
            open,
            high,
            low,
            close,
            adj_close,
            volume,
            data_source
        )
        VALUES (
            %(instrument_id)s,
            %(price_date)s,
            %(open)s,
            %(high)s,
            %(low)s,
            %(close)s,
            %(adj_close)s,
            %(volume)s,
            %(data_source)s
        )
        ON CONFLICT (instrument_id, price_date, data_source)
        DO UPDATE SET
            open       = EXCLUDED.open,
            high       = EXCLUDED.high,
            low        = EXCLUDED.low,
            close      = EXCLUDED.close,
            adj_close  = EXCLUDED.adj_close,
            volume     = EXCLUDED.volume,
            updated_at = NOW();
    """

    param_rows = []
    for r in rows:
        param_rows.append({
            "instrument_id": r["instrument_id"],
            "price_date": r["price_date"],
            "open": r["open"],
            "high": r["high"],
            "low": r["low"],
            "close": r["close"],
            "adj_close": r["close"],  # Use close as adj_close for now
            "volume": r["volume"],
            "data_source": DATA_SOURCE,
        })

    execute_batch(cur, sql, param_rows, page_size=500)
    log.info(f"Upserted {len(rows)} rows into instrument_price_daily")


def backfill_instrument(cur, instrument_id: int, ticker: str, existing_days: int, earliest_date, latest_date):
    """
    Backfill historical data for a single instrument.
    Fills both forward (from latest_date to yesterday) and backward (from earliest_date backwards).
    Note: We exclude today's date to avoid delayed data issues.
    """
    today = datetime.now(timezone.utc).date()
    yesterday = today - timedelta(days=1)
    total_rows = 0
    
    # 1. Forward fill: from latest_date to yesterday (exclude today to avoid delayed data)
    if latest_date and latest_date < yesterday:
        start_date = latest_date + timedelta(days=1)
        end_date = yesterday
        log.info(f"ticker={ticker}: Forward filling from {start_date} to {end_date}")
        
        bars = fetch_historical_aggregates(ticker, start_date.isoformat(), end_date.isoformat())
        if bars:
            rows = []
            for bar in bars:
                price_date = ms_to_date_utc(bar["timestamp_ms"])
                rows.append({
                    "instrument_id": instrument_id,
                    "price_date": price_date,
                    "open": bar["open"],
                    "high": bar["high"],
                    "low": bar["low"],
                    "close": bar["close"],
                    "volume": bar["volume"],
                })
            
            if rows:
                upsert_price_rows(cur, rows)
                total_rows += len(rows)
    
    # 2. Backward fill: from earliest_date backwards (if we have data) or from today backwards (if no data)
    if existing_days == 0:
        # No data exists, backfill from BACKFILL_DAYS ago to yesterday (exclude today)
        end_date = yesterday
        start_date = yesterday - timedelta(days=BACKFILL_DAYS)
        log.info(f"ticker={ticker}: No existing data, backfilling from {start_date} to {end_date}")
    elif earliest_date:
        # Backfill backwards from earliest_date
        # Don't go before 2 years ago (Polygon free tier limit)
        min_date = today - timedelta(days=730)
        
        # If earliest_date is already at or before the minimum, skip backward fill
        if earliest_date <= min_date:
            log.info(f"ticker={ticker}: Already has data back to {earliest_date} (at minimum {min_date}), skipping backward fill")
            return total_rows
        
        # Calculate backward fill range
        end_date = earliest_date - timedelta(days=1)
        start_date = max(end_date - timedelta(days=BACKFILL_DAYS), min_date)
        
        # Validate date range (start_date must be <= end_date)
        if start_date >= end_date:
            log.info(f"ticker={ticker}: Skipping backward fill (no valid date range: start={start_date}, end={end_date})")
            return total_rows
            
        log.info(f"ticker={ticker}: Backward filling from {start_date} to {end_date}")
    else:
        log.info(f"ticker={ticker}: Already has data, skipping backward fill")
        return total_rows
    
    # Fetch historical aggregates for backward fill
    bars = fetch_historical_aggregates(ticker, start_date.isoformat(), end_date.isoformat())
    if bars:
        rows = []
        for bar in bars:
            price_date = ms_to_date_utc(bar["timestamp_ms"])
            rows.append({
                "instrument_id": instrument_id,
                "price_date": price_date,
                "open": bar["open"],
                "high": bar["high"],
                "low": bar["low"],
                "close": bar["close"],
                "volume": bar["volume"],
            })
        
        if rows:
            upsert_price_rows(cur, rows)
            total_rows += len(rows)
    
    return total_rows


def run():
    conn = get_conn()
    conn.autocommit = False
    cur = conn.cursor()

    try:
        instruments = get_instruments_to_backfill(cur, MAX_INSTRUMENTS)
        batch_rows = []
        total_rows = 0

        for idx, (instrument_id, ticker, existing_days, earliest_date, latest_date) in enumerate(instruments, start=1):
            log.info(f"[{idx}/{len(instruments)}] Processing {ticker} (has {existing_days} days of data)")
            
            rows_added = backfill_instrument(cur, instrument_id, ticker, existing_days, earliest_date, latest_date)
            total_rows += rows_added
            
            # Commit after each instrument to avoid large transactions
            conn.commit()
            
            if REQUEST_SLEEP_SECS > 0:
                time.sleep(REQUEST_SLEEP_SECS)

        log.info(f"polygon_backfill_historical ETL completed successfully. Total rows upserted: {total_rows}.")

    except Exception as e:
        log.exception(f"Error in polygon_backfill_historical ETL: {e}")
        conn.rollback()
        raise

    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    run()

