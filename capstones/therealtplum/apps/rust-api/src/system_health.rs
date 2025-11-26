use axum::{extract::State, Json};
use serde::Serialize;
use sqlx::{Row, PgPool};
use tracing::{error, info};

use crate::AppState;
use deadpool_redis::redis::cmd;

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

/// Safely derive last_etl_run_utc from instrument_focus_universe.as_of_date.
///
/// This:
/// - never panics
/// - returns None on any error or if the table is empty
/// - logs what it’s doing
async fn get_last_etl_run_utc(pool: &PgPool) -> Option<String> {
    let query = r#"
        SELECT
            to_char(
                MAX(as_of_date),
                'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
            ) AS last_run_utc
        FROM instrument_focus_universe
    "#;

    let result = sqlx::query(query)
        .fetch_optional(pool)
        .await;

    match result {
        Ok(Some(row)) => {
            let val: Result<String, _> = row.try_get("last_run_utc");
            match val {
                Ok(s) if !s.is_empty() => {
                    info!(
                        "Derived last_etl_run_utc from instrument_focus_universe.as_of_date: {}",
                        s
                    );
                    Some(s)
                }
                Ok(_) => {
                    // Empty string from to_char → treat as no ETL info.
                    None
                }
                Err(err) => {
                    error!("Failed to read last_run_utc column: {err}");
                    None
                }
            }
        }
        Ok(None) => {
            // No rows (empty table)
            None
        }
        Err(err) => {
            error!(
                "Failed to fetch last_etl_run_utc from instrument_focus_universe: {err}"
            );
            None
        }
    }
}

pub async fn get_system_health(State(state): State<AppState>) -> Json<SystemHealth> {
    // --------------------------------------------------
    // API status (this handler executed, so API is "up")
    // --------------------------------------------------
    let api = "up".to_string();

    // --------------------------------------------------
    // DB health + table listing
    // --------------------------------------------------
    let db_status = match sqlx::query_scalar::<_, i32>("SELECT 1")
        .fetch_one(&state.db_pool)
        .await
    {
        Ok(_) => "up".to_string(),
        Err(err) => {
            error!("DB health check failed: {err}");
            "down".to_string()
        }
    };

    let mut db_tables: Vec<String> = Vec::new();

    match sqlx::query(
        r#"
        SELECT tablename
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
                .filter_map(|row| row.try_get::<String, _>("tablename").ok())
                .collect();
        }
        Err(err) => {
            error!("Failed to list DB tables: {err}");
        }
    }

    // --------------------------------------------------
    // Redis health via deadpool-redis connection
    // --------------------------------------------------
    let redis_status = match state.redis_pool.get().await {
        Ok(mut conn) => {
            match cmd("PING").query_async::<String>(&mut conn).await {
                Ok(reply) => {
                    info!("Redis PING reply: {reply}");
                    "up".to_string()
                }
                Err(err) => {
                    error!("Redis PING failed: {err}");
                    "down".to_string()
                }
            }
        }
        Err(err) => {
            error!("Failed to get Redis connection from pool: {err}");
            "down".to_string()
        }
    };

    // --------------------------------------------------
    // ETL status + last run (best-effort)
    // --------------------------------------------------
    let last_etl_run_utc = get_last_etl_run_utc(&state.db_pool).await;

    // v1: just expose "idle" plus a last-run timestamp inferred from DB.
    let etl_status = "idle".to_string();
    let recent_errors = 0;

    Json(SystemHealth {
        api,
        db: db_status,
        redis: redis_status,
        last_etl_run_utc,
        etl_status,
        recent_errors,
        db_tables,
    })
}