use crate::schemas::{HadronTick, StrategyDecision};
use rust_decimal::Decimal;
use std::collections::HashMap;
use tokio::sync::mpsc;
use tracing::{debug, info};

/// Per-instrument state maintained by the engine
#[derive(Debug, Clone)]
pub struct InstrumentState {
    pub instrument_id: i64,
    pub last_price: Option<Decimal>,
    pub last_timestamp: Option<chrono::DateTime<chrono::Utc>>,
    pub tick_count: u64,
    // Simple moving average (for example strategy)
    pub sma_5: Option<Decimal>,
    pub price_history: Vec<(chrono::DateTime<chrono::Utc>, Decimal)>,
}

impl InstrumentState {
    pub fn new(instrument_id: i64) -> Self {
        Self {
            instrument_id,
            last_price: None,
            last_timestamp: None,
            tick_count: 0,
            sma_5: None,
            price_history: Vec::new(),
        }
    }

    pub fn update(&mut self, tick: &HadronTick) {
        self.last_price = Some(tick.price);
        self.last_timestamp = Some(tick.timestamp);
        self.tick_count += 1;

        // Maintain price history (keep last 5 for SMA)
        self.price_history.push((tick.timestamp, tick.price));
        if self.price_history.len() > 5 {
            self.price_history.remove(0);
        }

        // Update SMA if we have enough data
        if self.price_history.len() >= 5 {
            let sum: Decimal = self.price_history.iter().map(|(_, p)| p).sum();
            self.sma_5 = Some(sum / Decimal::from(5));
        }
    }
}

/// Engine for a single shard
pub struct Engine {
    shard_id: usize,
    fast_rx: mpsc::Receiver<HadronTick>,
    warm_rx: mpsc::Receiver<HadronTick>,
    cold_rx: mpsc::Receiver<HadronTick>,
    decision_tx: mpsc::Sender<StrategyDecision>,
    // Per-instrument state
    instruments: HashMap<i64, InstrumentState>,
    // Strategy to run (Phase 1: single strategy)
    strategy: Box<dyn crate::strategies::Strategy + Send>,
}

impl Engine {
    pub fn new(
        shard_id: usize,
        fast_rx: mpsc::Receiver<HadronTick>,
        warm_rx: mpsc::Receiver<HadronTick>,
        cold_rx: mpsc::Receiver<HadronTick>,
        decision_tx: mpsc::Sender<StrategyDecision>,
        strategy: Box<dyn crate::strategies::Strategy + Send>,
    ) -> Self {
        Self {
            shard_id,
            fast_rx,
            warm_rx,
            cold_rx,
            decision_tx,
            instruments: HashMap::new(),
            strategy,
        }
    }

    /// Run the engine loop
    pub async fn run(&mut self) -> anyhow::Result<()> {
        info!("Hadron Engine (shard {}) started", self.shard_id);

        loop {
            tokio::select! {
                // Process FAST queue first
                tick_opt = self.fast_rx.recv() => {
                    if let Some(tick) = tick_opt {
                        self.process_tick(tick).await?;
                    }
                }
                // Then WARM queue
                tick_opt = self.warm_rx.recv() => {
                    if let Some(tick) = tick_opt {
                        self.process_tick(tick).await?;
                    }
                }
                // Finally COLD queue
                tick_opt = self.cold_rx.recv() => {
                    if let Some(tick) = tick_opt {
                        self.process_tick(tick).await?;
                    }
                }
            }
        }
    }

    async fn process_tick(&mut self, tick: HadronTick) -> anyhow::Result<()> {
        // Get or create instrument state
        let state = self
            .instruments
            .entry(tick.instrument_id)
            .or_insert_with(|| InstrumentState::new(tick.instrument_id));

        // Update state
        state.update(&tick);

        // Run strategy
        if let Some(decision) = self.strategy.evaluate(&tick, state) {
            debug!(
                "Strategy decision: {:?} for instrument_id={}",
                decision.decision_type, tick.instrument_id
            );

            if let Err(e) = self.decision_tx.send(decision).await {
                tracing::error!("Failed to send strategy decision: {}", e);
            }
        }

        Ok(())
    }
}

