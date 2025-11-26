use axum::{extract::State, Json};
use serde::Serialize;
use sqlx::Row;
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
            // This matches the official deadpool-redis example style:
            // cmd("PING").query_async::<String>(&mut conn).await
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
    // ETL status (stubbed for now)
    // --------------------------------------------------
    let last_etl_run_utc = None;
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