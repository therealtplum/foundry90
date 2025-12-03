// Kalshi integration API endpoints

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use serde_json;
use sqlx::FromRow;
use tracing::{error, info};

use crate::AppState;

// ============================================================================
// DTOs
// ============================================================================

#[derive(Debug, Serialize, FromRow)]
pub struct KalshiMarketSummary {
    pub id: i64,
    pub ticker: String,
    pub name: String,
    pub display_name: String,
    pub category: Option<String>,
    pub status: String,
    pub yes_price: Option<Decimal>,
    pub volume: Option<Decimal>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct KalshiUserBalance {
    pub balance: Decimal,
    pub currency: String,
    pub available_balance: Decimal,
    pub pending_withdrawals: Decimal,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct KalshiPosition {
    pub ticker: String,
    pub position: i32, // Positive for yes, negative for no
    pub average_price: Decimal,
    pub current_price: Decimal,
    pub unrealized_pnl: Decimal,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct KalshiUserAccount {
    pub balance: KalshiUserBalance,
    pub positions: Vec<KalshiPosition>,
    pub fetched_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Deserialize)]
pub struct ListKalshiMarketsParams {
    pub category: Option<String>,
    pub status: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
    pub search: Option<String>,
}

// ============================================================================
// Handlers
// ============================================================================

/// GET /kalshi/markets
/// List Kalshi markets with filtering and pagination
pub async fn list_kalshi_markets_handler(
    State(state): State<AppState>,
    Query(params): Query<ListKalshiMarketsParams>,
) -> impl IntoResponse {
    let limit = params.limit.unwrap_or(100).min(1000); // Cap at 1000
    let offset = params.offset.unwrap_or(0);
    let category = params.category.as_deref();
    let status = params.status.as_deref().unwrap_or("active");
    let search = params.search.as_deref();

    // Use the database function for filtering
    // Note: Cast limit and offset to i32 to match database function signature (integer type)
    let result = sqlx::query_as::<_, KalshiMarketSummary>(
        r#"
        SELECT * FROM get_kalshi_markets_filtered($1, $2, $3, $4, $5)
        "#,
    )
    .bind(category)
    .bind(status)
    .bind(limit as i32)
    .bind(offset as i32)
    .bind(search)
    .fetch_all(&state.db_pool)
    .await;

    match result {
        Ok(markets) => {
            info!("Fetched {} Kalshi markets", markets.len());
            (StatusCode::OK, Json(markets))
        }
        Err(e) => {
            error!("Error fetching Kalshi markets: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(vec![] as Vec<KalshiMarketSummary>),
            )
        }
    }
}

/// GET /kalshi/markets/{ticker}
/// Get details for a specific Kalshi market
pub async fn get_kalshi_market_handler(
    State(state): State<AppState>,
    Path(ticker): Path<String>,
) -> impl IntoResponse {
    // Use query_as with a struct or return JSON directly
    let result = sqlx::query(
        r#"
        SELECT 
            i.id,
            i.ticker,
            i.name,
            i.asset_class,
            i.status,
            i.external_ref,
            c.market_data,
            c.yes_price,
            c.no_price,
            c.volume,
            c.last_updated
        FROM instruments i
        LEFT JOIN kalshi_market_cache c ON i.ticker = c.market_ticker
        WHERE i.primary_source = 'kalshi'
          AND i.ticker = $1
        "#,
    )
    .bind(&ticker)
    .fetch_optional(&state.db_pool)
    .await;

    match result {
        Ok(Some(row)) => {
            use sqlx::Row;
            let market = serde_json::json!({
                "id": row.get::<i64, _>("id"),
                "ticker": row.get::<String, _>("ticker"),
                "name": row.get::<String, _>("name"),
                "asset_class": row.get::<String, _>("asset_class"),
                "status": row.get::<String, _>("status"),
                "external_ref": row.try_get::<serde_json::Value, _>("external_ref").ok(),
                "market_data": row.try_get::<serde_json::Value, _>("market_data").ok(),
                "yes_price": row.try_get::<Option<rust_decimal::Decimal>, _>("yes_price").ok().flatten(),
                "no_price": row.try_get::<Option<rust_decimal::Decimal>, _>("no_price").ok().flatten(),
                "volume": row.try_get::<Option<rust_decimal::Decimal>, _>("volume").ok().flatten(),
                "last_updated": row.try_get::<Option<chrono::DateTime<chrono::Utc>>, _>("last_updated").ok(),
            });
            (StatusCode::OK, Json(market))
        }
        Ok(None) => {
            (
                StatusCode::NOT_FOUND,
                Json(serde_json::json!({"error": "Market not found"})),
            )
        }
        Err(e) => {
            error!("Error fetching Kalshi market: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"error": "Internal server error"})),
            )
        }
    }
}

/// GET /kalshi/users/{user_id}/account
/// Get user's Kalshi account data (balance, positions)
/// Reads from kalshi_account_cache table (populated by Python ETL)
pub async fn get_kalshi_user_account_handler(
    State(state): State<AppState>,
    Path(user_id): Path<String>,
) -> impl IntoResponse {
    // Try to read from cache table first
    let result = sqlx::query(
        r#"
        SELECT balance_data, positions_data, fetched_at
        FROM kalshi_account_cache
        WHERE user_id = $1
        "#,
    )
    .bind(&user_id)
    .fetch_optional(&state.db_pool)
    .await;
    
    match result {
        Ok(Some(row)) => {
            use sqlx::Row;
            let balance_json: serde_json::Value = row.get("balance_data");
            let positions_json: serde_json::Value = row.get("positions_data");
            let fetched_at: Option<DateTime<Utc>> = row.get("fetched_at");
            
            // Parse balance
            let balance = match serde_json::from_value::<KalshiUserBalance>(balance_json.clone()) {
                Ok(b) => b,
                Err(e) => {
                    error!("Failed to parse balance: {}", e);
                    // Fallback to placeholder
                    KalshiUserBalance {
                        balance: Decimal::ZERO,
                        currency: "USD".to_string(),
                        available_balance: Decimal::ZERO,
                        pending_withdrawals: Decimal::ZERO,
                    }
                }
            };
            
            // Parse positions
            let positions = match serde_json::from_value::<Vec<KalshiPosition>>(positions_json) {
                Ok(p) => p,
                Err(e) => {
                    error!("Failed to parse positions: {}", e);
                    vec![]
                }
            };
            
            let account = KalshiUserAccount {
                balance,
                positions,
                fetched_at,
            };
            
            (StatusCode::OK, Json(account))
        }
        Ok(None) => {
            // No cached data - return placeholder
            info!("No cached account data for user: {}", user_id);
            let account = KalshiUserAccount {
                balance: KalshiUserBalance {
                    balance: Decimal::ZERO,
                    currency: "USD".to_string(),
                    available_balance: Decimal::ZERO,
                    pending_withdrawals: Decimal::ZERO,
                },
                positions: vec![],
                fetched_at: Some(Utc::now()),
            };
            (StatusCode::OK, Json(account))
        }
        Err(e) => {
            error!("Database error fetching account: {}", e);
            // Return placeholder on error
            let account = KalshiUserAccount {
                balance: KalshiUserBalance {
                    balance: Decimal::ZERO,
                    currency: "USD".to_string(),
                    available_balance: Decimal::ZERO,
                    pending_withdrawals: Decimal::ZERO,
                },
                positions: vec![],
                fetched_at: Some(Utc::now()),
            };
            (StatusCode::OK, Json(account))
        }
    }
}

/// GET /kalshi/users/{user_id}/balance
/// Get user's account balance
pub async fn get_kalshi_user_balance_handler(
    State(_state): State<AppState>,
    Path(_user_id): Path<String>,
) -> impl IntoResponse {
    // TODO: Implement actual balance fetching
    let balance = KalshiUserBalance {
        balance: Decimal::ZERO,
        currency: "USD".to_string(),
        available_balance: Decimal::ZERO,
        pending_withdrawals: Decimal::ZERO,
    };

    (StatusCode::OK, Json(balance))
}

/// GET /kalshi/users/{user_id}/positions
/// Get user's portfolio positions
pub async fn get_kalshi_user_positions_handler(
    State(_state): State<AppState>,
    Path(_user_id): Path<String>,
) -> impl IntoResponse {
    // TODO: Implement actual positions fetching
    let positions: Vec<KalshiPosition> = vec![];

    (StatusCode::OK, Json(positions))
}

/// GET /kalshi/users/{user_id}/account/refresh
/// Trigger a refresh of user's account data from Kalshi API
pub async fn refresh_kalshi_user_account_handler(
    State(_state): State<AppState>,
    Path(user_id): Path<String>,
) -> impl IntoResponse {
    use tokio::process::Command;
    
    info!("Refreshing account data for user: {}", user_id);
    
    // Call Python script to refresh account data
    let output = Command::new("docker")
        .args(&[
            "compose",
            "-f", "/Users/thomasplummer/Documents/python/projects/foundry90/capstones/therealtplum/docker-compose.yml",
            "run", "--rm", "etl",
            "python", "-m", "etl.kalshi_refresh_account",
            &user_id,
        ])
        .current_dir("/Users/thomasplummer/Documents/python/projects/foundry90/capstones/therealtplum")
        .output()
        .await;
    
    match output {
        Ok(result) => {
            if result.status.success() {
                let stdout = String::from_utf8_lossy(&result.stdout);
                match serde_json::from_str::<KalshiUserAccount>(&stdout) {
                    Ok(account) => (StatusCode::OK, Json(account)),
                    Err(e) => {
                        error!("Failed to parse refreshed account data: {}", e);
                        error!("Output: {}", stdout);
                        // Return placeholder on parse error
                        let account = KalshiUserAccount {
                            balance: KalshiUserBalance {
                                balance: Decimal::ZERO,
                                currency: "USD".to_string(),
                                available_balance: Decimal::ZERO,
                                pending_withdrawals: Decimal::ZERO,
                            },
                            positions: vec![],
                            fetched_at: Some(Utc::now()),
                        };
                        (StatusCode::OK, Json(account))
                    }
                }
            } else {
                let stderr = String::from_utf8_lossy(&result.stderr);
                error!("Python refresh script failed: {}", stderr);
                // Return placeholder on error
                let account = KalshiUserAccount {
                    balance: KalshiUserBalance {
                        balance: Decimal::ZERO,
                        currency: "USD".to_string(),
                        available_balance: Decimal::ZERO,
                        pending_withdrawals: Decimal::ZERO,
                    },
                    positions: vec![],
                    fetched_at: Some(Utc::now()),
                };
                (StatusCode::OK, Json(account))
            }
        }
        Err(e) => {
            error!("Failed to execute refresh script: {}", e);
            // Return placeholder on error
            let account = KalshiUserAccount {
                balance: KalshiUserBalance {
                    balance: Decimal::ZERO,
                    currency: "USD".to_string(),
                    available_balance: Decimal::ZERO,
                    pending_withdrawals: Decimal::ZERO,
                },
                positions: vec![],
                fetched_at: Some(Utc::now()),
            };
            (StatusCode::OK, Json(account))
        }
    }
}

