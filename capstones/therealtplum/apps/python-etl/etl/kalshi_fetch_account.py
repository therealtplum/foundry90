"""
Standalone script to fetch Kalshi account data for a user.

Can be called from the Rust API or run directly.
"""

import os
import sys
import json
import logging
from etl.kalshi_user_account import fetch_user_account_data

logging.basicConfig(
    level=logging.INFO,
    format="[kalshi_fetch_account] %(message)s",
)
log = logging.getLogger(__name__)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "user_id required"}))
        sys.exit(1)
    
    user_id = sys.argv[1]
    
    try:
        account_data = fetch_user_account_data(user_id)
        if account_data:
            print(json.dumps(account_data, default=str))
        else:
            print(json.dumps({"error": "Failed to fetch account data"}))
            sys.exit(1)
    except Exception as e:
        log.exception(f"Error fetching account: {e}")
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

