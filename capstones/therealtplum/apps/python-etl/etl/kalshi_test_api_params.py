#!/usr/bin/env python3
"""
Test script to verify which parameters Kalshi API /markets endpoint accepts.

This helps us understand what filtering options are actually available.
"""

import requests
import json
from typing import Dict, Any

KALSHI_BASE_URL = "https://api.elections.kalshi.com/trade-api/v2"
MARKETS_ENDPOINT = "/markets"


def test_params(params: Dict[str, Any], description: str) -> Dict[str, Any]:
    """
    Test a set of parameters and return results.
    
    Returns:
        Dict with status_code, market_count, and sample response
    """
    url = f"{KALSHI_BASE_URL}{MARKETS_ENDPOINT}"
    
    try:
        resp = requests.get(url, params=params, timeout=10)
        data = resp.json() if resp.status_code == 200 else {}
        markets = data.get("markets", []) or data.get("results", []) or []
        
        return {
            "description": description,
            "params": params,
            "status_code": resp.status_code,
            "market_count": len(markets),
            "has_cursor": "cursor" in data,
            "sample_ticker": markets[0].get("ticker") if markets else None,
        }
    except Exception as e:
        return {
            "description": description,
            "params": params,
            "error": str(e),
        }


def main():
    """Test various parameter combinations."""
    print("Testing Kalshi API /markets endpoint parameters...\n")
    
    test_cases = [
        # Basic tests
        ({"status": "open", "limit": 10}, "Basic: status=open, limit=10"),
        
        # Category tests
        ({"category": "Sports", "status": "open", "limit": 10}, "Category: Sports"),
        ({"category": "Politics", "status": "open", "limit": 10}, "Category: Politics"),
        ({"category": "Economics", "status": "open", "limit": 10}, "Category: Economics"),
        
        # Search tests
        ({"search": "Kansas", "status": "open", "limit": 10}, "Search: Kansas"),
        ({"search": "NBA", "status": "open", "limit": 10}, "Search: NBA"),
        
        # Combined tests (may not work)
        ({"category": "Sports", "search": "Kansas", "status": "open", "limit": 10}, 
         "Combined: category=Sports, search=Kansas"),
        
        # Sport-specific (may not work - all sports use "Sports" category)
        ({"category": "Basketball", "status": "open", "limit": 10}, "Category: Basketball (may not work)"),
        ({"sport": "Basketball", "status": "open", "limit": 10}, "Parameter: sport=Basketball (may not work)"),
    ]
    
    results = []
    for params, description in test_cases:
        result = test_params(params, description)
        results.append(result)
        
        if "error" in result:
            print(f"❌ {description}: ERROR - {result['error']}")
        else:
            status_icon = "✅" if result["status_code"] == 200 else "⚠️"
            print(f"{status_icon} {description}: {result['status_code']} - {result['market_count']} markets")
            if result.get("sample_ticker"):
                print(f"   Sample ticker: {result['sample_ticker']}")
    
    print("\n" + "="*60)
    print("Summary:")
    print("="*60)
    
    working = [r for r in results if r.get("status_code") == 200 and r.get("market_count", 0) > 0]
    print(f"\n✅ Working parameters: {len(working)}/{len(results)}")
    for r in working:
        print(f"   - {r['description']}: {r['market_count']} markets")
    
    print("\n💡 Recommendation:")
    if any("category" in str(r.get("params", {})) for r in working):
        print("   Use 'category' parameter for efficient filtering!")
    if any("search" in str(r.get("params", {})) for r in working):
        print("   Use 'search' parameter for targeted searches!")


if __name__ == "__main__":
    main()

