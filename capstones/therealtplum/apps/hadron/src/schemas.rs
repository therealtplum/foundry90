use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Core event types flowing through Hadron pipeline
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum HadronEvent {
    /// Raw event from external data source (before normalization)
    RawEvent(RawEvent),
    /// Normalized tick ready for processing
    Tick(HadronTick),
    /// Decision produced by a strategy
    StrategyDecision(StrategyDecision),
    /// Order intent ready for gateway
    OrderIntent(OrderIntent),
    /// Order execution confirmation
    OrderExecution(OrderExecution),
}

/// Raw event from ingest layer (venue-specific format)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawEvent {
    pub source: String,           // e.g., "polygon"
    pub venue: String,            // e.g., "polygon_ws"
    pub raw_payload: serde_json::Value,
    pub received_at: DateTime<Utc>,
}

/// Normalized tick representing a market event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HadronTick {
    pub instrument_id: i64,
    pub timestamp: DateTime<Utc>,
    pub price: Decimal,
    pub size: Option<Decimal>,
    pub venue: String,
    pub tick_type: TickType,
    pub source: String,           // original source (e.g., "polygon")
}

/// Type of market tick
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum TickType {
    Trade,
    Quote,
    BookUpdate,
    Other,
}

/// Priority class for routing
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Priority {
    Fast,   // Process immediately
    Warm,   // Process opportunistically
    Cold,   // Process with surplus CPU
    Drop,   // Discard or batch
}

/// Strategy decision output
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StrategyDecision {
    pub strategy_id: String,
    pub strategy_name: String,
    pub instrument_id: i64,
    pub timestamp: DateTime<Utc>,
    pub decision_type: DecisionType,
    pub confidence: Option<Decimal>,  // 0.0 to 1.0
    pub metadata: serde_json::Value,
}

/// Type of decision a strategy can make
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DecisionType {
    Buy { quantity: Decimal, limit_price: Option<Decimal> },
    Sell { quantity: Decimal, limit_price: Option<Decimal> },
    Hold,
    NoAction,
}

/// Order intent ready for gateway processing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OrderIntent {
    pub id: Uuid,
    pub instrument_id: i64,
    pub strategy_id: String,
    pub side: OrderSide,
    pub quantity: Decimal,
    pub order_type: OrderType,
    pub limit_price: Option<Decimal>,
    pub timestamp: DateTime<Utc>,
    pub metadata: serde_json::Value,
}

/// Order side
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum OrderSide {
    Buy,
    Sell,
}

/// Order type
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum OrderType {
    Market,
    Limit,
    Stop,
    StopLimit,
}

/// Order execution confirmation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OrderExecution {
    pub order_intent_id: Uuid,
    pub instrument_id: i64,
    pub venue: String,
    pub executed_at: DateTime<Utc>,
    pub executed_price: Decimal,
    pub executed_quantity: Decimal,
    pub status: ExecutionStatus,
    pub venue_order_id: Option<String>,
}

/// Execution status
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum ExecutionStatus {
    Filled,
    PartiallyFilled,
    Rejected,
    Cancelled,
}

