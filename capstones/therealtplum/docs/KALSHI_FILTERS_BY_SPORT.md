# Kalshi filters_by_sport Integration

## Overview

The `filters_by_sport` endpoint provides Kalshi's available sports, competitions, and scopes. This data is fetched and stored in the `venues` table for efficient querying and UI building.

**API Endpoint:** https://api.elections.kalshi.com/trade-api/v2/search/filters_by_sport  
**Authentication:** None required (public endpoint)  
**Update Frequency:** Recommended daily or on-demand

## Implementation

### Script
- **Location:** `apps/python-etl/etl/kalshi_filters_by_sport.py`
- **Purpose:** Fetch and store Kalshi's filters_by_sport data

### Database Storage
- **Table:** `venues`
- **Column:** `api_metadata` (JSONB)
- **Structure:**
  ```json
  {
    "filters_by_sport": {
      "filters_by_sports": {
        "Basketball": {
          "competitions": {
            "Pro Basketball (M)": {
              "scopes": ["Games", "Futures", "Win totals", ...]
            },
            "College Basketball (M)": {
              "scopes": ["Games", "Futures", "Awards", "Conference"]
            }
          },
          "scopes": ["Games", "Futures", "Awards", ...]
        }
      },
      "sport_ordering": ["All sports", "Football", "Basketball", ...]
    },
    "fetched_at": "2025-12-01T20:51:51.877000",
    "api_endpoint": "https://api.elections.kalshi.com/trade-api/v2/search/filters_by_sport"
  }
  ```

## Usage

### Running the Sync

```bash
# Using Makefile
make kalshi-sync-filters

# Or directly
cd apps/python-etl
DATABASE_URL="postgres://app:app@localhost:5433/fmhub" python -m etl.kalshi_filters_by_sport
```

### Querying the Data

#### Get all sports
```sql
SELECT 
    jsonb_object_keys(
        api_metadata->'filters_by_sport'->'filters_by_sports'
    ) as sport
FROM venues 
WHERE venue_code = 'KALSHI';
```

#### Get sport ordering
```sql
SELECT 
    api_metadata->'filters_by_sport'->'filters_by_sports'->'sport_ordering' as sport_ordering
FROM venues 
WHERE venue_code = 'KALSHI';
```

#### Get competitions for a sport
```sql
SELECT 
    jsonb_pretty(
        api_metadata->'filters_by_sport'->'filters_by_sports'->'Basketball'->'competitions'
    ) as basketball_competitions
FROM venues 
WHERE venue_code = 'KALSHI';
```

#### Get scopes for a competition
```sql
SELECT 
    jsonb_array_elements_text(
        api_metadata->'filters_by_sport'->'filters_by_sports'->'Basketball'->'competitions'->'Pro Basketball (M)'->'scopes'
    ) as scope
FROM venues 
WHERE venue_code = 'KALSHI';
```

## Use Cases

1. **UI Filter Building:** Build dynamic filter dropdowns based on available sports/competitions
2. **Market Type Discovery:** Understand what types of markets Kalshi offers
3. **Search Enhancement:** Use scopes to improve search functionality
4. **Data Validation:** Validate market tickers against known competitions/scopes

## Data Structure

The API returns:
- **Sports:** Top-level categories (Football, Basketball, Hockey, etc.)
- **Competitions:** Sub-categories within sports (Pro Basketball (M), College Basketball (M), etc.)
- **Scopes:** Market types within competitions (Games, Futures, Awards, etc.)
- **Sport Ordering:** Recommended display order for sports

## Integration with Existing Code

This complements existing Kalshi integration:
- `kalshi_instruments.py` - Fetches individual markets
- `kalshi_market_data.py` - Fetches market prices
- `kalshi_ticker_parser.py` - Parses ticker strings

The filters data helps understand the structure of markets before fetching them.

## Scheduled Updates

Consider adding to cron or scheduled tasks:
```bash
# Daily at 2 AM
0 2 * * * cd /path/to/project && make kalshi-sync-filters
```

