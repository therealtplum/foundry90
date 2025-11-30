use crate::schemas::{OrderIntent, StrategyDecision};
use std::env;
use tokio::sync::mpsc;
use tracing::{debug, info};
use uuid::Uuid;

/// Strategy coordinator that merges decisions into order intents
/// Phase 1: Simple pass-through (one strategy, no conflicts)
pub struct Coordinator {
    rx: mpsc::Receiver<StrategyDecision>,
    tx: mpsc::Sender<OrderIntent>,
    simulation_mode: bool,
}

impl Coordinator {
    pub fn new(
        rx: mpsc::Receiver<StrategyDecision>,
        tx: mpsc::Sender<OrderIntent>,
    ) -> Self {
        let simulation_mode = env::var("HADRON_SIMULATION_MODE")
            .unwrap_or_else(|_| "true".to_string())
            .parse()
            .unwrap_or(true);

        Self {
            rx,
            tx,
            simulation_mode,
        }
    }

    /// Run the coordinator loop
    pub async fn run(&mut self) -> anyhow::Result<()> {
        info!(
            "Hadron Strategy Coordinator started (simulation_mode={})",
            self.simulation_mode
        );

        while let Some(decision) = self.rx.recv().await {
            if let Some(order_intent) = self.coordinate(decision).await? {
                debug!(
                    "Produced order intent: id={}, instrument_id={}",
                    order_intent.id, order_intent.instrument_id
                );

                if let Err(e) = self.tx.send(order_intent).await {
                    tracing::error!("Failed to send order intent: {}", e);
                }
            }
        }

        Ok(())
    }

    async fn coordinate(
        &self,
        decision: StrategyDecision,
    ) -> anyhow::Result<Option<OrderIntent>> {
        // Phase 1: Simple pass-through
        // Later: merge multiple decisions, apply risk rules, etc.

        let (side, quantity, limit_price) = match decision.decision_type {
            crate::schemas::DecisionType::Buy {
                quantity,
                limit_price,
            } => (crate::schemas::OrderSide::Buy, quantity, limit_price),
            crate::schemas::DecisionType::Sell {
                quantity,
                limit_price,
            } => (crate::schemas::OrderSide::Sell, quantity, limit_price),
            crate::schemas::DecisionType::Hold | crate::schemas::DecisionType::NoAction => {
                return Ok(None);
            }
        };

        let order_type = if limit_price.is_some() {
            crate::schemas::OrderType::Limit
        } else {
            crate::schemas::OrderType::Market
        };

        let order_intent = OrderIntent {
            id: Uuid::new_v4(),
            instrument_id: decision.instrument_id,
            strategy_id: decision.strategy_id,
            side,
            quantity,
            order_type,
            limit_price,
            timestamp: decision.timestamp,
            metadata: decision.metadata,
        };

        Ok(Some(order_intent))
    }
}

