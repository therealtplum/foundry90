use crate::schemas::{HadronTick, Priority};
use std::env;
use tokio::sync::{broadcast, mpsc};
use tracing::debug;

/// Router that classifies ticks by priority and assigns to shards
pub struct Router {
    rx: broadcast::Receiver<HadronTick>,
    // Per-shard, per-priority queues
    // For Phase 1: single shard (shard 0)
    fast_tx: mpsc::Sender<HadronTick>,
    warm_tx: mpsc::Sender<HadronTick>,
    cold_tx: mpsc::Sender<HadronTick>,
    num_shards: usize,
}

impl Router {
    pub fn new(
        rx: broadcast::Receiver<HadronTick>,
        fast_tx: mpsc::Sender<HadronTick>,
        warm_tx: mpsc::Sender<HadronTick>,
        cold_tx: mpsc::Sender<HadronTick>,
    ) -> Self {
        let num_shards = env::var("HADRON_NUM_SHARDS")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(1);

        Self {
            rx,
            fast_tx,
            warm_tx,
            cold_tx,
            num_shards,
        }
    }

    /// Run the router loop
    pub async fn run(&mut self) -> anyhow::Result<()> {
        tracing::info!("Hadron Router started ({} shards)", self.num_shards);

        loop {
            let tick = match self.rx.recv().await {
                Ok(tick) => tick,
                Err(broadcast::error::RecvError::Closed) => {
                    tracing::warn!("Broadcast channel closed");
                    break;
                }
                Err(broadcast::error::RecvError::Lagged(n)) => {
                    tracing::warn!("Router lagged by {} messages", n);
                    continue;
                }
            };
            let priority = self.classify_priority(&tick);
            let shard = self.assign_shard(&tick);

            debug!(
                "Routing tick: instrument_id={}, priority={:?}, shard={}",
                tick.instrument_id, priority, shard
            );

            match priority {
                Priority::Fast => {
                    if let Err(e) = self.fast_tx.send(tick).await {
                        tracing::error!("Failed to send to fast queue: {}", e);
                    }
                }
                Priority::Warm => {
                    if let Err(e) = self.warm_tx.send(tick).await {
                        tracing::error!("Failed to send to warm queue: {}", e);
                    }
                }
                Priority::Cold => {
                    if let Err(e) = self.cold_tx.send(tick).await {
                        tracing::error!("Failed to send to cold queue: {}", e);
                    }
                }
                Priority::Drop => {
                    // Discard
                    debug!("Dropping tick for instrument_id={}", tick.instrument_id);
                }
            }
        }

        Ok(())
    }

    /// Classify priority based on tick characteristics
    /// For Phase 1: simple rule - all trades are FAST
    fn classify_priority(&self, tick: &HadronTick) -> Priority {
        // Phase 1: Simple classification
        // All trade ticks are FAST
        // Later: add rules based on open positions, volatility, strategy interest, etc.
        match tick.tick_type {
            crate::schemas::TickType::Trade => Priority::Fast,
            crate::schemas::TickType::Quote => Priority::Warm,
            _ => Priority::Cold,
        }
    }

    /// Assign tick to a shard based on instrument_id
    fn assign_shard(&self, tick: &HadronTick) -> usize {
        // Hash instrument_id to shard
        use std::hash::{Hash, Hasher};
        use std::collections::hash_map::DefaultHasher;

        let mut hasher = DefaultHasher::new();
        tick.instrument_id.hash(&mut hasher);
        (hasher.finish() as usize) % self.num_shards
    }
}

