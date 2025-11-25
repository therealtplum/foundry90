import os
import json
import hashlib
import requests
import psycopg2

POLYGON_API_KEY = os.environ["POLYGON_API_KEY"]
DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def normalize_asset_class(market: str | None) -> str | None:
    """
    Map Polygon's `market` field into our asset_class_enum.
    """
    if market is None:
        return None

    market = market.lower()
    mapping = {
        "stocks": "equity",
        "otc": "equity",
        "indices": "index",
        "funds": "etf",
        "crypto": "crypto",
        "fx": "fx",
    }
    return mapping.get(market, "other")


def compute_payload_hash(ticker: dict) -> str:
    """
    Hash the "shape" of the upstream record so we can cheaply tell
    whether anything material changed since last time.
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


def upsert_instrument(cur, t: dict) -> None:
    """
    Idempotent upsert of a single Polygon ticker into `instruments`.
    Falls back to ticker as `name` when Polygon omits it.
    """

    ticker = t.get("ticker")
    if not ticker:
        # Should be extremely rare; just skip garbage rows.
        return

    # 🚑 THIS IS THE FIX: never allow name to be NULL
    raw_name = t.get("name")
    name = raw_name if (raw_name and raw_name.strip()) else ticker

    asset_class = normalize_asset_class(t.get("market")) or "other"

    exchange = t.get("primary_exchange")
    currency_code = t.get("currency_name") or "USD"
    locale = (t.get("locale") or "").lower()
    region = locale or None
    country_code = "US" if locale in ("us", "usa") else None

    primary_source = "polygon"
    external_symbol = ticker

    external_ref = {
        "polygon_ticker": ticker,
        "type": t.get("type"),
        "market": t.get("market"),
        "primary_exchange": t.get("primary_exchange"),
        "locale": t.get("locale"),
        "cik": t.get("cik"),
        "composite_figi": t.get("composite_figi"),
    }

    status = "active" if t.get("active") else "inactive"
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
            external_symbol,
            external_ref,
            status,
            source_last_seen_at,
            source_payload_hash
        )
        VALUES (
            %s,  -- ticker
            %s,  -- name (never NULL)
            %s,  -- asset_class
            %s,  -- exchange
            %s,  -- currency_code
            %s,  -- region
            %s,  -- country_code
            %s,  -- primary_source
            %s,  -- external_symbol
            %s,  -- external_ref (JSONB)
            %s,  -- status
            NOW(),
            %s   -- source_payload_hash
        )
        ON CONFLICT (ticker, asset_class, primary_source) DO UPDATE
        SET
            name                = EXCLUDED.name,
            asset_class         = EXCLUDED.asset_class,
            exchange            = EXCLUDED.exchange,
            currency_code       = EXCLUDED.currency_code,
            region              = EXCLUDED.region,
            country_code        = EXCLUDED.country_code,
            primary_source      = EXCLUDED.primary_source,
            external_symbol     = EXCLUDED.external_symbol,
            external_ref        = EXCLUDED.external_ref,
            status              = EXCLUDED.status,
            source_last_seen_at = NOW(),
            source_payload_hash = EXCLUDED.source_payload_hash
        WHERE instruments.source_payload_hash IS DISTINCT FROM EXCLUDED.source_payload_hash;
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
            external_symbol,
            json.dumps(external_ref),
            status,
            payload_hash,
        ),
    )


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

            for row in results:
                upsert_instrument(cur, row)
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