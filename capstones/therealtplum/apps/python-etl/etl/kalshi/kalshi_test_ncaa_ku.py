"""
Test script: Search for upcoming NCAA basketball games moneyline involving KU (Kansas)

This script:
1. Uses Kalshi REST API to fetch markets
2. Filters for NCAA basketball games
3. Filters for KU/Kansas
4. Filters for moneyline markets
5. Uses the ticker parser to normalize results
6. Displays human-readable output

Usage:
    python -m etl.kalshi_test_ncaa_ku
"""

import os
import sys
import json
import time
import logging
import requests
from typing import List, Dict, Optional
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.backends import default_backend
import base64
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from etl.kalshi.kalshi_ticker_parser import parse_kalshi_ticker

logging.basicConfig(
    level=logging.INFO,
    format="[kalshi_test] %(message)s",
)
log = logging.getLogger(__name__)

# Kalshi API configuration
KALSHI_API_BASE = "https://api.elections.kalshi.com/trade-api/v2"
KALSHI_API_KEY = os.getenv("KALSHI_API_KEY_1") or os.getenv("KALSHI_API_KEY")
KALSHI_PRIVATE_KEY_PATH = os.getenv("KALSHI_PRIVATE_KEY_1_PATH") or os.getenv("KALSHI_PRIVATE_KEY_PATH")

if not KALSHI_API_KEY:
    raise RuntimeError("KALSHI_API_KEY_1 or KALSHI_API_KEY environment variable required")
if not KALSHI_PRIVATE_KEY_PATH:
    raise RuntimeError("KALSHI_PRIVATE_KEY_1_PATH or KALSHI_PRIVATE_KEY_PATH environment variable required")

# Resolve relative paths relative to project root
if not os.path.isabs(KALSHI_PRIVATE_KEY_PATH):
    # Try relative to project root (capstones/therealtplum)
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.."))
    key_path = os.path.join(project_root, KALSHI_PRIVATE_KEY_PATH)
    if os.path.exists(key_path):
        KALSHI_PRIVATE_KEY_PATH = key_path
    else:
        # Try relative to current directory
        key_path = os.path.join(os.getcwd(), KALSHI_PRIVATE_KEY_PATH)
        if os.path.exists(key_path):
            KALSHI_PRIVATE_KEY_PATH = key_path


def load_private_key(path: str):
    """Load RSA private key from PEM file."""
    with open(path, 'r') as f:
        key_data = f.read()
    
    # Try PKCS8 first (standard format)
    try:
        private_key = serialization.load_pem_private_key(
            key_data.encode(),
            password=None,
            backend=default_backend()
        )
    except ValueError:
        # Try PKCS1 format (legacy)
        try:
            from cryptography.hazmat.primitives.serialization import load_pem_private_key
            private_key = load_pem_private_key(
                key_data.encode(),
                password=None,
                backend=default_backend()
            )
        except Exception as e:
            raise ValueError(f"Failed to load private key from {path}: {e}")
    
    return private_key


def generate_kalshi_signature(private_key, timestamp_ms: str, method: str, path: str) -> str:
    """
    Generate RSA-PSS signature for Kalshi API authentication.
    
    Message format: timestamp + method + path
    Example: "1234567890GET/markets"
    """
    message = f"{timestamp_ms}{method}{path}"
    
    # Sign with RSA-PSS
    signature = private_key.sign(
        message.encode('utf-8'),
        padding.PSS(
            mgf=padding.MGF1(hashes.SHA256()),
            salt_length=padding.PSS.MAX_LENGTH
        ),
        hashes.SHA256()
    )
    
    # Base64 encode
    return base64.b64encode(signature).decode('utf-8')


