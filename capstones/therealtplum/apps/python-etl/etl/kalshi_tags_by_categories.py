#!/usr/bin/env python3
"""
Fetch and store Kalshi tags_by_categories API data.

This endpoint provides tags organized by categories, which can be used
for filtering markets more precisely than just sports.

API: https://api.elections.kalshi.com/trade-api/v2/search/tags_by_categories
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
TAGS_BY_CATEGORIES_ENDPOINT = "/search/tags_by_categories"

# Database configuration
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


def fetch_tags_by_categories() -> Optional[Dict[str, Any]]:
    """
    Fetch tags_by_categories data from Kalshi API.
    
    Returns:
        JSON response as dict, or None if request fails
    """
    url = f"{KALSHI_BASE_URL}{TAGS_BY_CATEGORIES_ENDPOINT}"
    
    try:
        logger.info(f"Fetching tags_by_categories from {url}")
        resp = requests.get(url, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        logger.info("Successfully fetched tags_by_categories data")
        return data
    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching tags_by_categories: {e}")
        return None
    except json.JSONDecodeError as e:
        logger.error(f"Error decoding JSON response: {e}")
        return None


def update_venue_metadata(conn, venue_code: str, metadata_key: str, metadata: Dict[str, Any]) -> bool:
    """
    Update venue metadata in the database.
    
    Args:
        conn: Database connection
        venue_code: Venue code (e.g., 'KALSHI')
        metadata_key: Key to store in api_metadata (e.g., 'tags_by_categories')
        metadata: Metadata dict to store
    
    Returns:
        True if successful
    """
    cursor = conn.cursor()
    
    try:
        # Update the venue with metadata (merge with existing)
        cursor.execute("""
            UPDATE venues
            SET 
                api_metadata = COALESCE(api_metadata, '{}'::jsonb) || %s::jsonb,
                updated_at = NOW()
            WHERE venue_code = %s
        """, (json.dumps({metadata_key: metadata}), venue_code))
        
        if cursor.rowcount == 0:
            logger.warning(f"Venue '{venue_code}' not found in database")
            return False
        
        conn.commit()
        logger.info(f"Updated {metadata_key} for venue: {venue_code}")
        return True
        
    except Exception as e:
        logger.error(f"Error updating venue metadata: {e}")
        conn.rollback()
        return False
    finally:
        cursor.close()


def main():
    """Main function to fetch and store tags_by_categories data."""
    logger.info("Starting Kalshi tags_by_categories sync...")
    
    # Fetch data from API
    data = fetch_tags_by_categories()
    if not data:
        logger.error("Failed to fetch tags_by_categories data")
        return
    
    # Store in database
    conn = get_db_connection()
    try:
        # Add timestamp to metadata
        metadata = {
            "tags_by_categories": data.get("tags_by_categories", {}),
            "fetched_at": datetime.utcnow().isoformat(),
            "api_endpoint": f"{KALSHI_BASE_URL}{TAGS_BY_CATEGORIES_ENDPOINT}",
        }
        
        success = update_venue_metadata(conn, "KALSHI", "tags_by_categories", metadata)
        
        if success:
            # Log summary
            tags_data = data.get("tags_by_categories", {})
            category_count = len(tags_data)
            total_tags = sum(len(tags) if tags else 0 for tags in tags_data.values())
            logger.info(f"Successfully stored {category_count} categories with {total_tags} total tags")
            
            # Log sports tags
            sports_tags = tags_data.get("Sports", [])
            if sports_tags:
                logger.info(f"Sports tags: {', '.join(sports_tags[:10])}...")
        else:
            logger.error("Failed to update venue metadata")
            
    except Exception as e:
        logger.error(f"Error in main: {e}", exc_info=True)
    finally:
        conn.close()


if __name__ == "__main__":
    main()

