"""
ETL job to fetch and store condition codes from Polygon API.

Endpoint: GET /v3/reference/conditions
"""

import os
import json
import logging
import requests
import psycopg2
from typing import List, Dict, Any

POLYGON_API_KEY = os.getenv("POLYGON_API_KEY")
if not POLYGON_API_KEY:
    raise RuntimeError("POLYGON_API_KEY environment variable is required")

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

logging.basicConfig(
    level=logging.INFO,
    format="[polygon_condition_codes] %(message)s",
)
log = logging.getLogger(__name__)


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def fetch_condition_codes(limit: int = 1000) -> List[Dict[str, Any]]:
    """
    Fetch condition codes from Polygon API.
    
    Args:
        limit: Maximum number of results to fetch per page
        
    Returns:
        List of condition code dictionaries
    """
    url = "https://api.polygon.io/v3/reference/conditions"
    params = {
        "apiKey": POLYGON_API_KEY,
        "limit": limit,
    }
    
    all_results = []
    next_url = None
    
    try:
        while True:
            if next_url:
                log.info(f"Fetching next page: {next_url}")
                resp = requests.get(
                    next_url,
                    params={"apiKey": POLYGON_API_KEY},
                    timeout=30,
                )
            else:
                log.info(f"Fetching condition codes from Polygon: {url}")
                resp = requests.get(url, params=params, timeout=30)
            
            resp.raise_for_status()
            data = resp.json()
            
            if data.get("status") != "OK":
                log.warning(f"Non-OK status from Polygon: {data.get('status')}")
                break
            
            results = data.get("results", []) or []
            all_results.extend(results)
            log.info(f"Received {len(results)} condition codes (total: {len(all_results)})")
            
            next_url = data.get("next_url")
            if not next_url:
                break
                
        log.info(f"Fetched {len(all_results)} total condition codes")
        return all_results
        
    except requests.exceptions.RequestException as e:
        log.error(f"Error fetching condition codes: {e}")
        raise
    except json.JSONDecodeError as e:
        log.error(f"Error parsing condition codes JSON: {e}")
        raise


def upsert_condition_code(cur, condition: Dict[str, Any]):
    """
    Upsert a condition code into the database.
    """
    condition_id = condition.get("id")
    if condition_id is None:
        log.warning(f"Skipping condition code without ID: {condition}")
        return
    
    name = condition.get("name", "")
    asset_class = condition.get("asset_class", "")
    data_types = condition.get("data_types", [])
    condition_type = condition.get("type", "")
    
    if not all([name, asset_class, condition_type]):
        log.warning(f"Skipping incomplete condition code: {condition}")
        return
    
    cur.execute(
        """
        INSERT INTO condition_codes (
            id, abbreviation, name, asset_class, data_types, description,
            exchange, legacy, type, sip_mapping, update_rules
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (id)
        DO UPDATE SET
            abbreviation = EXCLUDED.abbreviation,
            name = EXCLUDED.name,
            asset_class = EXCLUDED.asset_class,
            data_types = EXCLUDED.data_types,
            description = EXCLUDED.description,
            exchange = EXCLUDED.exchange,
            legacy = EXCLUDED.legacy,
            type = EXCLUDED.type,
            sip_mapping = EXCLUDED.sip_mapping,
            update_rules = EXCLUDED.update_rules,
            updated_at = NOW()
        """,
        (
            condition_id,
            condition.get("abbreviation"),
            name,
            asset_class,
            data_types,
            condition.get("description"),
            condition.get("exchange"),
            condition.get("legacy", False),
            condition_type,
            json.dumps(condition.get("sip_mapping")) if condition.get("sip_mapping") else None,
            json.dumps(condition.get("update_rules")) if condition.get("update_rules") else None,
        ),
    )


def main():
    """Main ETL function."""
    conditions = fetch_condition_codes()
    
    conn = get_conn()
    conn.autocommit = False
    cur = conn.cursor()
    
    try:
        for condition in conditions:
            upsert_condition_code(cur, condition)
        
        conn.commit()
        log.info(f"Successfully upserted {len(conditions)} condition codes")
        
    except Exception as e:
        conn.rollback()
        log.error(f"Error upserting condition codes: {e}")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()

