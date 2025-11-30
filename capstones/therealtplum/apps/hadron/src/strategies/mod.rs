use crate::engine::InstrumentState;
use crate::schemas::{DecisionType, HadronTick, StrategyDecision};
use chrono::Utc;
use rust_decimal::Decimal;
use serde_json::json;

/// Strategy trait - all strategies implement this
pub trait Strategy: Send {
    /// Evaluate a tick and produce a decision (if any)
    fn evaluate(
        &self,
        tick: &HadronTick,
        state: &InstrumentState,
    ) -> Option<StrategyDecision>;

    /// Strategy identifier
    fn id(&self) -> &str;

    /// Strategy name
    fn name(&self) -> &str;
}

/// Simple moving average crossover strategy
/// For Phase 1: very simple - buy if price > SMA, sell if price < SMA
pub struct SimpleSMAStrategy {
    id: String,
    name: String,
    min_confidence: Decimal,
}

impl SimpleSMAStrategy {
    pub fn new() -> Self {
        Self {
            id: "simple_sma_v1".to_string(),
            name: "Simple SMA Strategy".to_string(),
            min_confidence: Decimal::new(6, 1), // 0.6
        }
    }
}

impl Strategy for SimpleSMAStrategy {
    fn evaluate(
        &self,
        tick: &HadronTick,
        state: &InstrumentState,
    ) -> Option<StrategyDecision> {
        // Need at least 5 ticks to have SMA
        let sma = state.sma_5?;
        let price = tick.price;

        // Simple rule: if price is significantly above SMA, consider buying
        // If price is significantly below SMA, consider selling
        let threshold = Decimal::new(1, 2); // 0.01 = 1%

        let decision = if price > sma * (Decimal::ONE + threshold) {
            // Price is 1%+ above SMA - bullish signal
            Some(DecisionType::Buy {
                quantity: Decimal::new(10, 0), // 10 shares (example)
                limit_price: None,              // Market order
            })
        } else if price < sma * (Decimal::ONE - threshold) {
            // Price is 1%+ below SMA - bearish signal
            Some(DecisionType::Sell {
                quantity: Decimal::new(10, 0), // 10 shares (example)
                limit_price: None,              // Market order
            })
        } else {
            None
        };

        decision.map(|decision_type| StrategyDecision {
            strategy_id: self.id.clone(),
            strategy_name: self.name.clone(),
            instrument_id: tick.instrument_id,
            timestamp: Utc::now(),
            decision_type,
            confidence: Some(self.min_confidence),
            metadata: json!({
                "price": price,
                "sma_5": sma,
                "tick_count": state.tick_count,
            }),
        })
    }

    fn id(&self) -> &str {
        &self.id
    }

    fn name(&self) -> &str {
        &self.name
    }
}

