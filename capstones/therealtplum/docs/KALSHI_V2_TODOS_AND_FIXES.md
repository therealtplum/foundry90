# Kalshi V2 Integration: TODOs, Fixes, and Testing

## Summary of Changes (Since Last Commit)

This session focused on optimizing Kalshi instrument fetching by leveraging two new API endpoints:
1. `/search/filters_by_sport` - Provides sports, competitions, and scopes structure
2. `/search/tags_by_categories` - Provides tags organized by 16 categories

### Files Created
- `apps/python-etl/etl/kalshi_filters_by_sport.py` - Syncs filters_by_sport data
- `apps/python-etl/etl/kalshi_tags_by_categories.py` - Syncs tags_by_categories data
- `apps/python-etl/etl/kalshi_instruments_optimized.py` - Optimized fetching using categories
- `apps/python-etl/etl/kalshi_test_api_params.py` - Test script for API parameters
- `docs/KALSHI_API_PARAMETERS.md` - API parameters reference
- `docs/KALSHI_FILTERS_BY_SPORT.md` - filters_by_sport integration docs
- `docs/KALSHI_OPTIMIZED_FETCHING.md` - Optimized fetching strategy docs

### Files Modified
- `apps/python-etl/etl/kalshi_instruments.py` - Added support for optimized fetching
- `services/db/schema_sports_teams_venue_codes.sql` - Added `api_metadata` JSONB column to venues table
- `Makefile` - Added `kalshi-sync-filters` and `kalshi-sync-tags` targets

## Critical Fixes Needed

### 🔴 HIGH PRIORITY

1. **API Parameter Filtering Verification**
   - **Issue**: Testing shows API accepts `category` and `search` parameters but may not filter results without authentication
   - **Impact**: Optimized fetching may not work as expected
   - **Action Required**:
     - Test with authenticated Kalshi API requests
     - Verify if filtering works with auth tokens
     - If not, implement client-side filtering using stored filters/tags data
   - **Files**: `kalshi_instruments_optimized.py`, `kalshi_test_api_params.py`

2. **Database Connection Handling**
   - **Issue**: Scripts use `localhost:5433` for local execution but `db:5432` in Docker
   - **Status**: Currently handled via `DATABASE_URL` env var
   - **Action Required**: Ensure consistent connection handling across all scripts
   - **Files**: All ETL scripts

### 🟡 MEDIUM PRIORITY

3. **Optimized Fetching Implementation**
   - **Issue**: `fetch_all_markets_optimized()` needs to be tested with real API calls
   - **Action Required**:
     - Test with authenticated requests
     - Verify category filtering works
     - Implement fallback to client-side filtering if needed
   - **Files**: `kalshi_instruments_optimized.py`

4. **Error Handling**
   - **Issue**: Need better error handling for API failures, rate limiting
   - **Action Required**: Add retry logic, exponential backoff, rate limit detection
   - **Files**: All Kalshi API scripts

## TODOs

### Immediate (Next Session)

1. **Test API Filtering with Authentication**
   - [ ] Get Kalshi API credentials
   - [ ] Test `category` parameter with authenticated requests
   - [ ] Test `search` parameter with authenticated requests
   - [ ] Verify if filtering works server-side or needs client-side implementation
   - [ ] Update `kalshi_instruments_optimized.py` based on findings

2. **Implement Client-Side Filtering (If Needed)**
   - [ ] Parse `filters_by_sport` data to extract sports/competitions
   - [ ] Parse `tags_by_categories` data to extract categories
   - [ ] Filter fetched markets client-side based on stored metadata
   - [ ] Update optimized fetching to use client-side filtering if API doesn't filter

3. **Integration Testing**
   - [ ] Test `make kalshi-sync-filters` end-to-end
   - [ ] Test `make kalshi-sync-tags` end-to-end
   - [ ] Test `make kalshi-fetch-instruments` with optimized fetching
   - [ ] Compare results with unoptimized fetching
   - [ ] Measure performance improvement

### Short Term (Next Week)

4. **Production Readiness**
   - [ ] Add logging/metrics for API call counts
   - [ ] Add monitoring for sync failures
   - [ ] Schedule periodic syncs (daily/weekly) for filters and tags
   - [ ] Add alerts for sync failures

