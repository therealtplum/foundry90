#!/usr/bin/env python3
"""
Fetch and store Kalshi filters_by_sport API data.

This endpoint provides the available sports, competitions, and scopes
that Kalshi supports, which is useful for:
- Building search/filter UIs
- Understanding available market types
- Mapping Kalshi's structure to our database

API: https://api.elections.kalshi.com/trade-api/v2/search/filters_by_sport
Documentation: Public endpoint, no authentication required
"""

import os
import json
import logging
import requests
import psycopg2
from typing import Dict, Any, Optional
from datetime import datetime

# Kalshi API configuration
KALSHI_BASE_URL = os.getenv("KALSHI_BASE_URL", "https://api.elections.kalshi.com/trade-api/v2")
FILTERS_BY_SPORT_ENDPOINT = "/search/filters_by_sport"

# Database configuration
# Default to localhost:5433 for local execution, or db:5432 for Docker
DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@localhost:5433/fmhub")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


def get_db_connection():
    """Get database connection from environment variable."""
    database_url = os.getenv('DATABASE_URL', DATABASE_URL)
    if not database_url:
        raise ValueError("DATABASE_URL environment variable not set")
    return psycopg2.connect(database_url)


def fetch_filters_by_sport() -> Optional[Dict[str, Any]]:
    """
    Fetch filters_by_sport data from Kalshi API.
    
    Returns:
        JSON response as dict, or None if request fails
    """
    url = f"{KALSHI_BASE_URL}{FILTERS_BY_SPORT_ENDPOINT}"
    
    try:
        logger.info(f"Fetching filters_by_sport from {url}")
        resp = requests.get(url, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        logger.info("Successfully fetched filters_by_sport data")
        return data
    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching filters_by_sport: {e}")
        return None
    except json.JSONDecodeError as e:
        logger.error(f"Error decoding JSON response: {e}")
        return None


def update_venue_metadata(conn, venue_code: str, metadata: Dict[str, Any]) -> bool:
    """
    Update venue metadata in the database.
    
    We'll store this in a JSONB column. Since the venues table doesn't have
    a metadata column yet, we'll add it or use the notes field temporarily.
    For now, let's add a proper metadata JSONB column.
    
    Args:
        conn: Database connection
        venue_code: Venue code (e.g., 'KALSHI')
        metadata: Metadata dict to store
    
    Returns:
        True if successful
    """
    cursor = conn.cursor()
    
    try:
        # Check if metadata column exists, if not we'll add it
        cursor.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'venues' 
              AND column_name = 'api_metadata'
        """)
        
        if not cursor.fetchone():
            logger.info("Adding api_metadata column to venues table")
            cursor.execute("""
                ALTER TABLE venues 
                ADD COLUMN api_metadata JSONB
            """)
            conn.commit()
            logger.info("Added api_metadata column")
        
        # Update the venue with metadata
        cursor.execute("""
            UPDATE venues
            SET 
                api_metadata = %s,
                updated_at = NOW()
            WHERE venue_code = %s
        """, (json.dumps(metadata), venue_code))
        
        if cursor.rowcount == 0:
            logger.warning(f"Venue '{venue_code}' not found in database")
            return False
        
        conn.commit()
        logger.info(f"Updated metadata for venue: {venue_code}")
        return True
        
    except Exception as e:
        logger.error(f"Error updating venue metadata: {e}")
        conn.rollback()
        return False
    finally:
        cursor.close()


def main():
    """Main function to fetch and store filters_by_sport data."""
    logger.info("Starting Kalshi filters_by_sport sync...")
    
    # Fetch data from API
    data = fetch_filters_by_sport()
    if not data:
        logger.error("Failed to fetch filters_by_sport data")
        return
    
    # Store in database
    conn = get_db_connection()
    try:
        # Add timestamp to metadata
        metadata = {
            "filters_by_sport": data,
            "fetched_at": datetime.utcnow().isoformat(),
            "api_endpoint": f"{KALSHI_BASE_URL}{FILTERS_BY_SPORT_ENDPOINT}",
        }
        
        success = update_venue_metadata(conn, "KALSHI", metadata)
        
        if success:
            # Log summary
            filters = data.get("filters_by_sports", {})
            sport_count = len([k for k in filters.keys() if k != "sport_ordering"])
            logger.info(f"Successfully stored filters for {sport_count} sports")
            
            # Log sport ordering
            sport_ordering = data.get("filters_by_sports", {}).get("sport_ordering", [])
            logger.info(f"Sport ordering: {', '.join(sport_ordering[:5])}...")
        else:
            logger.error("Failed to update venue metadata")
            
    except Exception as e:
        logger.error(f"Error in main: {e}", exc_info=True)
    finally:
        conn.close()


if __name__ == "__main__":
    main()

