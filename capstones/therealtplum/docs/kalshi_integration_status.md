# Kalshi Integration - Status & Lessons Learned

**Date**: November 28, 2025  
**Branch**: `kalshi-integration`  
**Status**: ✅ Functional MVP - Ready for further development

## Overview

This document captures the current state of the Kalshi integration, lessons learned during implementation, known limitations, and future work needed.

## What We Built

### ✅ Completed Features

1. **Python ETL Modules**
   - `kalshi_instruments.py` - Fetches and stores Kalshi market instruments
   - `kalshi_market_data.py` - Fetches current market prices/odds
   - `kalshi_user_account.py` - Handles user authentication and account data fetching
   - `kalshi_rsa_signing.py` - RSA-PSS signature implementation for Kalshi API
   - `kalshi_refresh_account.py` - Script to refresh user account data from Kalshi
   - `kalshi_ticker_utils.py` - Utilities for human-readable ticker display
   - `kalshi_websocket.py` - WebSocket client (placeholder, not fully implemented)

2. **Rust API Endpoints**
   - `GET /kalshi/markets` - List Kalshi markets with filtering/pagination
   - `GET /kalshi/markets/{ticker}` - Get specific market details
   - `GET /kalshi/users/{user_id}/account` - Get user account (balance, positions)
   - `GET /kalshi/users/{user_id}/account/refresh` - Trigger account data refresh

3. **Database Schema**
   - `kalshi_account_cache` - Caches user account data for fast retrieval
   - `kalshi_user_credentials` - Stores encrypted user credentials (schema defined, not fully used)
   - Extended `instruments` table to support Kalshi markets

4. **Mac App (SwiftUI)**
   - Kalshi Markets view with search and filtering
   - Account view showing balance and positions
   - Local configuration support (uses `.env` credentials)
   - Real-time balance display ($306.24 verified working)
   - Positions display (3 positions verified working)

5. **Authentication**
   - RSA-PSS signing implementation matching pythia project
   - Support for `.env` file-based credentials
   - Private key stored in separate file (`.env.kalshi_key`) to avoid docker-compose parsing issues

## Lessons Learned

### 1. RSA-PSS Signing Implementation

**Key Insight**: The signature path must include the full API prefix `/trade-api/v2/`, not just the endpoint path.

**Example**:
- ❌ Wrong: Sign with path `portfolio/balance`
- ✅ Correct: Sign with path `/trade-api/v2/portfolio/balance`

**Reference**: Implemented based on pythia project's Rust implementation in `pythia-venues-kalshi/src/lib.rs`.

### 2. Docker Compose Environment Variables

**Issue**: Multi-line RSA private keys cannot be stored directly in `.env` files due to docker-compose's parser limitations with special characters (`+`, `/`).

**Solution**: Store private key in separate file (`.env.kalshi_key`) and reference via `KALSHI_API_SECRET_FILE` environment variable.

**Pattern**:
```bash
# .env
KALSHI_API_SECRET_FILE=.env.kalshi_key
KALSHI_USE_ENV_CREDS=true
```

### 3. Data Type Mismatches

**Issue**: Rust's `Decimal` type serializes to JSON strings, but Swift `Codable` expected `Double`.

**Solution**: Created custom `DoubleOrString` decoding strategy in Swift models to handle both formats.

**Location**: `KalshiModels.swift` - `DoubleOrString` wrapper type

### 4. Kalshi API Response Format

**Issue**: Kalshi returns monetary values in cents (integers), not dollars.

**Solution**: Transform in Python ETL before storing:
```python
balance_cents = balance.get("balance", 0)
balance_data = {
    "balance": balance_cents / 100.0,  # Convert to dollars
    ...
}
```

### 5. Path Prefix for Signing vs URL Construction

**Critical**: The path used for RSA-PSS signing must include `/trade-api/v2/` prefix, but the actual HTTP URL construction should append paths normally.

**Implementation**:
- Signing: `sign_kalshi_request(method, "portfolio/balance", ...)` → signs `/trade-api/v2/portfolio/balance`
- URL: `f"{base_url}/portfolio/balance"` → `https://api.elections.kalshi.com/trade-api/v2/portfolio/balance`

## Known Limitations & Scalability Concerns

### 🔴 Critical Issues

1. **No Real User Credential Storage**
   - Currently uses hardcoded "default" user ID from `.env`
   - `kalshi_user_credentials` table exists but not fully integrated
   - Mac app bypasses login form for local development
   - **Impact**: Cannot support multiple users in production

2. **Account Refresh Endpoint Calls Docker Compose**
   - Rust API endpoint executes `docker compose run` to call Python script
   - **Impact**: Not scalable, requires docker access from API container, slow

3. **No Background Job for Account Updates**
   - Account data only refreshed on-demand via API call
   - **Impact**: Stale data, manual refresh required

### 🟡 Medium Priority Issues

4. **WebSocket Not Implemented**
   - `kalshi_websocket.py` exists but is placeholder
   - **Impact**: No real-time market data updates

5. **Limited Error Handling**
   - API errors return placeholder data instead of proper error responses
   - **Impact**: Difficult to debug issues

6. **No Rate Limiting**
   - Kalshi API has rate limits, but we don't enforce them
   - **Impact**: Risk of API bans, potential failures

7. **Database Query Performance**
   - No indexes on Kalshi-specific columns
   - **Impact**: Slow queries as data grows

8. **Ticker Display Name Generation**
   - `kalshi_ticker_utils.py` has basic formatting but not comprehensive
   - **Impact**: Some tickers may still be hard to read

### 🟢 Low Priority / Future Enhancements

