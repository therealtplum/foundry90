import os
import json
import hashlib
import requests
import psycopg2
from psycopg2.extras import execute_values

POLYGON_API_KEY = os.environ["POLYGON_API_KEY"]
DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def normalize_asset_class(market: str | None) -> str | None:
    if market is None:
        return None

    market = market.lower()
    mapping = {
        "stocks": "equity",
        "crypto": "crypto",
        "fx": "fx",
        "otc": "equity",
        "indices": "index",
        "funds": "etf",
    }
    return mapping.get(market, market)


# ----------------------------------------------------------------------
# NEW: Compute hash of relevant fields to detect actual changes
# ----------------------------------------------------------------------
def compute_payload_hash(ticker: dict) -> str:
    relevant = {
        "ticker": ticker.get("ticker"),
        "name": ticker.get("name"),
        "type": ticker.get("type"),
        "market": ticker.get("market"),
        "primary_exchange": ticker.get("primary_exchange"),
        "currency_name": ticker.get("currency_name"),
        "locale": ticker.get("locale"),
    }
    s = json.dumps(relevant, sort_keys=True)
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


# ----------------------------------------------------------------------
# Upsert with change detection
# ----------------------------------------------------------------------
def upsert_instrument(cur, t: dict):
    ticker = t.get("ticker")
    name = t.get("name") or ticker
    market = t.get("market")
    asset_class = normalize_asset_class(market)

    exchange = t.get("primary_exchange") or t.get("exchange") or "UNKNOWN"
    currency_code = t.get("currency_name") or "USD"

    locale = t.get("locale")
    region = (locale or "us").upper()
    country_code = "US" if region == "US" else None

    primary_source = "polygon_reference"
    status = "active" if t.get("active", True) else "inactive"

    payload_hash = compute_payload_hash(t)

    sql = """
        INSERT INTO instruments (
            ticker,
            name,
            asset_class,
            exchange,
            currency_code,
            region,
            country_code,
            primary_source,
            status,
            source_last_seen_at,
            source_payload_hash
        )
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s, NOW(), %s)
        ON CONFLICT (ticker) DO UPDATE SET
            name                = EXCLUDED.name,
            asset_class         = EXCLUDED.asset_class,
            exchange            = EXCLUDED.exchange,
            currency_code       = EXCLUDED.currency_code,
            region              = EXCLUDED.region,
            country_code        = EXCLUDED.country_code,
            primary_source      = EXCLUDED.primary_source,
            status              = EXCLUDED.status,
            source_last_seen_at = NOW(),
            source_payload_hash = EXCLUDED.source_payload_hash
        WHERE
            instruments.source_payload_hash IS DISTINCT FROM EXCLUDED.source_payload_hash;
    """

    cur.execute(
        sql,
        (
            ticker,
            name,
            asset_class,
            exchange,
            currency_code,
            region,
            country_code,
            primary_source,
            status,
            payload_hash,
        ),
    )


# ----------------------------------------------------------------------
# Fetch all tickers (same as your version, unchanged)
# ----------------------------------------------------------------------
def fetch_all_tickers():
    base_url = "https://api.polygon.io/v3/reference/tickers"
    params = {
        "active": "true",
        "limit": 1000,
        "apiKey": POLYGON_API_KEY,
    }

    conn = get_conn()
    conn.autocommit = False
    cur = conn.cursor()

    updates = 0
    page = 1
    next_url = base_url

    try:
        while True:
            if next_url == base_url:
                print(
                    f"[polygon_instruments] Fetching page {page}: {base_url} "
                    f"params={params}"
                )
                resp = requests.get(base_url, params=params, timeout=30)
            else:
                print(
                    f"[polygon_instruments] Fetching page {page}: {next_url} "
                    f"(apiKey only)"
                )
                resp = requests.get(
                    next_url,
                    params={"apiKey": POLYGON_API_KEY},
                    timeout=30,
                )

            resp.raise_for_status()
            data = resp.json()

            results = data.get("results", [])
            print(f"[polygon_instruments]  Received {len(results)} instruments")

            for t in results:
                upsert_instrument(cur, t)
                updates += 1

            conn.commit()

            next_url = data.get("next_url")
            if not next_url:
                break

            page += 1

        print(f"[polygon_instruments] Done. Upserted/checked ~{updates} instruments.")

    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    fetch_all_tickers()