# Kalshi Ticker Parser - Phase 1 Complete

## Summary

Phase 1 of the Kalshi instrument normalization project is complete. The ticker parser successfully parses Kalshi market tickers into structured metadata for human-readable display names.

## Key Findings from Kalshi API Documentation

Based on the [Kalshi API documentation](https://docs.kalshi.com/api-reference/), we discovered:

1. **Sports Filtering Endpoint**: `/search/filters_by_sport`
   - Returns `filters_by_sports` mapping sports to their filter details (scopes and competitions)
   - Provides `sport_ordering` for display purposes
   - This could be used in Phase 2 to enrich team/competition metadata

2. **Series Categories Endpoint**: `/search/tags_by_categories`
   - Returns tags organized by series categories
   - Useful for filtering and search functionality

3. **Market Structure**: Kalshi markets are organized as:
   - **Series** → Templates for recurring events
   - **Events** → Real-world occurrences (e.g., NBA game, election)
   - **Markets** → Specific binary outcomes within events (e.g., "Will Team X win?")

## Ticker Format Discoveries

### Sports Game Tickers
- **Format**: `KX{LEAGUE}GAME-{DATE}{TEAM1}{TEAM2}[-{OUTCOME}]`
- **Date Format**: `YYMMMDD` (7 characters: `25NOV29` = Nov 29, 2025)
- **Examples**:
  - `KXNBAGAME-25NOV29TORCHA` → NBA game, Nov 29, 2025, Toronto at Charlotte
  - `KXNBAGAME-25NOV29TORCHA-TOR` → Same game, Toronto wins (outcome market)
  - `KXALEAGUEGAME-25DEC05AUCWPH-AUC` → A-League, Dec 5, 2025, Auckland vs Wellington Phoenix, Auckland wins

### Key Bug Fixed
- **Issue**: Date was being parsed as 8-9 characters instead of 7
- **Root Cause**: Assumed `YYMMMDD` was 8 chars (YY + MMM + DD = 2+3+2 = 7)
- **Fix**: Changed date extraction from `remaining[:8]` to `remaining[:7]`
- **Impact**: Team codes were being split incorrectly (e.g., `TORCHA` → `RC/HA` instead of `TOR/CHA`)

## Parser Capabilities

The parser now successfully handles:

1. **Sports Games** (NBA, NHL, A-League, etc.)
   - Extracts league, date, teams, and market type
   - Handles outcome markets (moneyline, spread, tie)

2. **Elections**
   - Primaries: `KX2028DRUN-28-AOC`
   - Governors: `GOVPARTYAL-26-D`
   - Chamber Control: `CONTROLH-2026-D`

3. **Corporate Events**
   - Stock splits: `APPLEFOLD-25DEC31`
   - Market events: `APPLEUS-29DEC31`

4. **Economic Indicators**
   - Fed rates: `FED-25DEC-T3.75`
   - Rate hikes: `FEDHIKE-25DEC31`

5. **Entertainment**
   - Songs: `KX1SONG-DRAKE-DEC2725`
   - Genres: `BEYONCEGENRE-30-AFA`

## Test Results

```
KXNBAGAME-25NOV29TORCHA
  → {'category': 'sports', 'sport': 'NBA', 'event_type': 'game', 
     'date': '2025-11-29', 'date_display': 'Nov 29, 2025', 
     'teams': ['Toronto', 'Charlotte'], 'team_codes': ['TOR', 'CHA'], 
     'market_type': 'game', 'parsed': True}

KXALEAGUEGAME-25DEC05AUCWPH-AUC
  → {'category': 'sports', 'sport': 'A-League', 'event_type': 'game', 
     'date': '2025-12-05', 'date_display': 'Dec 05, 2025', 
     'teams': ['Auckland', 'Wellington Phoenix'], 'team_codes': ['AUC', 'WPH'], 
     'market_type': 'moneyline', 'outcome': 'AUC', 'outcome_display': 'Auckland', 
     'parsed': True}
```

## Next Steps for Phase 2

1. **Use Kalshi REST API** to fetch market metadata:
   - `/markets` endpoint for market details
   - `/events` endpoint for event information
   - `/search/filters_by_sport` for sports metadata

2. **Enrich parsed data** with API responses:
   - Use API `title`, `subtitle`, `yes_sub_title`, `no_sub_title` fields
   - Cross-reference with parsed ticker data for validation

3. **Handle edge cases**:
   - Markets with non-standard ticker formats
   - Multivariate event collections
   - Scalar markets (non-binary)

4. **Expand team abbreviations**:
   - Use `/search/filters_by_sport` to get competition/scope data
   - Build comprehensive team code mapping

## Files Created

- `apps/python-etl/etl/kalshi_ticker_parser.py` - Main parser module
- `apps/python-etl/etl/kalshi_ticker_parser_test.py` - Unit test framework
- `apps/hadron/docs/KALSHI_INSTRUMENT_NORMALIZATION_PROPOSAL.md` - Original proposal
- `apps/hadron/docs/KALSHI_TICKER_PARSER_PHASE1_COMPLETE.md` - This document

## Known Limitations

1. **Team Code Dictionary**: Currently limited to common teams. Will expand in Phase 2 using Kalshi API data.

2. **Pattern Coverage**: Some ticker patterns may not be covered yet. Will refine as we encounter more examples.

3. **Market Type Detection**: Currently uses heuristics. Phase 2 will use API metadata for accurate market type detection.

4. **Date Format Variations**: Currently handles `YYMMMDD` format. May need to handle other formats as we encounter them.

## References

- [Kalshi API Documentation](https://docs.kalshi.com/api-reference/)
- [Get Filters for Sports](https://docs.kalshi.com/api-reference/search/get-filters-for-sports)
- [Get Tags for Series Categories](https://docs.kalshi.com/api-reference/search/get-tags-for-series-categories)
- [Get Markets](https://docs.kalshi.com/api-reference/market/get-markets)
- [Get Events](https://docs.kalshi.com/api-reference/events/get-events)


