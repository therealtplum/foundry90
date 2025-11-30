use crate::schemas::{HadronTick, RawEvent, TickType};
use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use sqlx::PgPool;
use std::collections::HashMap;
use tracing::warn;

/// Kalshi-specific normalizer
/// Handles conversion of Kalshi WebSocket events to HadronTick
pub struct KalshiNormalizer {
    db_pool: PgPool,
    // Cache of market_ticker -> instrument_id mappings
    market_cache: HashMap<String, i64>,
}

impl KalshiNormalizer {
    pub fn new(db_pool: PgPool) -> Self {
        Self {
            db_pool,
            market_cache: HashMap::new(),
        }
    }

    /// Normalize a Kalshi raw event to HadronTick
    pub async fn normalize(&mut self, raw_event: &RawEvent) -> Result<Option<HadronTick>> {
        let payload = &raw_event.raw_payload;

        // Get message type - Kalshi messages can have "type" at top level or in "msg"
        let msg_type = payload
            .get("type")
            .and_then(|v| v.as_str())
            .or_else(|| {
                // Try "msg" object
                payload.get("msg")
                    .and_then(|m| m.get("type"))
                    .and_then(|v| v.as_str())
            });

        let msg_type = match msg_type {
            Some(t) => t,
            None => {
                // Skip messages without type (might be control messages)
                return Ok(None);
            }
        };

        match msg_type {
            "ticker" => self.normalize_ticker(raw_event, payload).await,
            "trades" => self.normalize_trade(raw_event, payload).await,
            "orderbook_delta" | "orderbook_snapshot" => {
                // For now, we'll use the mid-price from orderbook
                // In the future, we might want separate BookUpdate ticks
                self.normalize_orderbook(raw_event, payload).await
            }
            "subscribed" | "error" => {
                // Control messages - skip
                Ok(None)
            }
            _ => {
                warn!("Unknown Kalshi message type: {}", msg_type);
                Ok(None)
            }
        }
    }

    /// Normalize Kalshi ticker update
    /// Ticker format: {"type": "ticker", "data": {"market_ticker": "...", "bid": 45, "ask": 46, "last_price": 45, "volume": 1234}}
    /// Or: {"type": "ticker", "msg": {"market_ticker": "...", "bid": 45, ...}}
    async fn normalize_ticker(
        &mut self,
        raw_event: &RawEvent,
        payload: &serde_json::Value,
    ) -> Result<Option<HadronTick>> {
        // Kalshi messages can have data in "data" or "msg" field
        let data = payload
            .get("data")
            .or_else(|| payload.get("msg"))
            .context("Missing 'data' or 'msg' field in Kalshi ticker message")?;

        let market_ticker = data
            .get("market_ticker")
            .and_then(|v| v.as_str())
            .context("Missing 'market_ticker' in Kalshi ticker data")?;

        // Look up or create instrument
        let instrument_id = match self.lookup_or_create_instrument(market_ticker).await {
            Ok(id) => id,
            Err(e) => {
                warn!(
                    "Failed to lookup/create instrument for market {}: {}",
                    market_ticker, e
                );
                return Ok(None);
            }
        };

        // Kalshi prices are in cents (0-100), representing probability
        // Kalshi ticker format uses: "price" (last price), "yes_bid"/"yes_ask" (bid/ask)
        // Prices can be integers or floats, so try both
        let price_cents = data
            .get("price")  // Primary: last price
            .and_then(|v| v.as_u64().or_else(|| v.as_f64().map(|f| f as u64)))
            .or_else(|| {
                // Fall back to mid-price from yes_bid/yes_ask
                let bid = data.get("yes_bid")
                    .and_then(|v| v.as_u64().or_else(|| v.as_f64().map(|f| f as u64)))?;
                let ask = data.get("yes_ask")
                    .and_then(|v| v.as_u64().or_else(|| v.as_f64().map(|f| f as u64)))?;
                Some((bid + ask) / 2)
            })
            .or_else(|| {
                // Legacy: try old field names (bid/ask)
                let bid = data.get("bid")
                    .and_then(|v| v.as_u64().or_else(|| v.as_f64().map(|f| f as u64)))?;
                let ask = data.get("ask")
                    .and_then(|v| v.as_u64().or_else(|| v.as_f64().map(|f| f as u64)))?;
                Some((bid + ask) / 2)
            });

        let price_cents = match price_cents {
            Some(p) => p,
            None => {
                warn!(
                    "Missing price information in Kalshi ticker for market {}",
                    market_ticker
                );
                return Ok(None);
            }
        };

        // Convert cents to Decimal (0-100 range, representing 0-100% probability)
        let price = Decimal::from(price_cents) / Decimal::from(100);

        // Volume is optional
        let size = data
            .get("volume")
            .and_then(|v| v.as_u64())
            .map(|v| Decimal::from(v));

        // Use received_at as timestamp (Kalshi ticker doesn't always have timestamp)
        let timestamp = raw_event.received_at;

        Ok(Some(HadronTick {
            instrument_id,
            timestamp,
            price,
            size,
            venue: raw_event.venue.clone(),
            tick_type: TickType::Quote, // Ticker represents quote (bid/ask)
            source: raw_event.source.clone(),
        }))
    }

