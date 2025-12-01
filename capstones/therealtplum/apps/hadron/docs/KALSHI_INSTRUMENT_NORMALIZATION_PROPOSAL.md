# Kalshi Instrument Normalization Proposal

## Problem Statement

Kalshi has millions of instruments with cryptic ticker names like:
- `KXNBAGAME-25NOV29TORCHA` → "NBA Game: Toronto at Charlotte, Nov 29, 2025"
- `KXNHLSPREAD-25NOV30WSHNYI-WSH1` → "NHL Spread: Washington vs NY Islanders, Nov 30, 2025"
- `KXMVESPORTSMULTIGAMEEXTENDED-S20250FF9B726EE8-1798A66A616` → Complex multi-game event

**Current Issues:**
1. Auto-created instruments have unhelpful names: `"Kalshi Market: {ticker}"`
2. Tickers are not human-readable
3. No metadata about market type (totals, spread, moneyline, parlay)
4. No relationship tracking (e.g., all markets for the same NBA game)
5. Need to scale to millions of instruments

## Solution Architecture

### Two-Path Approach

#### **Slow-Path (Python ETL) - Batch Normalization**
- **Purpose**: Bulk fetch, parse, and normalize all Kalshi markets
- **Frequency**: Daily or on-demand
- **Scale**: Handles millions of instruments efficiently
- **Components**:
  1. **Kalshi REST API Client**: Fetch all markets with pagination
  2. **Ticker Parser**: Parse Kalshi ticker patterns into structured metadata
  3. **Name Generator**: Create human-readable names from parsed metadata
  4. **Database Upsert**: Update `instruments` table with normalized data

#### **Fast-Path (Hadron Rust) - Real-Time Fallback**
- **Purpose**: Handle new markets seen in WebSocket stream before ETL runs
- **Behavior**: Create minimal instrument, mark for enrichment
- **Enrichment**: ETL will pick up and normalize on next run

### Database Schema Enhancements

#### Option 1: Use Existing `external_ref` JSONB Field
```sql
-- Store parsed metadata in external_ref
external_ref = {
  "kalshi_ticker": "KXNBAGAME-25NOV29TORCHA",
  "kalshi_market_id": "12345",
  "parsed": {
    "event_type": "nba_game",
    "date": "2025-11-29",
    "teams": ["TOR", "CHA"],
    "market_type": "moneyline",  // or "spread", "totals", "parlay"
    "line": null,  // for spreads/totals
    "category": "sports"
  },
  "display_name": "NBA: Toronto at Charlotte, Nov 29, 2025 (Moneyline)"
}
```

#### Option 2: Add `display_name` Column (Recommended)
```sql
ALTER TABLE instruments ADD COLUMN display_name TEXT;

-- Index for search
CREATE INDEX instruments_display_name_idx ON instruments (display_name);
```

**Recommendation**: Use both - `display_name` for fast queries, `external_ref` for rich metadata.

### Ticker Parser Design

#### Pattern Recognition
Kalshi tickers follow patterns:
- `KX{SPORT}{MARKET_TYPE}-{DATE}{TEAMS}-{SUFFIX}`
- `KX{EVENT_TYPE}-{IDENTIFIER}`

#### Parser Implementation
```python
def parse_kalshi_ticker(ticker: str) -> dict:
    """
    Parse Kalshi ticker into structured metadata.
    
    Examples:
    - KXNBAGAME-25NOV29TORCHA → {
        "sport": "NBA",
        "event_type": "game",
        "date": "2025-11-29",
        "teams": ["TOR", "CHA"],
        "market_type": "moneyline"
      }
    - KXNHLSPREAD-25NOV30WSHNYI-WSH1 → {
        "sport": "NHL",
        "event_type": "spread",
        "date": "2025-11-30",
        "teams": ["WSH", "NYI"],
        "market_type": "spread",
        "line": "WSH1"  # Washington -1
      }
    """
    # Pattern matching logic
    # Return structured dict
```

#### Name Generator
```python
def generate_display_name(parsed: dict, market_data: dict) -> str:
    """
    Generate human-readable name from parsed metadata.
    
    Examples:
    - "NBA: Toronto at Charlotte, Nov 29, 2025 (Moneyline)"
    - "NHL: Washington -1.0 vs NY Islanders, Nov 30, 2025 (Spread)"
    - "Election: Harris wins 2024 (Yes/No)"
    """
    # Use parsed metadata + Kalshi API market_data
    # Return formatted string
```

### Python ETL Implementation

#### New Module: `etl/kalshi_instruments.py`

