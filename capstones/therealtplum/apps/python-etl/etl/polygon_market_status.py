"""
ETL job to fetch and store current market status from Polygon API.

Endpoint: GET /v1/marketstatus/now
This should be run periodically (e.g., every minute) to track market status.
"""

import os
import json
import logging
import requests
import psycopg2
from datetime import datetime

POLYGON_API_KEY = os.getenv("POLYGON_API_KEY")
if not POLYGON_API_KEY:
    raise RuntimeError("POLYGON_API_KEY environment variable is required")

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

logging.basicConfig(
    level=logging.INFO,
    format="[polygon_market_status] %(message)s",
)
log = logging.getLogger(__name__)


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def fetch_market_status() -> Dict:
    """
    Fetch current market status from Polygon API.
    
    Returns:
        Market status dictionary
    """
    url = "https://api.polygon.io/v1/marketstatus/now"
    params = {
        "apiKey": POLYGON_API_KEY,
    }
    
    try:
        log.info(f"Fetching market status from Polygon: {url}")
        resp = requests.get(url, params=params, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        
        log.info(f"Received market status: market={data.get('market')}")
        return data
        
    except requests.exceptions.RequestException as e:
        log.error(f"Error fetching market status: {e}")
        raise
    except json.JSONDecodeError as e:
        log.error(f"Error parsing market status JSON: {e}")
        raise


def insert_market_status(cur, status: Dict):
    """
    Insert market status snapshot into the database.
    """
    server_time_str = status.get("serverTime")
    if not server_time_str:
        log.warning("No serverTime in market status response")
        return
    
    try:
        # Parse RFC3339 format: "2020-11-10T17:37:37-05:00"
        server_time = datetime.fromisoformat(server_time_str.replace("Z", "+00:00"))
    except ValueError as e:
        log.warning(f"Invalid serverTime format '{server_time_str}': {e}")
        return
    
    exchanges = status.get("exchanges", {})
    currencies = status.get("currencies", {})
    indices_groups = status.get("indicesGroups", {})
    
    cur.execute(
        """
        INSERT INTO market_status (
            server_time, market, after_hours, early_hours,
            exchange_nasdaq, exchange_nyse, exchange_otc,
            currency_crypto, currency_fx,
            indices_groups, raw_response
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            server_time,
            status.get("market", ""),
            status.get("afterHours", False),
            status.get("earlyHours", False),
            exchanges.get("nasdaq"),
            exchanges.get("nyse"),
            exchanges.get("otc"),
            currencies.get("crypto"),
            currencies.get("fx"),
            json.dumps(indices_groups) if indices_groups else None,
            json.dumps(status),
        ),
    )


def main():
    """Main ETL function."""
    status = fetch_market_status()
    
    conn = get_conn()
    conn.autocommit = False
    cur = conn.cursor()
    
    try:
        insert_market_status(cur, status)
        conn.commit()
        log.info("Successfully inserted market status")
        
    except Exception as e:
        conn.rollback()
        log.error(f"Error inserting market status: {e}")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()

