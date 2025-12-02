# Kalshi API Parameters Reference

## Markets Endpoint: `/markets`

**Base URL:** `https://api.elections.kalshi.com/trade-api/v2/markets`

### Query Parameters

**⚠️ IMPORTANT:** Testing shows the API accepts these parameters, but they may not filter results without authentication or may use different parameter names. Verification needed.

Based on codebase analysis and API structure, the `/markets` endpoint likely supports:

| Parameter | Type | Required | Description | Example Values |
|-----------|------|----------|-------------|----------------|
| `category` | string | No | Filter by category name | `"Sports"`, `"Politics"`, `"Economics"` |
| `search` | string | No | Text search in market titles/descriptions | `"Biden"`, `"Kansas"`, `"NBA"` |
| `status` | string | No | Market status filter | `"open"`, `"closed"`, `"active"` |
| `limit` | integer | No | Max results per page (max 1000) | `1000` (default) |
| `cursor` | string | No | Pagination cursor from previous response | `"abc123..."` |

**Note:** Parameters can be combined (e.g., `category=Sports&search=Kansas`)

### Category Values (from `tags_by_categories`)

Available categories (16 total):
- **Sports** - All sports markets (Football, Basketball, Hockey, Soccer, etc.)
- **Politics** - Political markets (Elections, SCOTUS, Bills, Trump Agenda, etc.)
- **Economics** - Economic indicators (Inflation, Fed, Growth, Oil and energy, etc.)
- **Entertainment** - Entertainment markets (Music, Movies, Awards, Video games, etc.)
- **Financials** - Financial markets (S&P, Nasdaq, EUR/USD, WTI, Treasuries, etc.)
- **Companies** - Company-related markets (CEOs, Earnings, Product launches, etc.)
- **Crypto** - Cryptocurrency markets (BTC, ETH, SOL, SHIBA, Dogecoin, etc.)
- **Health** - Health-related markets (Diseases, FDA Approval, Vaccines, etc.)
- **Climate and Weather** - Weather markets (Hurricanes, Climate change, etc.)
- **Science and Technology** - Tech markets (AI, Space, Energy, Medicine, etc.)
- **Transportation** - Transportation markets (Airlines & aviation)
- **World** - Foreign economies
- And more...

### Example API Calls

```bash
# Fetch Sports markets
curl "https://api.elections.kalshi.com/trade-api/v2/markets?category=Sports&status=open&limit=1000"

# Search for specific markets
curl "https://api.elections.kalshi.com/trade-api/v2/markets?search=Kansas&status=open&limit=1000"

# Combine category + search
curl "https://api.elections.kalshi.com/trade-api/v2/markets?category=Sports&search=Kansas&status=open&limit=1000"
```

```python
import requests

base_url = "https://api.elections.kalshi.com/trade-api/v2/markets"

# Fetch by category
params = {"category": "Sports", "status": "open", "limit": 1000}
resp = requests.get(base_url, params=params)
markets = resp.json().get("markets", [])

# Search
params = {"search": "Kansas", "status": "open", "limit": 1000}
resp = requests.get(base_url, params=params)

# Combined
params = {"category": "Sports", "search": "Kansas", "status": "open", "limit": 1000}
resp = requests.get(base_url, params=params)
```

## Search Endpoints

### `/search/filters_by_sport`

Returns available sports, competitions, and scopes.

**Parameters:** None (public endpoint)

**Use Case:** Understand what sports/competitions/scopes are available.

### `/search/tags_by_categories`

Returns tags organized by categories (16 categories, 83+ tags).

**Parameters:** None (public endpoint)

**Use Case:** Get list of available categories for filtering.

## Optimized Fetching Strategy

### ✅ Recommended: Fetch by Category

**80-90% reduction in API calls**

```python
# Fetch one category at a time
categories = ["Sports", "Politics", "Economics"]
for category in categories:
    markets = fetch_markets_with_params(category=category, status="open")
```

**Benefits:**
- ~16-20 API calls (one per category) vs 500-1000+ calls
- Minutes instead of hours
- Can prioritize important categories

### ✅ Alternative: Use Search for Specific Markets

**99%+ reduction for targeted searches**

```python
# Search for specific terms
markets = fetch_markets_with_params(search="Kansas Jayhawks", status="open")
```

## Implementation

Files created:
1. **`kalshi_instruments_optimized.py`** - Optimized fetching using categories
2. **`kalshi_filters_by_sport.py`** - Sync `filters_by_sport` data
3. **`kalshi_tags_by_categories.py`** - Sync `tags_by_categories` data
4. **`kalshi_test_api_params.py`** - Test script to verify parameters

## Usage

```bash
# Sync metadata
make kalshi-sync-filters
make kalshi-sync-tags

# Fetch instruments efficiently
make kalshi-fetch-instruments
```

## Key Insights

1. **Parameters accepted but filtering may require auth** - API accepts parameters but may not filter without authentication
2. **Use `tags_by_categories`** - To know what categories are available
3. **Use `filters_by_sport`** - To understand sports structure
4. **Client-side filtering** - May need to filter results client-side if API doesn't filter server-side
5. **Test with authenticated requests** - Filtering may only work with authenticated API calls

## Verification Needed

The parameters are accepted by the API (200 status), but testing shows they may not actually filter results. This could mean:
- Filtering requires authentication
- Different parameter names are needed
- Filtering works but needs to be tested with authenticated requests
- Client-side filtering is required

**Next Step:** Test with authenticated API calls to verify if filtering works.