```python
"""
Kalshi Instruments ETL

Fetches all Kalshi markets via REST API, parses tickers,
generates human-readable names, and upserts to instruments table.
"""

import requests
import psycopg2
from typing import Dict, List, Optional
import logging

log = logging.getLogger(__name__)

# Kalshi REST API endpoints
KALSHI_API_BASE = "https://api.elections.kalshi.com/trade-api/v2"
MARKETS_ENDPOINT = f"{KALSHI_API_BASE}/markets"

def fetch_all_markets(api_key: str, private_key_path: str) -> List[Dict]:
    """
    Fetch all Kalshi markets with pagination.
    
    Returns list of market objects from Kalshi API.
    """
    # Implement pagination
    # Handle rate limiting
    # Return all markets
    pass

def parse_ticker(ticker: str) -> Dict:
    """
    Parse Kalshi ticker into structured metadata.
    """
    # Pattern matching logic
    pass

def generate_display_name(parsed: Dict, market_data: Dict) -> str:
    """
    Generate human-readable display name.
    """
    # Use parsed + market_data
    pass

def upsert_instrument(cur, market: Dict, parsed: Dict, display_name: str):
    """
    Upsert instrument with normalized data.
    
    Updates:
    - name: display_name
    - external_ref: full metadata
    - display_name: human-readable name (if column exists)
    """
    pass

def run():
    """
    Main ETL function.
    
    1. Fetch all markets from Kalshi API
    2. Parse each ticker
    3. Generate display names
    4. Upsert to instruments table
    """
    pass
```

### Hadron Fast-Path Updates

#### Update `src/normalize/kalshi.rs`

```rust
// When creating new instrument in fast-path:
let row = sqlx::query_as::<_, (i64,)>(
    r#"
    INSERT INTO instruments (ticker, name, asset_class, primary_source, status, external_ref, created_at, updated_at)
    VALUES ($1, $2, 'other', 'kalshi', 'active', $3, NOW(), NOW())
    ON CONFLICT (ticker, asset_class, primary_source) DO UPDATE SET status = 'active', updated_at = NOW()
    RETURNING id
    "#,
)
.bind(market_ticker)
.bind(format!("Kalshi Market: {}", market_ticker)) // Temporary, ETL will update
.bind(serde_json::json!({
    "kalshi_ticker": market_ticker,
    "needs_enrichment": true, // Flag for ETL
    "created_via": "hadron_realtime"
}))
.fetch_one(&self.db_pool)
.await?;
```

### Implementation Phases

#### Phase 1: Ticker Parser (1-2 days)
- [ ] Research Kalshi ticker patterns
- [ ] Implement parser for common patterns (sports, elections, etc.)
- [ ] Unit tests for various ticker formats
- [ ] Handle edge cases and unknown patterns

#### Phase 2: Python ETL (2-3 days)
- [ ] Implement Kalshi REST API client with RSA-PSS auth
- [ ] Implement pagination and rate limiting
- [ ] Integrate ticker parser
- [ ] Implement name generator
- [ ] Database upsert logic
- [ ] Add to ETL schedule

#### Phase 3: Database Schema (1 day)
- [ ] Add `display_name` column (if not exists)
- [ ] Create indexes
- [ ] Migration script

#### Phase 4: Hadron Fast-Path (1 day)
- [ ] Update instrument creation to set `needs_enrichment` flag
- [ ] Ensure ETL picks up flagged instruments

#### Phase 5: API & UI Updates (1-2 days)
- [ ] Update Rust API to return `display_name` in responses
- [ ] Update macOS app to use `display_name`
- [ ] Update web frontend to use `display_name`

### Scalability Considerations

1. **Pagination**: Kalshi API supports pagination - fetch in batches
2. **Rate Limiting**: Respect Kalshi API rate limits (check docs)
3. **Incremental Updates**: Only update instruments that changed (use `source_payload_hash`)
4. **Caching**: Cache parsed ticker patterns to avoid re-parsing
5. **Parallel Processing**: Process markets in parallel batches (with rate limit awareness)

### Example Output

**Before:**
```json
{
  "ticker": "KXNBAGAME-25NOV29TORCHA",
  "name": "Kalshi Market: KXNBAGAME-25NOV29TORCHA"
}
```

**After:**
```json
{
  "ticker": "KXNBAGAME-25NOV29TORCHA",
  "name": "NBA: Toronto at Charlotte, Nov 29, 2025 (Moneyline)",
  "display_name": "NBA: Toronto at Charlotte, Nov 29, 2025 (Moneyline)",
  "external_ref": {
    "kalshi_ticker": "KXNBAGAME-25NOV29TORCHA",
    "parsed": {
      "sport": "NBA",
      "event_type": "game",
      "date": "2025-11-29",
      "teams": ["TOR", "CHA"],
      "market_type": "moneyline"
    },
    "category": "sports"
  }
}
```

## Questions to Resolve

1. **Kalshi API Documentation**: Need to verify:
   - REST endpoint for fetching all markets
   - Pagination parameters
   - Rate limits
   - Authentication method (RSA-PSS same as WebSocket?)

2. **Ticker Pattern Coverage**: 
   - How many distinct patterns exist?
   - Are patterns documented by Kalshi?
   - Do we need to reverse-engineer from examples?

3. **Market Relationships**:
   - Should we track parent events? (e.g., all markets for one NBA game)
   - New table `kalshi_event_groups`?

4. **Performance**:
   - How long to process 1M+ instruments?
   - Should we prioritize certain categories?

## Recommendation

**Start with Phase 1 (Ticker Parser)** to validate the approach with a small sample of instruments, then proceed with ETL implementation. This allows us to:
1. Test pattern recognition accuracy
2. Validate name generation quality
3. Get user feedback before full implementation


