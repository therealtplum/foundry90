import os
import json
import logging
import time
from datetime import datetime, timezone

import requests
import psycopg2
from psycopg2.extras import execute_batch

POLYGON_API_KEY = os.getenv("POLYGON_API_KEY")
if not POLYGON_API_KEY:
    raise RuntimeError("POLYGON_API_KEY environment variable is required for polygon_price_prev_daily ETL")

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

logging.basicConfig(
    level=logging.INFO,
    format="[polygon_price_prev_daily] %(message)s",
)
log = logging.getLogger(__name__)

# How many instruments to process in one run
MAX_INSTRUMENTS = int(os.getenv("PRICE_PREV_MAX_INSTRUMENTS", "2000"))

# Small sleep between requests to be nice to Polygon
REQUEST_SLEEP_SECS = float(os.getenv("PRICE_PREV_SLEEP_SECS", "0.02"))

# Flush to DB every N price rows
BATCH_SIZE = int(os.getenv("PRICE_PREV_BATCH_SIZE", "500"))

DATA_SOURCE = "polygon_prev"


def get_conn():
    return psycopg2.connect(DATABASE_URL)


# ----------------------------------------------------------------------
# DB helpers
# ----------------------------------------------------------------------


def fetch_instruments_for_prices(cur):
    """
    Get a list of (instrument_id, ticker) from instruments_useq.

    We use the curated US equity universe view so we don't pull for OTC/grey junk.
    """
    cur.execute(
        """
        SELECT id, ticker
        FROM instruments_useq
        WHERE status = 'active'
        ORDER BY ticker
        LIMIT %s;
        """,
        (MAX_INSTRUMENTS,),
    )
    rows = cur.fetchall()
    log.info(f"Fetched {len(rows)} instruments from instruments_useq for price loading")
    return rows


def upsert_price_rows(cur, rows):
    """
    Upsert into instrument_price_daily using the unique constraint:
    (instrument_id, price_date, data_source).

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
                "adj_close": r["adj_close"],
                "volume": r["volume"],
                "data_source": DATA_SOURCE,
            }
        )

    execute_batch(cur, sql, param_rows, page_size=500)
    log.info(f"Upserted {len(rows)} rows into instrument_price_daily")


# ----------------------------------------------------------------------
# Polygon API
# ----------------------------------------------------------------------


def fetch_prev_bar(ticker: str) -> dict | None:
    """
    Call Polygon /v2/aggs/ticker/{ticker}/prev to get the previous day's OHLCV.

    Returns:
        dict with keys (open, high, low, close, volume, timestamp_ms)
        or None if no data or if an error occurs.
    """
    url = f"https://api.polygon.io/v2/aggs/ticker/{ticker}/prev"
    params = {
        "adjusted": "true",
        "apiKey": POLYGON_API_KEY,
    }

    try:
        resp = requests.get(url, params=params, timeout=20)  # bump timeout a bit
        resp.raise_for_status()
    except requests.exceptions.ReadTimeout:
        log.warning(f"ticker={ticker}: Read timeout from Polygon prev endpoint, skipping.")
        return None
    except requests.exceptions.RequestException as e:
        log.warning(f"ticker={ticker}: request error from Polygon prev endpoint: {e}")
        return None

    try:
        data = resp.json()
    except json.JSONDecodeError as e:
        log.warning(f"ticker={ticker}: failed to decode JSON: {e}")
        return None

    if data.get("status") != "OK":
        log.warning(f"ticker={ticker}: non-OK status from Polygon prev endpoint: {data}")
        return None

    results = data.get("results") or []
    if not results:
        log.info(f"ticker={ticker}: no results in prev response")
        return None

    r = results[0]
    try:
        return {
            "open": float(r.get("o")),
            "high": float(r.get("h")),
            "low": float(r.get("l")),
            "close": float(r.get("c")),
            "volume": float(r.get("v")) if r.get("v") is not None else None,
            "timestamp_ms": int(r.get("t")),
        }
    except Exception as e:
        log.warning(f"ticker={ticker}: error parsing prev result: {e} data={json.dumps(r)}")
        return None


def ms_to_date_utc(ts_ms: int):
    """
    Convert Polygon millisecond timestamp to a DATE (UTC) for price_date.
    """
    dt = datetime.fromtimestamp(ts_ms / 1000.0, tz=timezone.utc)
    return dt.date()


# ----------------------------------------------------------------------
# Main ETL logic
# ----------------------------------------------------------------------


def run():
    conn = get_conn()
    conn.autocommit = False
    cur = conn.cursor()

    try:
        instruments = fetch_instruments_for_prices(cur)
        batch_rows = []
        total_rows = 0

        for idx, (instrument_id, ticker) in enumerate(instruments, start=1):
            if idx % 100 == 0:
                log.info(f"Processed {idx}/{len(instruments)} instruments so far...")

            prev = fetch_prev_bar(ticker)
            if not prev:
                if REQUEST_SLEEP_SECS > 0:
                    time.sleep(REQUEST_SLEEP_SECS)
                continue

            price_date = ms_to_date_utc(prev["timestamp_ms"])

            row = {
                "instrument_id": instrument_id,
                "price_date": price_date,
                "open": prev["open"],
                "high": prev["high"],
                "low": prev["low"],
                "close": prev["close"],
                "adj_close": prev["close"],  # can adjust later if needed
                "volume": prev["volume"],
            }
            batch_rows.append(row)
            total_rows += 1

            # Flush periodically so we don't lose work on a late failure
            if len(batch_rows) >= BATCH_SIZE:
                log.info(f"Flushing batch of {len(batch_rows)} price rows to DB...")
                upsert_price_rows(cur, batch_rows)
                conn.commit()
                batch_rows.clear()

            if REQUEST_SLEEP_SECS > 0:
                time.sleep(REQUEST_SLEEP_SECS)

        # Final flush
        if batch_rows:
            log.info(f"Flushing final batch of {len(batch_rows)} price rows to DB...")
            upsert_price_rows(cur, batch_rows)
            conn.commit()
            batch_rows.clear()

        log.info(f"polygon_price_prev_daily ETL completed successfully. Total rows upserted ~{total_rows}.")

    except Exception as e:
        log.exception(f"Error in polygon_price_prev_daily ETL: {e}")
        conn.rollback()
        raise

    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    run()