def make_kalshi_request(method: str, path: str, params: Optional[Dict] = None) -> Dict:
    """
    Make authenticated request to Kalshi REST API.
    
    Args:
        method: HTTP method (GET, POST, etc.)
        path: API path (e.g., "/markets")
        params: Query parameters
    
    Returns:
        JSON response as dict
    """
    private_key = load_private_key(KALSHI_PRIVATE_KEY_PATH)
    
    # Generate timestamp (milliseconds since epoch)
    timestamp_ms = str(int(time.time() * 1000))
    
    # Generate signature
    signature = generate_kalshi_signature(private_key, timestamp_ms, method, path)
    
    # Build URL
    url = f"{KALSHI_API_BASE}{path}"
    
    # Build headers
    headers = {
        "KALSHI-ACCESS-KEY": KALSHI_API_KEY,
        "KALSHI-ACCESS-SIGNATURE": signature,
        "KALSHI-ACCESS-TIMESTAMP": timestamp_ms,
        "Content-Type": "application/json",
    }
    
    # Make request
    if method == "GET":
        resp = requests.get(url, headers=headers, params=params, timeout=30)
    else:
        resp = requests.request(method, url, headers=headers, json=params, timeout=30)
    
    resp.raise_for_status()
    return resp.json()


def search_ncaa_ku_moneylines() -> List[Dict]:
    """
    Search for NCAA basketball games moneyline involving KU (Kansas).
    
    Returns list of market dictionaries with parsed ticker data.
    """
    log.info("Fetching markets from Kalshi API...")
    
    all_markets = []
    cursor = None
    page = 1
    max_pages = 5  # Limit to first 5 pages for testing (5000 markets should be enough)
    
    while page <= max_pages:
        log.info(f"Fetching page {page}...")
        
        params = {
            "limit": 1000,  # Max per page
            "status": "open",  # Only open markets
        }
        
        # Try to filter by series_ticker if we know NCAA basketball series
        # This would be more efficient but requires knowing the series ticker
        # For now, we'll fetch and filter client-side
        
        if cursor:
            params["cursor"] = cursor
        
        try:
            response = make_kalshi_request("GET", "/markets", params=params)
            markets = response.get("markets", [])
            cursor = response.get("cursor")
            
            log.info(f"Received {len(markets)} markets on page {page}")
            
            if not markets:
                break
            
            all_markets.extend(markets)
            
            # Check if there are more pages
            if not cursor or len(markets) < 1000:
                break
            
            page += 1
            time.sleep(0.3)  # Rate limiting (reduced for faster testing)
            
        except Exception as e:
            log.error(f"Error fetching markets: {e}")
            break
    
    log.info(f"Total markets fetched: {len(all_markets)}")
    
    # Filter for NCAA basketball games involving KU/Kansas
    log.info("Filtering for NCAA basketball games involving KU/Kansas...")
    
    filtered = []
    for market in all_markets:
        ticker = market.get("ticker", "").upper()
        title = market.get("title", "").upper()
        subtitle = market.get("subtitle", "").upper()
        yes_sub_title = market.get("yes_sub_title", "").upper()
        no_sub_title = market.get("no_sub_title", "").upper()
        event_ticker = market.get("event_ticker", "").upper()
        
        # Check if it's NCAA basketball (not football)
        is_ncaa_basketball = (
            ("NCAA" in ticker or "NCAA" in title or "NCAA" in subtitle or "NCAA" in event_ticker) and
            ("BASKETBALL" in ticker or "BASKETBALL" in title or "BASKETBALL" in subtitle or
             "BASKETBALL" in event_ticker or "NCAAMB" in ticker or "NCAAMBK" in ticker) and
            "FOOTBALL" not in ticker and "FOOTBALL" not in title and "FOOTBALL" not in subtitle and
            "FB" not in ticker  # Exclude FB (football) codes
        )
        
        # Check if it involves KU/Kansas
        involves_ku = (
            "KU" in ticker or "KANSAS" in ticker or
            "KU" in title or "KANSAS" in title or
            "KU" in subtitle or "KANSAS" in subtitle or
            "KU" in yes_sub_title or "KANSAS" in yes_sub_title or
            "KU" in no_sub_title or "KANSAS" in no_sub_title or
            "KU" in event_ticker or "KANSAS" in event_ticker
        )
        
        # Check if it's a moneyline market (game winner, not championship winner)
        # Moneyline markets are typically game-specific, not season-long championships
        is_moneyline = (
            ("MONEYLINE" in ticker or "MONEYLINE" in title or "MONEYLINE" in subtitle) or
            ("WIN" in title and "CHAMPIONSHIP" not in title and "CHAMPION" not in title and
             "SPREAD" not in title and "TOTAL" not in title and "OVER" not in title and "UNDER" not in title) or
            ("GAME" in ticker and "WIN" in title)  # Game winner markets
        )
        
        if is_ncaa and involves_ku and is_moneyline:
            # Parse the ticker
            parsed = parse_kalshi_ticker(market.get("ticker", ""))
            
            market_data = {
                "ticker": market.get("ticker"),
                "event_ticker": market.get("event_ticker"),
                "title": market.get("title"),
                "subtitle": market.get("subtitle"),
                "yes_sub_title": market.get("yes_sub_title"),
                "no_sub_title": market.get("no_sub_title"),
                "status": market.get("status"),
                "open_time": market.get("open_time"),
                "close_time": market.get("close_time"),
                "yes_bid": market.get("yes_bid"),
                "yes_ask": market.get("yes_ask"),
                "last_price": market.get("last_price"),
                "volume": market.get("volume"),
                "parsed": parsed,
            }
            filtered.append(market_data)
    
    log.info(f"Found {len(filtered)} NCAA basketball moneyline markets involving KU/Kansas")
    return filtered


