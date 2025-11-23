use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use serde::Serialize;
use sqlx::PgPool;
use std::{env, net::SocketAddr};
use tokio::net::TcpListener;
use tracing::{error, info};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[derive(Clone)]
struct AppState {
    db_pool: PgPool,
}

#[derive(Serialize)]
struct HealthResponse {
    status: String,
    db_ok: bool,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Logging
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,tower_http=info,sqlx=warn".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    dotenvy::dotenv().ok();

    // Default for local dev (when running `cargo run`):
    // DB is exposed on host port 5433 (mapped from container's 5432)
    let default_db_url = "postgres://app:app@localhost:5433/fmhub".to_string();
    let database_url = env::var("DATABASE_URL").unwrap_or(default_db_url);

    info!("Connecting to Postgres at {database_url}…");
    let db_pool = PgPool::connect(&database_url).await?;
    info!("Connected to Postgres");

    let state = AppState { db_pool };

    let app = Router::new()
        .route("/health", get(health_handler))
        .with_state(state);

    let port: u16 = env::var("PORT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(3000);

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = TcpListener::bind(addr).await?;
    info!("🚀 fmhub-api listening on http://{}", listener.local_addr()?);

    axum::serve(listener, app).await?;

    Ok(())
}

async fn health_handler(State(state): State<AppState>) -> impl IntoResponse {
    let db_ok = match sqlx::query_scalar::<_, i64>("SELECT 1::BIGINT")
        .fetch_one(&state.db_pool)
        .await
    {
        Ok(_) => true,
        Err(err) => {
            error!("DB health check failed: {err}");
            false
        }
    };

    let body = HealthResponse {
        status: "ok".to_string(),
        db_ok,
    };

    let status = if db_ok {
        StatusCode::OK
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    };

    (status, Json(body))
}