9. **Parlay Support**
   - Schema exists (`kalshi_parlays` table) but not populated
   - **Impact**: Multi-variant events not properly handled

10. **Market Categorization**
    - Basic categorization exists but could be improved
    - **Impact**: Filtering/search may not be optimal

11. **Position Details**
    - Current positions show basic info, missing average price, PnL details
    - **Impact**: Limited trading insights

## TODOs

### High Priority

- [ ] **Implement proper user credential storage**
  - Complete `kalshi_user_credentials` table integration
  - Add encryption/decryption in Rust API
  - Update Mac app to support multiple users

- [ ] **Refactor account refresh mechanism**
  - Remove docker compose dependency from Rust API
  - Implement direct Python function calls or message queue
  - Consider using background job system (e.g., Celery, sidekiq)

- [ ] **Add background job for account updates**
  - Periodic refresh of account data (every 5-15 minutes)
  - Update `kalshi_account_cache` table automatically

- [ ] **Implement WebSocket streaming**
  - Complete `kalshi_websocket.py` implementation
  - Add Redis pub/sub for real-time updates
  - Update Mac app to consume WebSocket data

### Medium Priority

- [ ] **Add database indexes**
  ```sql
  CREATE INDEX idx_instruments_primary_source ON instruments(primary_source);
  CREATE INDEX idx_instruments_external_ref_ticker ON instruments USING GIN (external_ref jsonb_path_ops);
  CREATE INDEX idx_kalshi_account_cache_user_id ON kalshi_account_cache(user_id);
  ```

- [ ] **Improve error handling**
  - Return proper HTTP error codes from Rust API
  - Add error logging and monitoring
  - Show user-friendly error messages in Mac app

- [ ] **Add rate limiting**
  - Implement rate limiter for Kalshi API calls
  - Add retry logic with exponential backoff
  - Track API usage metrics

- [ ] **Enhance ticker display**
  - Improve `format_ticker_display_name()` function
  - Add more parsing rules for different ticker formats
  - Support event metadata extraction

### Low Priority

- [ ] **Parlay support**
  - Populate `kalshi_parlays` table
  - Add parlay detection logic
  - Display parlays in Mac app

- [ ] **Market categorization improvements**
  - Add ML-based categorization
  - Improve search/filter accuracy
  - Add custom categories

- [ ] **Position details enhancement**
  - Calculate and display average entry price
  - Show unrealized PnL
  - Add position history

- [ ] **Testing**
  - Add unit tests for RSA-PSS signing
  - Add integration tests for API endpoints
  - Add E2E tests for Mac app

## Architecture Decisions

### Why Python for ETL?

- Kalshi Python SDK available (though we implemented our own)
- Easier to iterate on data transformations
- Existing ETL infrastructure in Python

### Why Rust for API?

- Performance for high-throughput market data
- Type safety for financial data
- Existing Rust API infrastructure

### Why SwiftUI for Mac App?

- Native macOS experience
- Easy integration with existing app
- Good performance for real-time updates

## File Structure

```
capstones/therealtplum/
├── apps/
│   ├── python-etl/
│   │   └── etl/
│   │       ├── kalshi_instruments.py
│   │       ├── kalshi_market_data.py
│   │       ├── kalshi_user_account.py
│   │       ├── kalshi_rsa_signing.py
│   │       ├── kalshi_refresh_account.py
│   │       ├── kalshi_ticker_utils.py
│   │       └── kalshi_websocket.py
│   └── rust-api/
│       └── src/
│           ├── kalshi.rs
│           └── main.rs (updated)
├── clients/
│   └── FMHubControl/
│       └── FMHubControl/
│           └── FMHubControl/
│               ├── KalshiMarketsView.swift
│               ├── KalshiAccountView.swift
│               ├── KalshiModels.swift
│               ├── KalshiService.swift
│               └── KalshiLoginView.swift
├── services/
│   └── db/
│       └── schema_kalshi.sql
└── docs/
    ├── kalshi_integration.md
    └── kalshi_integration_status.md (this file)
```

## Environment Variables

Required in `.env`:
```bash
# Kalshi API credentials (for local testing)
KALSHI_API_KEY_ID=your_api_key_id
KALSHI_API_SECRET_FILE=.env.kalshi_key  # Path to private key file
KALSHI_USER_ID=default
KALSHI_USE_ENV_CREDS=true
KALSHI_BASE_URL=https://api.elections.kalshi.com/trade-api/v2
# For demo: https://demo-api.kalshi.co/trade-api/v2
```

## Testing

### Manual Testing Checklist

- [x] Fetch Kalshi markets via API
- [x] Display markets in Mac app
- [x] Fetch user account balance
- [x] Display balance in Mac app ($306.24 verified)
- [x] Fetch user positions
- [x] Display positions in Mac app (3 positions verified)
- [x] Refresh account data
- [ ] Test with multiple users (not implemented)
- [ ] Test WebSocket streaming (not implemented)
- [ ] Test error scenarios

## References

- **Pythia Project**: External reference (path not included for security)
  - RSA-PSS signing implementation: `backend/crates/pythia-venues-kalshi/src/lib.rs`
- **Kalshi API Docs**: https://docs.kalshi.com
- **Kalshi Base URL**: `https://api.elections.kalshi.com/trade-api/v2`
- **Kalshi Demo URL**: `https://demo-api.kalshi.co/trade-api/v2`

## Next Steps

1. **Immediate**: Address critical scalability issues (user storage, refresh mechanism)
2. **Short-term**: Implement WebSocket streaming for real-time data
3. **Medium-term**: Add background jobs, improve error handling
4. **Long-term**: Full trading functionality, advanced analytics

---

**Note**: This integration is functional for single-user local development but requires significant work before production deployment.

