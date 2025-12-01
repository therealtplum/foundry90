# Web Application TODO

## Multi-Asset Class Display

**Status:** Planned  
**Priority:** Medium  
**Created:** 2025-12-XX

### Goal
Display sports prediction markets (e.g., Kalshi), crypto, and other asset classes alongside traditional stocks in the focus ticker strip and throughout the web application.

### Current State
- The focus ticker strip (`/capstones` page) currently displays data from the API endpoint `/focus/ticker-strip`, which pulls from the database's `instrument_focus_universe` table.
- The database currently contains primarily stocks, ETFs, and equities.
- Sample data (`apps/web/data/sample_tickers.json`) includes example KU basketball games with `asset_class: "other"` to demonstrate the concept.

### Requirements

1. **Database Integration**
   - Ensure Kalshi markets and other prediction markets are properly stored in the `instruments` table with appropriate `asset_class` values.
   - Update ETL pipelines to include sports/crypto/prediction market data in the focus universe calculation.

2. **API Enhancement**
   - The `/focus/ticker-strip` endpoint should return instruments from all asset classes (equity, etf, crypto, other, etc.).
   - No filtering by asset class should occur at the API level.

3. **UI/UX Considerations**
   - The ticker strip should seamlessly display all asset types.
   - Consider visual differentiation (icons, colors) for different asset classes if needed.
   - Ensure price formatting works correctly for:
     - Stocks/ETFs: Dollar amounts (e.g., $679.68)
     - Prediction markets: Probabilities (e.g., 0.65 = 65%)
     - Crypto: Appropriate decimal precision

4. **Data Normalization**
   - Ensure consistent data structure across asset classes.
   - Handle missing fields gracefully (e.g., `prior_day_last_close_price` may not exist for prediction markets).

### Implementation Notes

- The `FocusTickerStrip` component already supports the data structure needed (it normalizes `short_insight`/`recent_insight` fields).
- The static fallback (`sample_tickers.json`) demonstrates the expected format.
- The component currently prioritizes API data over static JSON, which is correct for production.

### Related Work

- Kalshi integration in Hadron (`apps/hadron/`) is in progress.
- Kalshi ticker parser (`apps/python-etl/etl/kalshi_ticker_parser.py`) exists for normalizing market data.
- Sample data includes KU basketball games as examples.

### Next Steps

1. Complete Kalshi ETL pipeline to populate `instruments` table with prediction markets.
2. Update focus universe calculation to include prediction markets.
3. Test ticker strip display with mixed asset classes.
4. Add visual indicators for asset class if needed.
5. Ensure price formatting handles all asset types correctly.