    /// Normalize Kalshi trade event
    /// Trade format: {"type": "trades", "data": {"market_ticker": "...", "price": 45, "quantity": 10, "side": "yes", "timestamp": 1234567890}}
    async fn normalize_trade(
        &mut self,
        raw_event: &RawEvent,
        payload: &serde_json::Value,
    ) -> Result<Option<HadronTick>> {
        let data = payload
            .get("data")
            .or_else(|| payload.get("msg"))
            .context("Missing 'data' or 'msg' field in Kalshi trade message")?;

        let market_ticker = data
            .get("market_ticker")
            .and_then(|v| v.as_str())
            .context("Missing 'market_ticker' in Kalshi trade data")?;

        // Look up or create instrument
        let instrument_id = match self.lookup_or_create_instrument(market_ticker).await {
            Ok(id) => id,
            Err(e) => {
                warn!(
                    "Failed to lookup/create instrument for market {}: {}",
                    market_ticker, e
                );
                return Ok(None);
            }
        };

        // Price in cents (0-100)
        let price_cents = data
            .get("price")
            .and_then(|v| v.as_u64())
            .context("Missing 'price' in Kalshi trade data")?;

        // Convert cents to Decimal (0-100 range)
        let price = Decimal::from(price_cents) / Decimal::from(100);

        // Quantity
        let size = data
            .get("quantity")
            .and_then(|v| v.as_u64())
            .map(|v| Decimal::from(v));

        // Timestamp - Kalshi uses Unix timestamp (seconds)
        let timestamp = data
            .get("timestamp")
            .and_then(|v| v.as_i64())
            .map(|ts| DateTime::from_timestamp(ts, 0))
            .flatten()
            .unwrap_or_else(|| raw_event.received_at);

        Ok(Some(HadronTick {
            instrument_id,
            timestamp,
            price,
            size,
            venue: raw_event.venue.clone(),
            tick_type: TickType::Trade,
            source: raw_event.source.clone(),
        }))
    }

