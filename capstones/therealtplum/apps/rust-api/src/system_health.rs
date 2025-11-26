use axum::{extract::State, Json};
use serde::Serialize;
use sqlx::{Row}; // <-- important: Row trait
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
    pub db_tables: Vec<String>,
}

pub async fn get_system_health(State(state): State<AppState>) -> Json<SystemHealth> {
    // API is "up" if this handler is reachable
    let api = "up".to_string();

    // ----- DB liveness: runtime query (no macros) -----
    let db_ok = sqlx::query("SELECT 1")
        .fetch_one(&state.db_pool)
        .await
        .is_ok();

    let db = if db_ok {
        "up".to_string()
    } else {
        "down".to_string()
    };

    // ----- DB tables: runtime query (no macros) -----
    let mut db_tables: Vec<String> = Vec::new();

    if db_ok {
        match sqlx::query(
            r#"
            SELECT tablename::TEXT AS name
            FROM pg_tables
            WHERE schemaname = 'public'
            ORDER BY tablename
            "#,
        )
        .fetch_all(&state.db_pool)
        .await
        {
            Ok(rows) => {
                db_tables = rows
                    .into_iter()
                    .filter_map(|row| row.try_get::<String, _>("name").ok())
                    .collect();
            }
            Err(err) => {
                error!(error = ?err, "failed to fetch db tables");
            }
        }
    }

    // TODO: wire these to real ETL metadata later
    let last_etl_run_utc = None;
    let etl_status = "idle".to_string();
    let recent_errors = 0;
    let redis = "unknown".to_string();

    Json(SystemHealth {
        api,
        db,
        redis,
        last_etl_run_utc,
        etl_status,
        recent_errors,
        db_tables,
    })
}