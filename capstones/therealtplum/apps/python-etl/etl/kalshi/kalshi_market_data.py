import os
import json
import logging
import time
from datetime import datetime, timezone, date

import requests
import psycopg2
from psycopg2.extras import execute_batch

KALSHI_BASE_URL = os.getenv("KALSHI_BASE_URL", "https://api.elections.kalshi.com/trade-api/v2")

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

logging.basicConfig(
    level=logging.INFO,
    format="[kalshi_market_data] %(message)s",
)
log = logging.getLogger(__name__)

# How many instruments to process in one run
MAX_INSTRUMENTS = int(os.getenv("KALSHI_MAX_INSTRUMENTS", "500"))

# Small sleep between requests
REQUEST_SLEEP_SECS = float(os.getenv("KALSHI_SLEEP_SECS", "0.1"))

# Flush to DB every N price rows
BATCH_SIZE = int(os.getenv("KALSHI_BATCH_SIZE", "100"))

DATA_SOURCE = "kalshi"


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def fetch_kalshi_instruments(cur):
    """
    Get a list of (instrument_id, ticker) from instruments where primary_source='kalshi'.
    """
    cur.execute(
        """
        SELECT id, ticker
        FROM instruments
        WHERE primary_source = 'kalshi'
          AND status = 'active'
        ORDER BY ticker
        LIMIT %s;
        """,
        (MAX_INSTRUMENTS,),
    )
    rows = cur.fetchall()
    log.info(f"Fetched {len(rows)} Kalshi instruments for market data loading")
    return rows


def upsert_market_data_rows(cur, rows):
    """
    Upsert into instrument_price_daily.
    
    For Kalshi markets, we store:
    - close: current yes price (0-100, representing probability)
    - open/high/low: can be derived from order book or set to close for simplicity
    - volume: number of contracts traded
    
    rows = list of dicts with keys:
        instrument_id, price_date, open, high, low, close, adj_close, volume
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
        param_rows.append(
            {
                "instrument_id": r["instrument_id"],
                "price_date": r["price_date"],
                "open": r["open"],
                "high": r["high"],
                "low": r["low"],
                "close": r["close"],
                "adj_close": r["close"],  # For prediction markets, adj_close = close
                "volume": r["volume"],
                "data_source": DATA_SOURCE,
            }
        )
    
    execute_batch(cur, sql, param_rows, page_size=500)
    log.info(f"Upserted {len(rows)} rows into instrument_price_daily")


def fetch_market_data(ticker: str) -> dict | None:
    """
    Fetch current market data for a Kalshi market.
    
    Kalshi API endpoint: GET /markets/{ticker}
    Returns current yes price, volume, and order book data.
    
    Note: Kalshi markets are binary (yes/no). The yes price represents
    the probability (0-100) that the event will occur.
    """
    url = f"{KALSHI_BASE_URL}/markets/{ticker}"
    
    try:
        resp = requests.get(url, timeout=20)
        resp.raise_for_status()
    except requests.exceptions.RequestException as e:
        log.warning(f"ticker={ticker}: request error from Kalshi API: {e}")
        return None
    
    try:
        data = resp.json()
    except json.JSONDecodeError as e:
        log.warning(f"ticker={ticker}: failed to decode JSON: {e}")
        return None
    
    # Kalshi API may return market directly or nested
    market = data.get("market") or data
    
    if not market or not isinstance(market, dict):
        log.warning(f"ticker={ticker}: no market data in response")
        return None
    
    # Extract current yes price (0-100, representing probability)
    # Kalshi markets have a "yes" and "no" side
    # The yes price is the current probability estimate
    # Try different field names that Kalshi might use
    yes_bid = market.get("yes_bid") or market.get("yesBid") or 0
    yes_ask = market.get("yes_ask") or market.get("yesAsk") or 0
    
    # Calculate mid price
    if yes_bid and yes_ask:
        yes_price = (yes_bid + yes_ask) / 2
    elif yes_bid:
        yes_price = yes_bid
    elif yes_ask:
        yes_price = yes_ask
    else:
        # Try last price if available
        yes_price = market.get("yes_price") or market.get("yesPrice") or market.get("last_price") or 0
    
    # Volume (number of contracts)
    volume = market.get("volume") or market.get("total_volume") or 0
    
    # Use current date as price_date
    price_date = date.today()
    
    # For prediction markets, we'll use the yes price as close
    # and set open/high/low to the same value for simplicity
    # (or we could track historical prices if available)
    # Note: yes_price is typically 0-100, representing percentage probability
    return {
        "open": yes_price,
        "high": yes_price,
        "low": yes_price,
        "close": yes_price,
        "volume": volume,
        "price_date": price_date,
    }


def run():
    """
    Main ETL function to fetch and store Kalshi market data.
    """
    conn = get_conn()
    conn.autocommit = False
    cur = conn.cursor()
    
    try:
        instruments = fetch_kalshi_instruments(cur)
        batch_rows = []
        total_rows = 0
        
        for idx, (instrument_id, ticker) in enumerate(instruments, start=1):
            if idx % 50 == 0:
                log.info(f"Processed {idx}/{len(instruments)} instruments so far...")
            
            market_data = fetch_market_data(ticker)
            if not market_data:
                if REQUEST_SLEEP_SECS > 0:
                    time.sleep(REQUEST_SLEEP_SECS)
                continue
            
            row = {
                "instrument_id": instrument_id,
                "price_date": market_data["price_date"],
                "open": market_data["open"],
                "high": market_data["high"],
                "low": market_data["low"],
                "close": market_data["close"],
                "volume": market_data["volume"],
            }
            batch_rows.append(row)
            total_rows += 1
            
            # Flush periodically
            if len(batch_rows) >= BATCH_SIZE:
                log.info(f"Flushing batch of {len(batch_rows)} market data rows to DB...")
                upsert_market_data_rows(cur, batch_rows)
                conn.commit()
                batch_rows.clear()
            
            if REQUEST_SLEEP_SECS > 0:
                time.sleep(REQUEST_SLEEP_SECS)
        
        # Final flush
        if batch_rows:
            log.info(f"Flushing final batch of {len(batch_rows)} market data rows to DB...")
            upsert_market_data_rows(cur, batch_rows)
            conn.commit()
            batch_rows.clear()
        
        log.info(f"kalshi_market_data ETL completed successfully. Total rows upserted ~{total_rows}.")
    
    except Exception as e:
        log.exception(f"Error in kalshi_market_data ETL: {e}")
        conn.rollback()
        raise
    
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    run()