def display_results(markets: List[Dict]):
    """Display results in a human-readable format."""
    if not markets:
        print("\n❌ No NCAA basketball moneyline markets found for KU/Kansas")
        return
    
    print(f"\n✅ Found {len(markets)} NCAA basketball moneyline market(s) involving KU/Kansas:\n")
    
    for i, market in enumerate(markets, 1):
        print(f"{'='*80}")
        print(f"Market {i}: {market['ticker']}")
        print(f"{'='*80}")
        
        # Display API data
        print(f"Event Ticker: {market.get('event_ticker', 'N/A')}")
        print(f"Title: {market.get('title', 'N/A')}")
        print(f"Subtitle: {market.get('subtitle', 'N/A')}")
        print(f"Yes: {market.get('yes_sub_title', 'N/A')}")
        print(f"No: {market.get('no_sub_title', 'N/A')}")
        print(f"Status: {market.get('status', 'N/A')}")
        print(f"Open Time: {market.get('open_time', 'N/A')}")
        print(f"Close Time: {market.get('close_time', 'N/A')}")
        
        if market.get('yes_bid') is not None:
            print(f"Yes Bid: {market['yes_bid']}¢ (${market['yes_bid']/100:.2f})")
        if market.get('yes_ask') is not None:
            print(f"Yes Ask: {market['yes_ask']}¢ (${market['yes_ask']/100:.2f})")
        if market.get('last_price') is not None:
            print(f"Last Price: {market['last_price']}¢ (${market['last_price']/100:.2f})")
        if market.get('volume') is not None:
            print(f"Volume: {market['volume']:,} contracts")
        
        # Display parsed data
        parsed = market.get('parsed', {})
        if parsed.get('parsed'):
            print(f"\n📊 Parsed Ticker Data:")
            print(f"  Category: {parsed.get('category', 'N/A')}")
            if parsed.get('category') == 'sports':
                print(f"  Sport: {parsed.get('sport', 'N/A')}")
                print(f"  Date: {parsed.get('date_display', 'N/A')}")
                print(f"  Teams: {', '.join(parsed.get('teams', []))}")
                print(f"  Team Codes: {', '.join(parsed.get('team_codes', []))}")
                print(f"  Market Type: {parsed.get('market_type', 'N/A')}")
                if parsed.get('outcome'):
                    print(f"  Outcome: {parsed.get('outcome_display', parsed.get('outcome'))}")
        else:
            print(f"\n⚠️  Ticker could not be parsed (format: {market['ticker']})")
        
        print()


def main():
    """Main entry point."""
    try:
        markets = search_ncaa_ku_moneylines()
        display_results(markets)
        
        # Also save to JSON for inspection
        output_file = "ncaa_ku_moneylines.json"
        with open(output_file, 'w') as f:
            json.dump(markets, f, indent=2, default=str)
        print(f"\n💾 Results saved to {output_file}")
        
    except Exception as e:
        log.error(f"Error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()

