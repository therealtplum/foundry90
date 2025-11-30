"""
ETL job to fetch and store market holidays from Polygon API.

Endpoint: GET /v1/marketstatus/upcoming
"""

import os
import json
import logging
import requests
import psycopg2
from datetime import datetime
from typing import List, Dict, Any

POLYGON_API_KEY = os.getenv("POLYGON_API_KEY")
if not POLYGON_API_KEY:
    raise RuntimeError("POLYGON_API_KEY environment variable is required")

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

logging.basicConfig(
    level=logging.INFO,
    format="[polygon_market_holidays] %(message)s",
)
log = logging.getLogger(__name__)


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def fetch_market_holidays() -> List[Dict[str, Any]]:
    """
    Fetch upcoming market holidays from Polygon API.
    
    Returns:
        List of holiday dictionaries
    """
    url = "https://api.polygon.io/v1/marketstatus/upcoming"
    params = {
        "apiKey": POLYGON_API_KEY,
    }
    
    try:
        log.info(f"Fetching market holidays from Polygon: {url}")
        resp = requests.get(url, params=params, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        
        holidays = data if isinstance(data, list) else []
        log.info(f"Received {len(holidays)} market holidays")
        return holidays
        
    except requests.exceptions.RequestException as e:
        log.error(f"Error fetching market holidays: {e}")
        raise
    except json.JSONDecodeError as e:
        log.error(f"Error parsing market holidays JSON: {e}")
        raise


def upsert_holiday(cur, holiday: Dict[str, Any]):
    """
    Upsert a market holiday into the database.
    """
    date_str = holiday.get("date")
    exchange = holiday.get("exchange")
    name = holiday.get("name")
    status = holiday.get("status")
    
    if not all([date_str, exchange, name, status]):
        log.warning(f"Skipping incomplete holiday record: {holiday}")
        return
    
    # Parse date
    try:
        holiday_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError as e:
        log.warning(f"Invalid date format '{date_str}': {e}")
        return
    
    # Parse optional times
    open_time = None
    close_time = None
    if "open" in holiday:
        try:
            open_time = datetime.fromisoformat(holiday["open"].replace("Z", "+00:00"))
        except (ValueError, KeyError):
            pass
    if "close" in holiday:
        try:
            close_time = datetime.fromisoformat(holiday["close"].replace("Z", "+00:00"))
        except (ValueError, KeyError):
            pass
    
    cur.execute(
        """
        INSERT INTO market_holidays (
            date, exchange, name, status, open_time, close_time
        )
        VALUES (%s, %s, %s, %s, %s, %s)
        ON CONFLICT (date, exchange)
        DO UPDATE SET
            name = EXCLUDED.name,
            status = EXCLUDED.status,
            open_time = EXCLUDED.open_time,
            close_time = EXCLUDED.close_time,
            updated_at = NOW()
        """,
        (holiday_date, exchange, name, status, open_time, close_time),
    )


def main():
    """Main ETL function."""
    holidays = fetch_market_holidays()
    
    conn = get_conn()
    conn.autocommit = False
    cur = conn.cursor()
    
    try:
        for holiday in holidays:
            upsert_holiday(cur, holiday)
        
        conn.commit()
        log.info(f"Successfully upserted {len(holidays)} market holidays")
        
    except Exception as e:
        conn.rollback()
        log.error(f"Error upserting market holidays: {e}")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()

