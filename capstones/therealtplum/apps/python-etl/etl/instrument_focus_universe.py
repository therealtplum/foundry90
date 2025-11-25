# apps/python-etl/etl/instrument_focus_universe.py

import os
import sys
import time
import logging
from datetime import date
from typing import Dict, Any, List, Optional, Tuple

import psycopg2
import psycopg2.extras
import requests

POLYGON_API_KEY = os.environ["POLYGON_API_KEY"]
DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

logging.basicConfig(
    level=logging.INFO,
    format="[instrument_focus] %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger(__name__)


# -------------------------------------------------------------------
# DB helpers
# -------------------------------------------------------------------

def get_conn():
    return psycopg2.connect(DATABASE_URL)


# -------------------------------------------------------------------
# Polygon helpers
# -------------------------------------------------------------------

def fetch_polygon_snapshot(url: str) -> List[Dict[str, Any]]:
    """
    Fetch a snapshot from Polygon (stocks or crypto).
    """
    params = {"apiKey": POLYGON_API_KEY}
    log.info(f"Fetching snapshot: {url}")
    resp = requests.get(url, params=params, timeout=30)
    if resp.status_code == 403:
        log.warning(
            f"403 Forbidden from Polygon for {url} – skipping this snapshot."
        )
        return []
    resp.raise_for_status()
    data = resp.json()
    return data.get("tickers", [])


def compute_activity_for_ticker(t: Dict[str, Any], asset_class: str) -> Dict[str, Any]:
    """
    Given a Polygon snapshot ticker payload, compute simple activity metrics.
    We keep it deliberately simple: dollar_volume = close * volume.
    """
    last_quote = t.get("lastQuote", {}) or {}
    last_trade = t.get("lastTrade", {}) or {}
    day = t.get("day", {}) or {}

    # Prefer "c" (close) from day; fallback to last trade price
    close = day.get("c") or last_trade.get("p")
    volume = day.get("v") or last_trade.get("s")

    try:
        close = float(close) if close is not None else None
    except (TypeError, ValueError):
        close = None

    try:
        volume = float(volume) if volume is not None else 0.0
    except (TypeError, ValueError):
        volume = 0.0

    dollar_volume = (close or 0.0) * volume

    return {
        "asset_class": asset_class,
        "dollar_volume": dollar_volume,
        "volume": volume,
    }


def build_activity_from_snapshots() -> Dict[str, Dict[str, Any]]:
    """
    Build a map of ticker -> activity metrics from Polygon snapshots
    for US stocks and global crypto.
    """
    activity: Dict[str, Dict[str, Any]] = {}

    # Stocks snapshot
    stocks_url = "https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers"
    stock_tickers = fetch_polygon_snapshot(stocks_url)
    for t in stock_tickers:
        ticker = t.get("ticker")
        if not ticker:
            continue
        metrics = compute_activity_for_ticker(t, asset_class="equity")
        activity[ticker] = metrics

    # Crypto snapshot (best-effort; may be forbidden on your plan)
    crypto_url = "https://api.polygon.io/v2/snapshot/locale/global/markets/crypto/tickers"
    crypto_tickers = fetch_polygon_snapshot(crypto_url)
    for t in crypto_tickers:
        ticker = t.get("ticker")
        if not ticker:
            continue
        metrics = compute_activity_for_ticker(t, asset_class="crypto")
        # If ticker overlaps with equity universe, keep whichever has higher dollar_volume
        if ticker in activity:
            if metrics["dollar_volume"] > activity[ticker]["dollar_volume"]:
                activity[ticker] = metrics
        else:
            activity[ticker] = metrics

    log.info(f"Built activity metrics for {len(activity)} tickers")
    return activity


def fetch_prev_close_price(ticker: str) -> Optional[float]:
    """
    Fetch previous close price for a ticker from Polygon.

    Uses:
        GET /v2/aggs/ticker/{ticker}/prev?adjusted=true&apiKey=...

    Returns:
        float close price, or None if not available / error.
    """
    url = f"https://api.polygon.io/v2/aggs/ticker/{ticker}/prev"
    params = {"adjusted": "true", "apiKey": POLYGON_API_KEY}

    try:
        resp = requests.get(url, params=params, timeout=10)
        if resp.status_code == 403:
            log.warning(f"403 Forbidden for prev close {ticker} – skipping price.")
            return None
        if resp.status_code == 429:
            # crude backoff
            log.warning(f"429 Too Many Requests for {ticker}, sleeping 1s…")
            time.sleep(1)
            resp = requests.get(url, params=params, timeout=10)

        resp.raise_for_status()
        data = resp.json()
        results = data.get("results") or []
        if not results:
            return None
        close = results[0].get("c")
        if close is None:
            return None
        return float(close)
    except Exception as e:
        log.warning(f"Failed to fetch prev close for {ticker}: {e}")
        return None


# -------------------------------------------------------------------
# Focus universe builder
# -------------------------------------------------------------------

def build_focus_universe(
    conn,
    as_of: Optional[date] = None,
    global_top_n: int = 500,
    min_by_asset: Optional[Dict[str, int]] = None,
) -> None:
    """
    Build the instrument_focus_universe table for a given as_of date.

    Strategy:
      1. Build Polygon activity metrics (dollar_volume, volume, asset_class).
      2. Map tickers to fmhub instruments.
      3. Compute global + per-asset-class ranks.
      4. Select global_top_n overall, and ensure at least min_by_asset per class.
      5. For those focus instruments, fetch prev close price from Polygon
         and upsert into instrument_focus_universe with last_close_price.
    """
    if as_of is None:
        as_of = date.today()

    if min_by_asset is None:
        min_by_asset = {
            "equity": 200,
            "etf": 100,
            "crypto": 100,
        }

    log.info("Building activity metrics from Polygon snapshots…")
    activity = build_activity_from_snapshots()

    # 2. Map tickers to instruments in DB
    ticker_list = list(activity.keys())
    if not ticker_list:
        log.warning("No activity metrics to process. Exiting.")
        return

    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        # Fetch instruments for these tickers
        cur.execute(
            """
            SELECT id, ticker, asset_class::text AS asset_class
            FROM instruments
            WHERE ticker = ANY(%s)
              AND status = 'active'
            """,
            (ticker_list,),
        )
        rows = cur.fetchall()

    by_ticker: Dict[str, Dict[str, Any]] = {}
    for row in rows:
        by_ticker[row["ticker"]] = {
            "instrument_id": row["id"],
            "asset_class": row["asset_class"],
        }

    log.info(f"Matched {len(by_ticker)} instruments from DB")

    # 3. Build list of candidates with activity + instrument mapping
    candidates: List[Dict[str, Any]] = []
    for ticker, metrics in activity.items():
        info = by_ticker.get(ticker)
        if not info:
            continue

        asset_class = info["asset_class"] or metrics["asset_class"]
        dollar_volume = metrics["dollar_volume"]
        volume = metrics["volume"]

        candidates.append(
            {
                "ticker": ticker,
                "instrument_id": info["instrument_id"],
                "asset_class": asset_class,
                "dollar_volume": dollar_volume,
                "volume": volume,
            }
        )

    if not candidates:
        log.warning("No candidates after mapping activity to instruments.")
        return

    # 4. Global ranking by dollar_volume desc
    candidates.sort(key=lambda c: c["dollar_volume"], reverse=True)
    for idx, c in enumerate(candidates, start=1):
        c["rank_global"] = idx

    # 5. Per-asset-class ranking
    per_asset: Dict[str, List[Dict[str, Any]]] = {}
    for c in candidates:
        per_asset.setdefault(c["asset_class"], []).append(c)

    for asset_class, items in per_asset.items():
        items.sort(key=lambda c: c["dollar_volume"], reverse=True)
        for idx, c in enumerate(items, start=1):
            c["rank_asset_class"] = idx

    # 6. Select focus universe: global top + min per asset class
    focus: Dict[int, Dict[str, Any]] = {}

    # global top
    for c in candidates[:global_top_n]:
        focus[c["instrument_id"]] = c

    # min per asset class
    for asset_class, min_n in min_by_asset.items():
        items = per_asset.get(asset_class, [])
        for c in items[:min_n]:
            focus[c["instrument_id"]] = c

    focus_list = list(focus.values())
    log.info(
        f"Focus universe for {as_of}: {len(focus_list)} instruments "
        f"(global top {global_top_n} + per-asset mins {min_by_asset})"
    )

    # 7. Upsert into instrument_focus_universe with last_close_price
    with conn.cursor() as cur:
        for idx, c in enumerate(focus_list, start=1):
            ticker = c["ticker"]
            instrument_id = c["instrument_id"]
            asset_class = c["asset_class"]
            dollar_volume = c["dollar_volume"]
            volume = c["volume"]
            rank_global = c["rank_global"]
            rank_asset = c["rank_asset_class"]

            # Fetch prev close price from Polygon
            last_close_price = fetch_prev_close_price(ticker)

            if idx <= 10:
                # only spam log for first few
                log.info(
                    f"[{idx}/{len(focus_list)}] {ticker} "
                    f"id={instrument_id} dv={dollar_volume:.0f} "
                    f"last_close={last_close_price}"
                )

            cur.execute(
                """
                INSERT INTO instrument_focus_universe (
                    as_of_date,
                    instrument_id,
                    asset_class,
                    dollar_volume,
                    volume,
                    activity_rank_global,
                    activity_rank_asset_class,
                    last_close_price
                )
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (as_of_date, instrument_id)
                DO UPDATE SET
                    asset_class              = EXCLUDED.asset_class,
                    dollar_volume            = EXCLUDED.dollar_volume,
                    volume                   = EXCLUDED.volume,
                    activity_rank_global     = EXCLUDED.activity_rank_global,
                    activity_rank_asset_class= EXCLUDED.activity_rank_asset_class,
                    last_close_price         = EXCLUDED.last_close_price
                """,
                (
                    as_of,
                    instrument_id,
                    asset_class,
                    dollar_volume,
                    volume,
                    rank_global,
                    rank_asset,
                    last_close_price,
                ),
            )

        conn.commit()


# -------------------------------------------------------------------
# CLI entrypoint
# -------------------------------------------------------------------

def main():
    as_of = date.today()
    conn = get_conn()
    try:
        build_focus_universe(conn, as_of=as_of)
    finally:
        conn.close()


if __name__ == "__main__":
    main()