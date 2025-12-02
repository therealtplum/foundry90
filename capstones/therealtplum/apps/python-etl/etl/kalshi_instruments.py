import os
import json
import hashlib
import logging
import requests
import psycopg2

# Kalshi API configuration
KALSHI_API_KEY = os.getenv("KALSHI_API_KEY")
KALSHI_KEY_ID = os.getenv("KALSHI_KEY_ID")
KALSHI_BASE_URL = os.getenv("KALSHI_BASE_URL", "https://api.elections.kalshi.com/trade-api/v2")

# Note: Kalshi uses RSA-PSS signing for authenticated requests, but public market data
# endpoints may not require authentication. For now, we'll use public endpoints.
# If authentication is needed, we'll need to implement RSA-PSS signing.

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

logging.basicConfig(
    level=logging.INFO,
    format="[kalshi_instruments] %(message)s",
)
log = logging.getLogger(__name__)


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def normalize_asset_class(market_data: dict) -> str:
    """
    Map Kalshi market data to our internal asset_class.
    
    Kalshi markets are prediction markets, so we'll use 'other' for now.
    In the future, we could extend the schema to add 'prediction_market'.
    """
    return "other"


def compute_payload_hash(market: dict) -> str:
    """
    Compute a stable hash of relevant market fields to detect changes.
    """
    relevant = {
        "ticker": market.get("ticker"),
        "title": market.get("title"),
        "subtitle": market.get("subtitle"),
        "status": market.get("status"),
        "series_ticker": market.get("series_ticker"),
        "event_ticker": market.get("event_ticker"),
    }
    s = json.dumps(relevant, sort_keys=True)
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def upsert_instrument(cur, market: dict):
    """
    Upsert a Kalshi market as an instrument.
    
    Kalshi markets have:
    - ticker: unique identifier (e.g., "BIDEN-2024")
    - title: market question/title
    - subtitle: additional context
    - status: market status (open, closed, etc.)
    - series_ticker: series identifier
    - event_ticker: event identifier
    """
    ticker = market.get("ticker")
    if not ticker:
        return

    # Use title as name, fallback to ticker
    name = market.get("title") or market.get("subtitle") or ticker
    
    asset_class = normalize_asset_class(market)
    
    # Kalshi is a US-based exchange
    exchange = "KALSHI"
    currency_code = "USD"
    region = "US"
    country_code = "US"
    
    primary_source = "kalshi"
    status = "active" if market.get("status") in ["open", "active"] else "inactive"
    
    payload_hash = compute_payload_hash(market)
    
    # Store Kalshi-specific data in external_ref JSONB
    external_ref = {
        "kalshi_ticker": ticker,
        "series_ticker": market.get("series_ticker"),
        "event_ticker": market.get("event_ticker"),
        "market_status": market.get("status"),
        "subtitle": market.get("subtitle"),
    }
    
    # Check existing hash for (ticker, primary_source)
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
        
        # Update existing row
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
                status              = %s,
                external_ref        = %s,
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
                status,
                json.dumps(external_ref),
                payload_hash,
                ticker,
                primary_source,
            ),
        )
    else:
        # Insert new row
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
                external_ref,
                source_last_seen_at,
                source_payload_hash
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW(), %s)
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
                json.dumps(external_ref),
                payload_hash,
            ),
        )


def fetch_all_markets(use_filters: bool = False):
    """
    Fetch all active markets from Kalshi API.
    
    Kalshi API endpoint: GET /markets
    This is a public endpoint that doesn't require authentication.
    
    Note: Kalshi API uses cursor-based pagination. The response includes
    a 'cursor' field that should be used for the next page.
    
    Args:
        use_filters: If True, use filters_by_sport data for optimized fetching
    """
    # Use optimized version if requested and available
    if use_filters:
        try:
            from kalshi_instruments_optimized import fetch_all_markets_optimized
            log.info("Using optimized fetch with filters_by_sport data...")
            fetch_all_markets_optimized()
            return
        except ImportError:
            log.warning("Optimized module not available, falling back to standard fetch")
        except Exception as e:
            log.warning(f"Optimized fetch failed: {e}, falling back to standard fetch")
    
    base_url = f"{KALSHI_BASE_URL}/markets"
    params = {
        "limit": 1000,  # Max per page
        "status": "open",  # Only fetch open markets
    }
    
    conn = get_conn()
    conn.autocommit = False
    cur = conn.cursor()
    
    updates = 0
    cursor = None
    page = 0
    
    try:
        while True:
            if cursor:
                params["cursor"] = cursor
            else:
                # Remove cursor on first request
                params.pop("cursor", None)
            
            log.info(f"Fetching Kalshi markets page {page + 1} (cursor={cursor})")
            
            try:
                resp = requests.get(base_url, params=params, timeout=30)
                resp.raise_for_status()
                data = resp.json()
            except requests.exceptions.RequestException as e:
                log.error(f"Error fetching Kalshi markets: {e}")
                if hasattr(e, 'response') and e.response is not None:
                    log.error(f"Response status: {e.response.status_code}, body: {e.response.text}")
                break
            
            # Kalshi API structure may vary - try different response formats
            markets = data.get("markets", []) or data.get("results", []) or []
            log.info(f"Received {len(markets)} markets on page {page + 1}")
            
            if not markets:
                break
            
            for market in markets:
                upsert_instrument(cur, market)
                updates += 1
            
            conn.commit()
            
            # Get next cursor for pagination
            cursor = data.get("cursor")
            if not cursor:
                # No more pages
                break
            
            page += 1
            
            # Safety limit to prevent infinite loops
            if page > 1000:
                log.warning("Reached maximum page limit (1000), stopping")
                break
        
        log.info(f"Done. Upserted/checked ~{updates} Kalshi markets.")
    
    except Exception as e:
        log.exception(f"Error in fetch_all_markets: {e}")
        conn.rollback()
        raise
    
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    fetch_all_markets()

