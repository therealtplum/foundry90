import os
import json
import hashlib
import logging
import requests
import psycopg2

POLYGON_API_KEY = os.getenv("POLYGON_API_KEY")
if not POLYGON_API_KEY:
    raise RuntimeError("POLYGON_API_KEY environment variable is required for polygon_instruments ETL")

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

logging.basicConfig(
    level=logging.INFO,
    format="[polygon_instruments] %(message)s",
)
log = logging.getLogger(__name__)


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def normalize_asset_class(market: str | None) -> str | None:
    """
    Map Polygon 'market' to our internal asset_class values.
    """
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
# Compute hash of relevant fields to detect actual changes
# ----------------------------------------------------------------------

def compute_payload_hash(ticker: dict) -> str:
    """
    Compute a stable hash of relevant reference fields so we only update
    instruments when something material changes.
    """
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
# Upsert with change detection (no ON CONFLICT)
# ----------------------------------------------------------------------

def upsert_instrument(cur, t: dict):
    ticker = t.get("ticker")
    if not ticker:
        return

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

    # 1) Check existing hash for (ticker, primary_source)
    cur.execute(
        """
        SELECT source_payload_hash
        FROM instruments
        WHERE ticker = %s
          AND primary_source = %s
        """,
        (ticker, primary_source),
    )
    row = cur.fetchone()

    if row is not None:
        existing_hash = row[0]
        # If nothing changed, skip
        if existing_hash == payload_hash:
            return

        # 2) UPDATE existing row
        cur.execute(
            """
            UPDATE instruments
            SET
                name                = %s,
                asset_class         = %s,
                exchange            = %s,
                currency_code       = %s,
                region              = %s,
                country_code        = %s,
                primary_source      = %s,
                status              = %s,
                source_last_seen_at = NOW(),
                source_payload_hash = %s
            WHERE ticker = %s
              AND primary_source = %s
            """,
            (
                name,
                asset_class,
                exchange,
                currency_code,
                region,
                country_code,
                primary_source,
                status,
                payload_hash,
                ticker,
                primary_source,
            ),
        )
    else:
        # 3) INSERT new row
        cur.execute(
            """
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
            """,
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
# Fetch all tickers from Polygon
# ----------------------------------------------------------------------

# TODO: consider a shared Polygon client module for pagination/backoff logic
#       so polygon_instruments + instrument_focus_universe don’t diverge.

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
                log.info(f"Fetching page {page}: {base_url} params={params}")
                resp = requests.get(base_url, params=params, timeout=30)
            else:
                log.info(f"Fetching page {page}: {next_url} (apiKey only)")
                resp = requests.get(
                    next_url,
                    params={"apiKey": POLYGON_API_KEY},
                    timeout=30,
                )

            resp.raise_for_status()
            data = resp.json()

            results = data.get("results", []) or []
            log.info(f"Received {len(results)} instruments on page {page}")

            for t in results:
                upsert_instrument(cur, t)
                updates += 1

            conn.commit()

            next_url = data.get("next_url")
            if not next_url:
                break

            page += 1

        log.info(f"Done. Upserted/checked ~{updates} instruments.")

    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    fetch_all_tickers()