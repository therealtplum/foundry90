"""
Refresh Kalshi account data for a user and store in database.

This can be called periodically or on-demand to update account data.
"""

import os
import sys
import json
import logging
import psycopg2
from datetime import datetime, timezone
from dotenv import load_dotenv
from etl.kalshi_user_account import fetch_user_account_data, get_user_credentials

# Load .env file if it exists
load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

logging.basicConfig(
    level=logging.INFO,
    format="[kalshi_refresh_account] %(message)s",
)
log = logging.getLogger(__name__)


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def store_account_data(user_id: str, account_data: dict):
    """Store account data in database for fast retrieval."""
    conn = get_conn()
    cur = conn.cursor()
    
    try:
        # Create table if it doesn't exist
        cur.execute("""
            CREATE TABLE IF NOT EXISTS kalshi_account_cache (
                user_id TEXT PRIMARY KEY,
                balance_data JSONB NOT NULL,
                positions_data JSONB NOT NULL,
                fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
        """)
        
        # Upsert account data
        cur.execute("""
            INSERT INTO kalshi_account_cache (user_id, balance_data, positions_data, fetched_at)
            VALUES (%s, %s, %s, NOW())
            ON CONFLICT (user_id)
            DO UPDATE SET
                balance_data = EXCLUDED.balance_data,
                positions_data = EXCLUDED.positions_data,
                fetched_at = EXCLUDED.fetched_at,
                updated_at = NOW()
        """, (
            user_id,
            json.dumps(account_data.get("balance", {})),
            json.dumps(account_data.get("positions", [])),
        ))
        
        conn.commit()
        log.info(f"Stored account data for user: {user_id}")
    except Exception as e:
        log.error(f"Error storing account data: {e}")
        conn.rollback()
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    # Support both user_id from args or from env vars for local testing
    if len(sys.argv) >= 2:
        user_id = sys.argv[1]
    else:
        # Try to get from env var (for local testing)
        user_id = os.getenv("KALSHI_USER_ID", "default")
    
    # For local testing, allow using env vars directly instead of stored credentials
    use_env_creds = os.getenv("KALSHI_USE_ENV_CREDS", "false").lower() == "true"
    
    try:
        if use_env_creds:
            # Use credentials directly from env vars (for local testing)
            api_key = os.getenv("KALSHI_API_KEY_ID")
            api_secret = os.getenv("KALSHI_API_SECRET")
            
            # Also check for file-based private key (for multi-line keys)
            if not api_secret:
                key_file = os.getenv("KALSHI_API_SECRET_FILE")
                if key_file:
                    # Try multiple locations
                    possible_paths = []
                    
                    # If it's a relative path, try different locations
                    if not os.path.isabs(key_file):
                        # 1. Current directory
                        possible_paths.append(key_file)
                        # 2. /app (where docker volume mounts it)
                        possible_paths.append(f"/app/{os.path.basename(key_file)}")
                        # 3. /app with full relative path
                        possible_paths.append(f"/app/{key_file}")
                        # 4. Project root (where .env usually is)
                        project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
                        possible_paths.append(os.path.join(project_root, key_file))
                    else:
                        possible_paths.append(key_file)
                    
                    # Try each path
                    for path in possible_paths:
                        if os.path.exists(path):
                            with open(path, 'r') as f:
                                api_secret = f.read().strip()
                            log.info(f"Loaded private key from: {path}")
                            break
                    else:
                        log.error(f"Private key file not found in any of: {possible_paths}")
            
            if not api_key or not api_secret:
                print(json.dumps({"error": "KALSHI_API_KEY_ID and KALSHI_API_SECRET (or KALSHI_API_SECRET_FILE) must be set"}))
                sys.exit(1)
            
            from etl.kalshi_user_account import KalshiAuthenticatedClient
            
            client = KalshiAuthenticatedClient(api_key, api_secret)
            balance = client.get_balance()
            positions = client.get_positions()
            account = client.get_user_account()
            
            # Transform balance to match Rust API structure
            # Kalshi returns: {"balance": 30624, "portfolio_value": 152, "updated_ts": ...}
            # Rust expects: {"balance": Decimal, "currency": "USD", "available_balance": Decimal, "pending_withdrawals": Decimal}
            balance_data = {}
            if balance:
                # Convert cents to dollars (divide by 100)
                balance_cents = balance.get("balance", 0)
                portfolio_value_cents = balance.get("portfolio_value", 0)
                
                balance_data = {
                    "balance": balance_cents / 100.0,  # Convert cents to dollars
                    "currency": "USD",
                    "available_balance": balance_cents / 100.0,  # Assume same as balance for now
                    "pending_withdrawals": 0.0,
                }
            
            # Transform positions to match Rust API structure
            positions_data = []
            if positions and isinstance(positions, dict) and "market_positions" in positions:
                for pos in positions.get("market_positions", []):
                    # Map Kalshi position to our structure
                    positions_data.append({
                        "ticker": pos.get("ticker", ""),
                        "position": pos.get("position", 0),
                        "average_price": 0.0,  # Not provided by Kalshi API
                        "current_price": 0.0,  # Not provided by Kalshi API
                        "unrealized_pnl": pos.get("realized_pnl", 0) / 100.0,  # Convert cents to dollars
                    })
            
            account_data = {
                "balance": balance_data,
                "positions": positions_data,
                "fetched_at": None,
            }
        else:
            # Use stored credentials from database
            credentials = get_user_credentials(user_id)
            if not credentials:
                print(json.dumps({"error": "No credentials found for user"}))
                sys.exit(1)
            
            # Fetch account data
            account_data = fetch_user_account_data(user_id)
            if not account_data:
                print(json.dumps({"error": "Failed to fetch account data"}))
                sys.exit(1)
        
        # Store in database
        store_account_data(user_id, account_data)
        
        # Return the data
        print(json.dumps(account_data, default=str))
    except Exception as e:
        log.exception(f"Error: {e}")
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

