use crate::schemas::{OrderExecution, OrderIntent};
use chrono::Utc;
use sqlx::PgPool;
use std::env;
use tokio::sync::mpsc;
use tracing::{debug, info};

/// Order gateway that routes orders to venues
/// Phase 1: Simulation mode only (logs and records)
pub struct Gateway {
    rx: mpsc::Receiver<OrderIntent>,
    execution_tx: mpsc::Sender<OrderExecution>,
    db_pool: PgPool,
    simulation_mode: bool,
}

impl Gateway {
    pub fn new(
        rx: mpsc::Receiver<OrderIntent>,
        execution_tx: mpsc::Sender<OrderExecution>,
        db_pool: PgPool,
    ) -> Self {
        let simulation_mode = env::var("HADRON_SIMULATION_MODE")
            .unwrap_or_else(|_| "true".to_string())
            .parse()
            .unwrap_or(true);

        Self {
            rx,
            execution_tx,
            db_pool,
            simulation_mode,
        }
    }

    /// Run the gateway loop
    pub async fn run(&mut self) -> anyhow::Result<()> {
        info!(
            "Hadron Order Gateway started (simulation_mode={})",
            self.simulation_mode
        );

        while let Some(order_intent) = self.rx.recv().await {
            match self.process_order(order_intent).await {
                Ok(execution) => {
                    if let Some(exec) = execution {
                        debug!(
                            "Order executed: intent_id={}, instrument_id={}",
                            exec.order_intent_id, exec.instrument_id
                        );

                        if let Err(e) = self.execution_tx.send(exec).await {
                            tracing::error!("Failed to send order execution: {}", e);
                        }
                    }
                }
                Err(e) => {
                    tracing::error!("Failed to process order: {}", e);
                }
            }
        }

        Ok(())
    }

    async fn process_order(
        &self,
        intent: OrderIntent,
    ) -> anyhow::Result<Option<OrderExecution>> {
        if self.simulation_mode {
            // Simulation mode: immediately "fill" at current market price
            // In reality, we'd look up the last known price from Redis or state
            // For MVP, we'll use a placeholder price

            info!(
                "SIMULATION: Executing order intent_id={}, instrument_id={}, side={:?}, quantity={}",
                intent.id, intent.instrument_id, intent.side, intent.quantity
            );

            // Record the order intent
            // Convert enums to strings matching database enum types
            let side_str = match intent.side {
                crate::schemas::OrderSide::Buy => "Buy",
                crate::schemas::OrderSide::Sell => "Sell",
            };
            let order_type_str = match intent.order_type {
                crate::schemas::OrderType::Market => "Market",
                crate::schemas::OrderType::Limit => "Limit",
                crate::schemas::OrderType::Stop => "Stop",
                crate::schemas::OrderType::StopLimit => "StopLimit",
            };
            
            sqlx::query(
                r#"
                INSERT INTO hadron_order_intents (
                    id, instrument_id, strategy_id, side, quantity,
                    order_type, limit_price, timestamp, metadata
                )
                VALUES ($1, $2, $3, $4::order_side_enum, $5, $6::order_type_enum, $7, $8, $9)
                "#,
            )
            .bind(intent.id)
            .bind(intent.instrument_id)
            .bind(&intent.strategy_id)
            .bind(side_str)
            .bind(intent.quantity)
            .bind(order_type_str)
            .bind(intent.limit_price)
            .bind(intent.timestamp)
            .bind(&intent.metadata)
            .execute(&self.db_pool)
            .await?;

            // Create simulated execution
            // For MVP, we'll assume immediate fill at a simulated price
            let execution = OrderExecution {
                order_intent_id: intent.id,
                instrument_id: intent.instrument_id,
                venue: "simulation".to_string(),
                executed_at: Utc::now(),
                executed_price: intent.limit_price.unwrap_or(rust_decimal::Decimal::new(100, 0)), // Placeholder
                executed_quantity: intent.quantity,
                status: crate::schemas::ExecutionStatus::Filled,
                venue_order_id: Some(format!("SIM-{}", intent.id)),
            };

            // Record execution
            // Convert enum to string matching database enum type
            let status_str = match execution.status {
                crate::schemas::ExecutionStatus::Filled => "Filled",
                crate::schemas::ExecutionStatus::PartiallyFilled => "PartiallyFilled",
                crate::schemas::ExecutionStatus::Rejected => "Rejected",
                crate::schemas::ExecutionStatus::Cancelled => "Cancelled",
            };
            
            sqlx::query(
                r#"
                INSERT INTO hadron_order_executions (
                    order_intent_id, instrument_id, venue, executed_at,
                    executed_price, executed_quantity, status, venue_order_id
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7::execution_status_enum, $8)
                "#,
            )
            .bind(execution.order_intent_id)
            .bind(execution.instrument_id)
            .bind(&execution.venue)
            .bind(execution.executed_at)
            .bind(execution.executed_price)
            .bind(execution.executed_quantity)
            .bind(status_str)
            .bind(execution.venue_order_id.as_ref())
            .execute(&self.db_pool)
            .await?;

            Ok(Some(execution))
        } else {
            // Live mode: connect to real venue
            // Phase 1: not implemented
            tracing::warn!("Live order routing not implemented yet");
            Ok(None)
        }
    }
}

