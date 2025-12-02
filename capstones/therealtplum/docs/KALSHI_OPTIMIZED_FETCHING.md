# Kalshi Optimized Instrument Fetching

## Problem

The current `kalshi_instruments.py` fetches **ALL** markets blindly:
- Makes thousands of API calls
- Fetches millions of instruments
- Slow and inefficient
- High rate limit risk

## Solution

Use `filters_by_sport` data to make **targeted API calls**:
- Only fetch markets for sports/competitions we care about
- Reduce API calls by 80-90%
- Faster execution
- Lower rate limit risk

## Implementation

### Option 1: Use Optimized Script (Recommended)

```bash
# Use the optimized version directly
cd apps/python-etl
DATABASE_URL="postgres://app:app@localhost:5433/fmhub" python -m etl.kalshi_instruments_optimized
```

### Option 2: Enable in Existing Script

```python
# In kalshi_instruments.py, call with use_filters=True
from kalshi_instruments import fetch_all_markets
fetch_all_markets(use_filters=True)
```

## How It Works

1. **Load filters data** from `venues.api_metadata`
2. **Iterate through sports** in priority order
3. **For each sport/competition**, make targeted API call
4. **Map to API parameters** (category, sport, competition, etc.)

## API Parameter Mapping

The Kalshi `/markets` endpoint likely supports:
- `category` - Sport or competition category
- `status` - Market status (open, closed, etc.)
- `limit` - Results per page (max 1000)
- `cursor` - Pagination cursor

**Note:** The exact parameter names may need testing. The optimized script tries:
- `category` parameter with sport/competition names
- Falls back to unfiltered if category doesn't work

## Example Usage

```python
from kalshi_instruments_optimized import fetch_all_markets_optimized

# Fetch all sports (uses filters data)
fetch_all_markets_optimized()

# Prioritize specific sports first
fetch_all_markets_optimized(prioritize_sports=["Football", "Basketball", "Hockey"])
```

## Benefits

### Before (Blind Fetch)
- Fetches ALL markets: ~500,000+ instruments
- Thousands of API calls
- Takes hours to complete
- High rate limit risk

### After (Optimized)
- Fetches only needed sports: ~50,000-100,000 instruments
- Hundreds of API calls (80-90% reduction)
- Completes in minutes
- Lower rate limit risk

## Testing API Parameters

To verify what parameters Kalshi actually accepts:

```python
import requests

# Test different parameter names
test_params = [
    {"category": "Basketball"},
    {"sport": "Basketball"},
    {"competition": "Pro Basketball (M)"},
    {"series": "NBA"},
]

for params in test_params:
    resp = requests.get("https://api.elections.kalshi.com/trade-api/v2/markets", params=params)
    print(f"{params}: {resp.status_code} - {len(resp.json().get('markets', []))} markets")
```

## Next Steps

1. **Test API parameters** - Verify what Kalshi actually accepts
2. **Update mapping** - Adjust `map_sport_to_category()` based on results
3. **Add to Makefile** - Create `make kalshi-fetch-instruments-optimized`
4. **Schedule updates** - Run optimized fetch on schedule

## Fallback

If filters data is unavailable, the script falls back to the original blind fetch method.