    /// Normalize Kalshi orderbook update
    /// Uses mid-price from orderbook
    async fn normalize_orderbook(
        &mut self,
        raw_event: &RawEvent,
        payload: &serde_json::Value,
    ) -> Result<Option<HadronTick>> {
        let data = payload
            .get("data")
            .or_else(|| payload.get("msg"))
            .context("Missing 'data' or 'msg' field in Kalshi orderbook message")?;

        let market_ticker = data
            .get("market_ticker")
            .and_then(|v| v.as_str())
            .context("Missing 'market_ticker' in Kalshi orderbook data")?;

        // Look up or create instrument
        let instrument_id = match self.lookup_or_create_instrument(market_ticker).await {
            Ok(id) => id,
            Err(e) => {
                warn!(
                    "Failed to lookup/create instrument for market {}: {}",
                    market_ticker, e
                );
                return Ok(None);
            }
        };

        // Kalshi orderbook has "yes" and "no" sides
        // Each side is an array of [price_cents, quantity] pairs
        // We'll calculate mid-price from best bid/ask
        let yes_orders = data
            .get("yes")
            .and_then(|v| v.as_array())
            .map_or(&[] as &[serde_json::Value], |arr| arr);
        let no_orders = data
            .get("no")
            .and_then(|v| v.as_array())
            .map_or(&[] as &[serde_json::Value], |arr| arr);

        // Best bid = highest "yes" price, Best ask = lowest "no" price
        // In Kalshi: "yes" means you think it will happen (higher price = more confident)
        // "no" means you think it won't happen (lower price = more confident)
        // Mid-price = (best_yes + best_no) / 2
        let best_yes = yes_orders
            .iter()
            .filter_map(|order| {
                order.as_array()?.get(0)?.as_u64()
            })
            .max();
        let best_no = no_orders
            .iter()
            .filter_map(|order| {
                order.as_array()?.get(0)?.as_u64()
            })
            .min();

        let price_cents = match (best_yes, best_no) {
            (Some(yes), Some(no)) => (yes + no) / 2,
            (Some(yes), None) => yes,
            (None, Some(no)) => no,
            (None, None) => {
                warn!("No valid prices in Kalshi orderbook for {}", market_ticker);
                return Ok(None);
            }
        };

        // Convert cents to Decimal
        let price = Decimal::from(price_cents) / Decimal::from(100);

        // Use received_at as timestamp
        let timestamp = raw_event.received_at;

        Ok(Some(HadronTick {
            instrument_id,
            timestamp,
            price,
            size: None, // Orderbook doesn't have a single trade size
            venue: raw_event.venue.clone(),
            tick_type: TickType::BookUpdate,
            source: raw_event.source.clone(),
        }))
    }

    /// Look up or create instrument for a Kalshi market ticker
    async fn lookup_or_create_instrument(&mut self, market_ticker: &str) -> Result<i64> {
        // Check cache first
        if let Some(&id) = self.market_cache.get(market_ticker) {
            return Ok(id);
        }

        // Try to find existing instrument
        let row = sqlx::query_as::<_, (i64,)>(
            r#"
            SELECT id
            FROM instruments
            WHERE ticker = $1
              AND status = 'active'
            ORDER BY id
            LIMIT 1
            "#,
        )
        .bind(market_ticker)
        .fetch_optional(&self.db_pool)
        .await
        .context("Failed to query instruments table")?;

        let instrument_id = if let Some((id,)) = row {
            id
        } else {
            // Create new instrument for this Kalshi market
            // Kalshi markets are prediction markets, using 'other' asset_class for now
            // Note: instruments table has unique constraint on (ticker, asset_class, primary_source)
            let row = sqlx::query_as::<_, (i64,)>(
                r#"
                INSERT INTO instruments (ticker, name, asset_class, primary_source, status, created_at, updated_at)
                VALUES ($1, $2, 'other', 'kalshi', 'active', NOW(), NOW())
                ON CONFLICT (ticker, asset_class, primary_source) DO UPDATE SET status = 'active', updated_at = NOW()
                RETURNING id
                "#,
            )
            .bind(market_ticker)
            .bind(format!("Kalshi Market: {}", market_ticker))
            .fetch_one(&self.db_pool)
            .await
            .context("Failed to create instrument for Kalshi market")?;

            row.0
        };

        // Cache it
        self.market_cache.insert(market_ticker.to_string(), instrument_id);

        Ok(instrument_id)
    }
}

