use axum::{extract::State, Json};
use serde::Serialize;
use sqlx::query_scalar;
use tracing::error;

use crate::AppState;

#[derive(Serialize)]
pub struct SystemHealth {
    pub api: String,
    pub db: String,
    pub redis: String,
    pub last_etl_run_utc: Option<String>,
    pub etl_status: String,
    pub recent_errors: i32,
}

pub async fn get_system_health(State(state): State<AppState>) -> Json<SystemHealth> {
    // If we’re answering, API is up
    let api = "up".to_string();

    // DB health check (same idea as health_handler in main.rs)
    let db = match query_scalar::<_, i32>("SELECT 1")
        .fetch_one(&state.db_pool)
        .await
    {
        Ok(_) => "up".to_string(),
        Err(err) => {
            error!("DB health check failed in system_health: {err}");
            "down".to_string()
        }
    };

    // Redis not wired yet in AppState, so keep this as a placeholder
    let redis = "unknown".to_string();

    // TODO: wire these to real ETL metadata later
    let last_etl_run_utc = None;
    let etl_status = "idle".to_string();
    let recent_errors = 0;

    Json(SystemHealth {
        api,
        db,
        redis,
        last_etl_run_utc,
        etl_status,
        recent_errors,
    })
}
