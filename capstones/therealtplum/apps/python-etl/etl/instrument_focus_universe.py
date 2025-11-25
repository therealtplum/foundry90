import os
import requests
import psycopg2
from psycopg2.extras import execute_values
from datetime import date
import requests
from requests import HTTPError

POLYGON_API_KEY = os.environ["POLYGON_API_KEY"]
DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

# How many globally, and minimum per asset_class
GLOBAL_TOP_N = 500
MIN_PER_ASSET_CLASS = {
    "equity": 200,
    "etf": 100,
    "crypto": 100,
}


def get_conn():
    return psycopg2.connect(DATABASE_URL)

def fetch_polygon_snapshot(url: str) -> list[dict]:
    params = {"apiKey": POLYGON_API_KEY}
    print(f"[instrument_focus] Fetching snapshot: {url}")
    resp = requests.get(url, params=params, timeout=30)

    # Handle permission issues gracefully
    if resp.status_code == 403:
        print(f"[instrument_focus] 403 Forbidden from Polygon for {url} – skipping this snapshot.")
        return []

    try:
        resp.raise_for_status()
    except HTTPError as e:
        print(f"[instrument_focus] ERROR for {url}: {e}")
        return []

    data = resp.json()
    return data.get("tickers", [])


def build_activity_from_snapshots() -> dict[str, dict]:
    """
    Returns a dict keyed by ticker:
      {
        "TICKER": {"volume": float, "dollar_volume": float},
        ...
      }
    Uses Polygon snapshot endpoints for stocks + crypto.
    """

    ticker_activity: dict[str, dict] = {}

    # US stocks snapshot (includes equities/ETFs that trade on US exchanges)
    stocks_url = "https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers"
    stock_tickers = fetch_polygon_snapshot(stocks_url)

    for t in stock_tickers:
        ticker = t.get("ticker")
        if not ticker:
            continue

        day = t.get("day") or {}
        v = day.get("v") or 0  # volume
        vw = day.get("vw") or 0  # volume-weighted avg price
        dollar_volume = float(v) * float(vw)

        ticker_activity[ticker] = {
            "volume": float(v),
            "dollar_volume": dollar_volume,
        }

    # Crypto snapshot (optional but nice)
    crypto_url = "https://api.polygon.io/v2/snapshot/locale/global/markets/crypto/tickers"
    crypto_tickers = fetch_polygon_snapshot(crypto_url)

    for t in crypto_tickers:
        ticker = t.get("ticker")
        if not ticker:
            continue

        day = t.get("day") or {}
        v = day.get("v") or 0
        vw = day.get("vw") or 0
        dollar_volume = float(v) * float(vw)

        # If crypto share the same ticker symbols as stocks, this would overwrite,
        # but in practice they live in a different namespace (e.g. X:BTCUSD).
        ticker_activity[ticker] = {
            "volume": float(v),
            "dollar_volume": dollar_volume,
        }

    print(f"[instrument_focus] Built activity metrics for {len(ticker_activity)} tickers")
    return ticker_activity


def load_instruments_for_tickers(conn, tickers: list[str]) -> list[dict]:
    """
    Look up our instruments by ticker so we can map Polygon tickers -> instrument_id + asset_class.
    """
    if not tickers:
        return []

    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, ticker, asset_class
        FROM instruments
        WHERE ticker = ANY(%s)
        """,
        (tickers,),
    )
    rows = cur.fetchall()
    cur.close()

    instruments = []
    for (inst_id, ticker, asset_class) in rows:
        instruments.append(
            {
                "id": inst_id,
                "ticker": ticker,
                "asset_class": asset_class,
            }
        )

    print(f"[instrument_focus] Matched {len(instruments)} instruments from DB")
    return instruments


def build_focus_universe(conn):
    """
    Main job:
      1. Pull Polygon snapshots (stocks + crypto).
      2. Compute dollar volume per ticker.
      3. Join to our instruments.
      4. Compute global + per-asset_class ranks.
      5. Select top N globally + min per asset_class.
      6. Upsert into instrument_focus_universe for today.
    """

    today = date.today()

    # 1) Get activity metrics from Polygon
    activity = build_activity_from_snapshots()
    if not activity:
        print("[instrument_focus] No activity metrics; aborting.")
        return

    # 2) Map to our instruments
    conn.autocommit = False
    instruments = load_instruments_for_tickers(conn, list(activity.keys()))

    # Attach activity metrics
    enriched = []
    for inst in instruments:
        t = inst["ticker"]
        m = activity.get(t)
        if not m:
            continue

        enriched.append(
            {
                "id": inst["id"],
                "ticker": t,
                "asset_class": inst["asset_class"],
                "volume": m["volume"],
                "dollar_volume": m["dollar_volume"],
            }
        )

    if not enriched:
        print("[instrument_focus] No enriched instruments; aborting.")
        conn.rollback()
        return

    # 3) Rank globally by dollar_volume
    enriched.sort(key=lambda x: x["dollar_volume"], reverse=True)
    for rank, inst in enumerate(enriched, start=1):
        inst["rank_global"] = rank

    # 4) Rank within each asset_class
    by_asset: dict[str, list[dict]] = {}
    for inst in enriched:
        asset = inst.get("asset_class") or "unknown"
        by_asset.setdefault(asset, []).append(inst)

    for asset, items in by_asset.items():
        items.sort(key=lambda x: x["dollar_volume"], reverse=True)
        for rank, inst in enumerate(items, start=1):
            inst["rank_asset_class"] = rank

    # 5) Select focus universe: global top N + min per asset_class
    #    Use set of instrument_ids to dedupe.
    selected_ids = set()

    # Global top N
    for inst in enriched[:GLOBAL_TOP_N]:
        selected_ids.add(inst["id"])

    # Per asset_class minimums
    for asset, min_count in MIN_PER_ASSET_CLASS.items():
        items = by_asset.get(asset, [])
        for inst in items[:min_count]:
            selected_ids.add(inst["id"])

    focus_instruments = [inst for inst in enriched if inst["id"] in selected_ids]

    print(
        f"[instrument_focus] Focus universe for {today}: "
        f"{len(focus_instruments)} instruments "
        f"(global top {GLOBAL_TOP_N} + per-asset mins {MIN_PER_ASSET_CLASS})"
    )

    # 6) Upsert into instrument_focus_universe
    cur = conn.cursor()

    # Clear any existing rows for today (simple + idempotent)
    cur.execute(
        "DELETE FROM instrument_focus_universe WHERE as_of_date = %s",
        (today,),
    )

    rows_to_insert = [
        (
            today,
            inst["id"],
            inst.get("asset_class"),
            inst["dollar_volume"],
            inst["volume"],
            inst["rank_global"],
            inst["rank_asset_class"],
        )
        for inst in focus_instruments
    ]

    insert_sql = """
        INSERT INTO instrument_focus_universe (
            as_of_date,
            instrument_id,
            asset_class,
            dollar_volume,
            volume,
            activity_rank_global,
            activity_rank_asset_class
        )
        VALUES %s
    """

    execute_values(cur, insert_sql, rows_to_insert)
    conn.commit()
    cur.close()

    print("[instrument_focus] Upserted focus universe successfully.")


if __name__ == "__main__":
    conn = get_conn()
    try:
        build_focus_universe(conn)
    finally:
        conn.close()