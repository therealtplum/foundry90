use crate::schemas::{HadronTick, RawEvent, TickType};
use anyhow::{Context, Result};
use rust_decimal::Decimal;
use sqlx::PgPool;
use std::collections::HashMap;
use tokio::sync::{broadcast, mpsc};
use tracing::{error, info, warn};

/// Normalizer that converts raw events to HadronTick
pub struct Normalizer {
    db_pool: PgPool,
    rx: mpsc::Receiver<RawEvent>,
    tx: broadcast::Sender<HadronTick>,
    // Cache of ticker -> instrument_id mappings
    symbol_cache: HashMap<String, i64>,
}

impl Normalizer {
    pub fn new(
        db_pool: PgPool,
        rx: mpsc::Receiver<RawEvent>,
        tx: broadcast::Sender<HadronTick>,
    ) -> Self {
        Self {
            db_pool,
            rx,
            tx,
            symbol_cache: HashMap::new(),
        }
    }

    /// Run the normalizer loop
    pub async fn run(&mut self) -> Result<()> {
        info!("Hadron Normalizer started");

        while let Some(raw_event) = self.rx.recv().await {
            match self.normalize(&raw_event).await {
                Ok(Some(tick)) => {
                    if let Err(e) = self.tx.send(tick) {
                        error!("Failed to broadcast normalized tick: {}", e);
                    }
                }
                Ok(None) => {
                    // Event was filtered out or not relevant
                }
                Err(e) => {
                    error!("Normalization error: {}", e);
                }
            }
        }

        Ok(())
    }

    async fn normalize(&mut self, raw_event: &RawEvent) -> Result<Option<HadronTick>> {
        // Handle Polygon trade events
        if raw_event.source == "polygon" && raw_event.venue == "polygon_ws" {
            return self.normalize_polygon_trade(raw_event).await;
        }

        // Unknown source/venue - skip for now
        warn!(
            "Unknown source/venue combination: {}/{}",
            raw_event.source, raw_event.venue
        );
        Ok(None)
    }

    async fn normalize_polygon_trade(&mut self, raw_event: &RawEvent) -> Result<Option<HadronTick>> {
        let payload = &raw_event.raw_payload;

        // Polygon trade event structure:
        // {
        //   "ev": "T",
        //   "sym": "AAPL",
        //   "x": 4,  // exchange
        //   "i": "12345",  // trade ID
        //   "z": 3,  // tape
        //   "p": 150.25,  // price
        //   "s": 100,  // size
        //   "t": 1234567890000000000,  // timestamp (nanoseconds)
        //   ...
        // }

        let symbol = payload
            .get("sym")
            .and_then(|v| v.as_str())
            .context("Missing 'sym' field in Polygon trade event")?;

        // Look up instrument_id
        let instrument_id = match self.lookup_instrument_id(symbol).await {
            Ok(id) => id,
            Err(e) => {
                warn!("Failed to lookup instrument_id for symbol {}: {}", symbol, e);
                return Ok(None);
            }
        };

        let price = payload
            .get("p")
            .and_then(|v| v.as_f64())
            .map(Decimal::try_from)
            .transpose()
            .context("Invalid or missing 'p' (price) field")?
            .context("Missing 'p' (price) field")?;

        let size = payload
            .get("s")
            .and_then(|v| v.as_u64())
            .map(|v| Decimal::from(v));

        // Parse timestamp (nanoseconds since epoch)
        let timestamp_ns = payload
            .get("t")
            .and_then(|v| v.as_u64())
            .context("Missing 't' (timestamp) field")?;

        let timestamp = chrono::DateTime::from_timestamp(
            (timestamp_ns / 1_000_000_000) as i64,
            (timestamp_ns % 1_000_000_000) as u32,
        )
        .context("Invalid timestamp")?
        .with_timezone(&chrono::Utc);

        let tick = HadronTick {
            instrument_id,
            timestamp,
            price,
            size,
            venue: raw_event.venue.clone(),
            tick_type: TickType::Trade,
            source: raw_event.source.clone(),
        };

        Ok(Some(tick))
    }

    async fn lookup_instrument_id(&mut self, ticker: &str) -> Result<i64> {
        // Check cache first
        if let Some(&id) = self.symbol_cache.get(ticker) {
            return Ok(id);
        }

        // Query database
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
        .bind(ticker)
        .fetch_optional(&self.db_pool)
        .await
        .context("Failed to query instruments table")?;

        let instrument_id = match row {
            Some((id,)) => id,
            None => {
                // Try case-insensitive lookup
                let row = sqlx::query_as::<_, (i64,)>(
                    r#"
                    SELECT id
                    FROM instruments
                    WHERE UPPER(ticker) = UPPER($1)
                      AND status = 'active'
                    ORDER BY id
                    LIMIT 1
                    "#,
                )
                .bind(ticker)
                .fetch_optional(&self.db_pool)
                .await
                .context("Failed to query instruments table (case-insensitive)")?;

                row.map(|(id,)| id)
                    .context(format!("Instrument not found for ticker: {}", ticker))?
            }
        };

        // Cache it
        self.symbol_cache.insert(ticker.to_string(), instrument_id);

        Ok(instrument_id)
    }
}

