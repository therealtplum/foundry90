mod coordinator;
mod engine;
mod gateway;
mod ingest;
mod normalize;
mod recorder;
mod router;
mod schemas;
mod strategies;

use anyhow::Result;
use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Json, Router as AxumRouter,
};
use coordinator::Coordinator;
use engine::Engine;
use gateway::Gateway;
use ingest::IngestManager;
use normalize::Normalizer;
use recorder::Recorder;
use router::Router;
use serde::Serialize;
use sqlx::PgPool;
use std::{env, net::SocketAddr};
use tokio::net::TcpListener;
use tokio::sync::mpsc;
use tracing::{info, warn};
use tracing_subscriber::{fmt, EnvFilter, prelude::*};

/// Shared application state for health endpoint
#[derive(Clone)]
struct AppState {
    db_pool: PgPool,
}

#[derive(Serialize)]
struct HealthResponse {
    status: String,
    db_ok: bool,
    service: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,hadron=debug".into()),
        )
        .with(fmt::layer())
        .init();

    dotenvy::dotenv().ok();

    info!("🚀 Hadron Real-Time Intelligence System starting...");

    // Connect to Postgres
    let default_db_url = "postgres://app:app@localhost:5433/fmhub".to_string();
    let database_url = env::var("DATABASE_URL").unwrap_or(default_db_url);

    info!("Connecting to Postgres at {}...", database_url);
    let db_pool = PgPool::connect(&database_url).await?;
    info!("Connected to Postgres");

    // Create channels for pipeline
    let (raw_tx, raw_rx) = mpsc::channel::<schemas::RawEvent>(10000);
    
    // Use broadcast channel for ticks so both router and recorder can receive
    let (tick_tx, _) = tokio::sync::broadcast::channel::<schemas::HadronTick>(10000);
    let tick_rx_router = tick_tx.subscribe();
    let tick_rx_recorder = tick_tx.subscribe();
    
    let (fast_tx, fast_rx) = mpsc::channel::<schemas::HadronTick>(10000);
    let (warm_tx, warm_rx) = mpsc::channel::<schemas::HadronTick>(1000);
    let (cold_tx, cold_rx) = mpsc::channel::<schemas::HadronTick>(100);
    let (decision_tx, decision_rx) = mpsc::channel::<schemas::StrategyDecision>(1000);
    let (order_intent_tx, order_intent_rx) = mpsc::channel::<schemas::OrderIntent>(1000);
    let (execution_tx, execution_rx) = mpsc::channel::<schemas::OrderExecution>(1000);

    // Spawn pipeline components
    let db_pool_ingest = db_pool.clone();
    let db_pool_recorder = db_pool.clone();
    let db_pool_gateway = db_pool.clone();

    // Ingest - Polygon WebSocket
    // NOTE: Polygon allows only 1 concurrent WebSocket connection per asset class
    // Multiple connections will result in "max_connections" errors
    // For now, use only the first API key. Future: implement connection pooling/rotation
    let api_keys = ingest::IngestManager::get_api_keys();
    info!("Found {} Polygon API key(s)", api_keys.len());
    
    if api_keys.is_empty() {
        warn!("No Polygon API keys found. Hadron will not be able to ingest Polygon data.");
    } else {
        // Polygon limitation: only 1 concurrent WebSocket connection per asset class
        // Use only the first API key to avoid "max_connections" errors
        // TODO: Implement connection pooling/rotation for multiple keys
        let api_key = api_keys[0].clone();
        let connection_id = "polygon_default".to_string();
        
        info!("Spawning Polygon ingest connection: {} (Polygon allows only 1 concurrent connection per asset class)", connection_id);
        let raw_tx_clone = raw_tx.clone();
        tokio::spawn(async move {
            let ingest_manager = ingest::IngestManager::with_api_key(
                raw_tx_clone,
                api_key,
                connection_id.clone(),
            );
            if let Err(e) = ingest_manager.start().await {
                warn!("[{}] Polygon ingest manager error: {}", connection_id, e);
            }
        });
        
        if api_keys.len() > 1 {
            warn!("Multiple Polygon API keys found ({}), but only using the first one due to Polygon's 1-connection-per-asset-class limitation. Consider implementing connection pooling/rotation.", api_keys.len());
        }
    }

    // Ingest - Kalshi WebSocket
    // Kalshi supports multiple connections, so we can use all available keys
    let kalshi_keys = ingest::KalshiIngestManager::get_api_keys();
    info!("Found {} Kalshi API key(s)", kalshi_keys.len());
    
    if kalshi_keys.is_empty() {
        warn!("No Kalshi API keys found. Hadron will not be able to ingest Kalshi data.");
    } else {
        // Spawn a Kalshi ingest manager for each API key
        for (idx, (api_key, private_key_path)) in kalshi_keys.iter().enumerate() {
            let connection_id = format!("kalshi_{}", idx + 1);
            let raw_tx_clone = raw_tx.clone();
            let api_key_clone = api_key.clone();
            let key_path_clone = private_key_path.clone();
            
            info!("Spawning Kalshi ingest connection: {}", connection_id);
            tokio::spawn(async move {
                let kalshi_manager = ingest::KalshiIngestManager::new(
                    raw_tx_clone,
                    api_key_clone,
                    key_path_clone,
                    connection_id.clone(),
                );
                if let Err(e) = kalshi_manager.start().await {
                    warn!("[{}] Kalshi ingest manager error: {}", connection_id, e);
                }
            });
        }
    }

    // Normalize - needs to send to broadcast channel
    let tick_tx_normalize = tick_tx.clone();
    let mut normalizer = Normalizer::new(db_pool_ingest, raw_rx, tick_tx_normalize);
    tokio::spawn(async move {
        if let Err(e) = normalizer.run().await {
            warn!("Normalizer error: {}", e);
        }
    });

    // Router - receives from broadcast channel
    let mut router = Router::new(tick_rx_router, fast_tx, warm_tx, cold_tx);
    tokio::spawn(async move {
        if let Err(e) = router.run().await {
            warn!("Router error: {}", e);
        }
    });

    // Engine (single shard for Phase 1)
    let strategy: Box<dyn strategies::Strategy + Send> =
        Box::new(strategies::SimpleSMAStrategy::new());
    let mut engine = Engine::new(0, fast_rx, warm_rx, cold_rx, decision_tx, strategy);
    tokio::spawn(async move {
        if let Err(e) = engine.run().await {
            warn!("Engine error: {}", e);
        }
    });

    // Coordinator
    let mut coordinator = Coordinator::new(decision_rx, order_intent_tx);
    tokio::spawn(async move {
        if let Err(e) = coordinator.run().await {
            warn!("Coordinator error: {}", e);
        }
    });

    // Gateway
    let mut gateway = Gateway::new(order_intent_rx, execution_tx, db_pool_gateway);
    tokio::spawn(async move {
        if let Err(e) = gateway.run().await {
            warn!("Gateway error: {}", e);
        }
    });

    // Recorder - receives from broadcast channel
    let mut recorder = Recorder::new(tick_rx_recorder, execution_rx, db_pool_recorder);
    tokio::spawn(async move {
        if let Err(e) = recorder.run().await {
            warn!("Recorder error: {}", e);
        }
    });

    // Health endpoint
    let state = AppState { db_pool: db_pool.clone() };
    let app = AxumRouter::new()
        .route("/system/health", get(health_handler))
        .with_state(state);

    let port: u16 = env::var("PORT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(3002); // Different port from rust-api

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = TcpListener::bind(addr).await?;
    info!("📡 Hadron health endpoint listening on http://{}", listener.local_addr()?);

    info!("✅ Hadron pipeline started");

    axum::serve(listener, app).await?;

    Ok(())
}

async fn health_handler(State(state): State<AppState>) -> impl IntoResponse {
    let db_ok = match sqlx::query_scalar::<_, i32>("SELECT 1")
        .fetch_one(&state.db_pool)
        .await
    {
        Ok(_) => true,
        Err(_) => false,
    };

    let body = HealthResponse {
        status: if db_ok { "ok".to_string() } else { "degraded".to_string() },
        db_ok,
        service: "hadron".to_string(),
    };

    let status = if db_ok {
        StatusCode::OK
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    };

    (status, Json(body))
}

