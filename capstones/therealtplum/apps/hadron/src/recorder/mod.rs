use crate::schemas::{HadronTick, OrderExecution};
use sqlx::PgPool;
use tokio::sync::{broadcast, mpsc};
use tokio::time::{interval, Duration};
use tracing::{debug, info, warn};

/// Recorder that persists events to Postgres
pub struct Recorder {
    tick_rx: broadcast::Receiver<HadronTick>,
    execution_rx: mpsc::Receiver<OrderExecution>,
    db_pool: PgPool,
    // Batch writes for efficiency
    tick_batch: Vec<HadronTick>,
    batch_size: usize,
    flush_interval: Duration,
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
            flush_interval: Duration::from_secs(5), // Flush every 5 seconds if batch not full
        }
    }

    /// Run the recorder loop
    pub async fn run(&mut self) -> anyhow::Result<()> {
        info!("Hadron Recorder started (batch_size={}, flush_interval={}s)", 
              self.batch_size, self.flush_interval.as_secs());

        let mut flush_timer = interval(self.flush_interval);

        loop {
            tokio::select! {
                tick_result = self.tick_rx.recv() => {
                    match tick_result {
                        Ok(tick) => {
                            self.handle_tick(tick).await?;
                        }
                        Err(broadcast::error::RecvError::Closed) => {
                            info!("Tick broadcast channel closed");
                            // Flush any remaining ticks before exiting
                            self.flush_ticks().await?;
                            return Ok(());
                        }
                        Err(broadcast::error::RecvError::Lagged(n)) => {
                            warn!("Recorder lagged by {} messages - may need larger buffer or faster processing", n);
                            // Continue processing
                        }
                    }
                }
                execution_opt = self.execution_rx.recv() => {
                    if let Some(execution) = execution_opt {
                        self.handle_execution(execution).await?;
                    }
                }
                _ = flush_timer.tick() => {
                    // Time-based flush to prevent ticks sitting in memory too long
                    if !self.tick_batch.is_empty() {
                        debug!("Timer-based flush triggered with {} ticks", self.tick_batch.len());
                        self.flush_ticks().await?;
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
        let batch_len = batch.len();

        // Use a transaction for better performance - all inserts in one transaction
        // This is significantly faster than individual transactions
        let mut tx = self.db_pool.begin().await?;

        // Execute all inserts in the transaction
        // While not as fast as a single multi-row INSERT, this is still much better
        // than individual transactions and works reliably with sqlx
        for tick in &batch {
            // Convert enum to string for PostgreSQL enum type
            // The enum values match the database enum: 'Trade', 'Quote', 'BookUpdate', 'Other'
            let tick_type_str = match tick.tick_type {
                crate::schemas::TickType::Trade => "Trade",
                crate::schemas::TickType::Quote => "Quote",
                crate::schemas::TickType::BookUpdate => "BookUpdate",
                crate::schemas::TickType::Other => "Other",
            };
            
            sqlx::query(
                r#"
                INSERT INTO hadron_ticks (
                    instrument_id, timestamp, price, size, venue,
                    tick_type, source
                )
                VALUES ($1, $2, $3, $4, $5, $6::tick_type_enum, $7)
                "#,
            )
            .bind(tick.instrument_id)
            .bind(tick.timestamp)
            .bind(tick.price)
            .bind(tick.size)
            .bind(&tick.venue)
            .bind(tick_type_str)
            .bind(&tick.source)
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;

        debug!("Flushed {} ticks to database", batch_len);

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

