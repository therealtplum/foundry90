use crate::schemas::{HadronTick, OrderExecution};
use sqlx::PgPool;
use tokio::sync::{broadcast, mpsc};
use tracing::{debug, info};

/// Recorder that persists events to Postgres
pub struct Recorder {
    tick_rx: broadcast::Receiver<HadronTick>,
    execution_rx: mpsc::Receiver<OrderExecution>,
    db_pool: PgPool,
    // Batch writes for efficiency
    tick_batch: Vec<HadronTick>,
    batch_size: usize,
}

impl Recorder {
    pub fn new(
        tick_rx: broadcast::Receiver<HadronTick>,
        execution_rx: mpsc::Receiver<OrderExecution>,
        db_pool: PgPool,
    ) -> Self {
        Self {
            tick_rx,
            execution_rx,
            db_pool,
            tick_batch: Vec::new(),
            batch_size: 100, // Batch 100 ticks before writing
        }
    }

    /// Run the recorder loop
    pub async fn run(&mut self) -> anyhow::Result<()> {
        info!("Hadron Recorder started");

        loop {
            tokio::select! {
                tick_result = self.tick_rx.recv() => {
                    match tick_result {
                        Ok(tick) => {
                            self.handle_tick(tick).await?;
                        }
                        Err(broadcast::error::RecvError::Closed) => {
                            info!("Tick broadcast channel closed");
                            return Ok(());
                        }
                        Err(broadcast::error::RecvError::Lagged(n)) => {
                            debug!("Recorder lagged by {} messages", n);
                            // Continue processing
                        }
                    }
                }
                execution_opt = self.execution_rx.recv() => {
                    if let Some(execution) = execution_opt {
                        self.handle_execution(execution).await?;
                    }
                }
            }
        }
    }

    async fn handle_tick(&mut self, tick: HadronTick) -> anyhow::Result<()> {
        self.tick_batch.push(tick);

        if self.tick_batch.len() >= self.batch_size {
            self.flush_ticks().await?;
        }

        Ok(())
    }

    async fn flush_ticks(&mut self) -> anyhow::Result<()> {
        if self.tick_batch.is_empty() {
            return Ok(());
        }

        let batch = std::mem::take(&mut self.tick_batch);

        // Batch insert ticks
        for tick in batch {
            sqlx::query(
                r#"
                INSERT INTO hadron_ticks (
                    instrument_id, timestamp, price, size, venue,
                    tick_type, source
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                "#,
            )
            .bind(tick.instrument_id)
            .bind(tick.timestamp)
            .bind(tick.price)
            .bind(tick.size)
            .bind(&tick.venue)
            .bind(format!("{:?}", tick.tick_type))
            .bind(&tick.source)
            .execute(&self.db_pool)
            .await?;
        }

        debug!("Flushed {} ticks to database", self.tick_batch.len());

        Ok(())
    }

    async fn handle_execution(&self, execution: OrderExecution) -> anyhow::Result<()> {
        // Executions are already written by gateway, but we can log here
        debug!(
            "Recording execution: order_intent_id={}, instrument_id={}",
            execution.order_intent_id, execution.instrument_id
        );

        Ok(())
    }
}