5. **Documentation**
   - [ ] Update main Kalshi integration docs with V2 changes
   - [ ] Add examples of using optimized fetching
   - [ ] Document authentication requirements (if any)

6. **Code Cleanup**
   - [ ] Remove or update `kalshi_test_api_params.py` based on findings
   - [ ] Consolidate duplicate code between optimized and standard fetching
   - [ ] Add type hints where missing

### Medium Term (Next Month)

7. **Advanced Filtering**
   - [ ] Support filtering by specific sports (e.g., "Basketball", "Football")
   - [ ] Support filtering by competitions (e.g., "NBA", "NFL")
   - [ ] Support filtering by tags (e.g., "NFL", "UFC")
   - [ ] Build query builder for complex filters

8. **Performance Optimization**
   - [ ] Implement parallel fetching for multiple categories
   - [ ] Add caching for filters/tags data
   - [ ] Optimize database queries for metadata retrieval

9. **Monitoring and Analytics**
   - [ ] Track API call counts per category
   - [ ] Track market counts per category
   - [ ] Build dashboard for sync status
   - [ ] Alert on unusual patterns (e.g., sudden drop in markets)

## Further Testing/Expansion

### Testing Checklist

- [ ] **Unit Tests**
  - [ ] Test `fetch_filters_by_sport()` function
  - [ ] Test `fetch_tags_by_categories()` function
  - [ ] Test `get_filters_from_db()` function
  - [ ] Test `get_tags_from_db()` function
  - [ ] Test `fetch_markets_with_params()` function
  - [ ] Test `fetch_markets_by_category()` function

- [ ] **Integration Tests**
  - [ ] Test full sync workflow (filters → tags → instruments)
  - [ ] Test error recovery (API failures, DB failures)
  - [ ] Test rate limiting handling
  - [ ] Test concurrent syncs (should fail gracefully)

- [ ] **Performance Tests**
  - [ ] Measure time saved with optimized fetching
  - [ ] Measure API call reduction
  - [ ] Measure database query performance
  - [ ] Load test with large datasets

- [ ] **Edge Cases**
  - [ ] Empty filters/tags data
  - [ ] Malformed API responses
  - [ ] Network timeouts
  - [ ] Database connection failures
  - [ ] Missing venue records

### Expansion Opportunities

1. **Additional API Endpoints**
   - Explore other Kalshi search endpoints
   - Look for series/event filtering options
   - Check for market metadata endpoints

2. **Smart Fetching Strategies**
   - Prioritize categories based on user interest
   - Incremental updates (only fetch new/changed markets)
   - Differential sync (compare with last sync)

3. **Integration with Sports Teams**
   - Use `sports_teams` table to filter markets
   - Match Kalshi markets to sports teams
   - Build team-specific market views

4. **Multi-Venue Support**
   - Apply similar optimization to other venues (Polymarket, CME, etc.)
   - Build generic filtering framework
   - Cross-venue market comparison

## Known Issues

1. **API Parameter Filtering**
   - Status: Unverified
   - Impact: High
   - Workaround: Client-side filtering if needed

2. **Database Connection**
   - Status: Working but inconsistent
   - Impact: Low
   - Workaround: Use `DATABASE_URL` env var

3. **Error Handling**
   - Status: Basic
   - Impact: Medium
   - Workaround: Manual monitoring

## Performance Expectations

### Before Optimization
- API Calls: ~500-1000+ (blind pagination)
- Time: Hours
- Markets: All markets (500,000+)

### After Optimization (Expected)
- API Calls: ~16-20 (one per category)
- Time: Minutes
- Markets: Only needed categories
- Reduction: 80-90% fewer API calls

### Actual Performance
- **TBD**: Needs testing with authenticated requests

## Next Steps

1. **Immediate**: Test API filtering with authentication
2. **Short Term**: Implement client-side filtering if needed
3. **Medium Term**: Production deployment and monitoring
4. **Long Term**: Advanced features and multi-venue support

## Related Documentation

- `docs/KALSHI_API_PARAMETERS.md` - API parameters reference
- `docs/KALSHI_FILTERS_BY_SPORT.md` - filters_by_sport integration
- `docs/KALSHI_OPTIMIZED_FETCHING.md` - Optimized fetching strategy
- `docs/kalshi_integration.md` - Main Kalshi integration docs

