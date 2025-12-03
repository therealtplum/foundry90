use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use serde_json::json;
use sqlx::{FromRow, PgPool};
use std::{env, net::SocketAddr, sync::Arc};
use tokio::net::TcpListener;
use tower_http::cors::{Any, CorsLayer};
use tracing::{error, info};
use tracing_subscriber::prelude::*;
use tracing_subscriber::{fmt, EnvFilter};

mod system_health;
mod kalshi;
mod fred;
mod env_config;

use deadpool_redis::{Config as RedisConfig, Pool as RedisPool};
use deadpool_redis::redis::AsyncCommands;
use env_config::{EnvConfig, HealthResponse, ComingSoonResponse};

/// Shared application state
#[derive(Clone)]
pub struct AppState {
    pub db_pool: PgPool,
    pub redis_pool: RedisPool,
    pub(crate) chat_client: Option<ChatClient>,
    pub env_config: EnvConfig,
}


/// Lightweight instrument listing DTO
#[derive(Debug, Serialize, FromRow)]
struct InstrumentSummary {
    id: i64,
    ticker: String,
    name: String,
    asset_class: String,
}

/// More detailed instrument view
#[derive(Debug, Serialize, FromRow)]
struct InstrumentDetail {
    id: i64,
    ticker: String,
    name: String,
    asset_class: String,
    exchange: Option<String>,
    currency_code: String,
    region: Option<String>,
    country_code: Option<String>,
    primary_source: String,
    status: String,
}

/// News article DTO for API responses
#[derive(Debug, Serialize, FromRow)]
struct NewsArticleDto {
    id: i64,
    source: String,
    publisher: Option<String>,
    headline: String,
    summary: Option<String>,
    url: String,
    published_at: DateTime<Utc>,
}

/// Instrument insight record from DB (and for Redis cache)
#[derive(Debug, Serialize, Deserialize, FromRow)]
struct InstrumentInsightRecord {
    id: i64,
    content_markdown: String,
    model_name: Option<String>,
    created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
struct ListInstrumentsParams {
    limit: Option<i64>,
    offset: Option<i64>,
}

#[derive(Debug, Deserialize)]
struct ListNewsParams {
    limit: Option<i64>,
    offset: Option<i64>,
}

#[derive(Debug, Deserialize)]
struct InsightQueryParams {
    horizon_days: Option<i32>,
}

// --- Focus ticker strip model ---

#[derive(Debug, Serialize, Deserialize, FromRow)]
struct FocusTickerStripRow {
    instrument_id: i64,
    ticker: String,
    name: String,
    asset_class: String,
    last_close_price: Option<Decimal>,
    short_insight: Option<String>,
    recent_insight: Option<String>,
}

#[derive(Debug, Deserialize)]
struct FocusStripParams {
    limit: Option<i64>,
}

#[derive(Debug, Deserialize)]
struct FocusMarketDataParams {
    limit: Option<i64>,
    days: Option<i32>, // Number of days of history to fetch (default: 30)
}

/// Price data point for market charts
#[derive(Debug, Serialize, FromRow)]
struct PriceDataPoint {
    instrument_id: i64,
    ticker: String,
    name: String,
    price_date: chrono::NaiveDate,
    open: Option<Decimal>,
    high: Option<Decimal>,
    low: Option<Decimal>,
    close: Option<Decimal>,
    volume: Option<Decimal>,
}

// ---------------------------------------------------------------------
// OpenAI chat client
// ---------------------------------------------------------------------

#[derive(Clone)]
struct ChatClient {
    http: Arc<reqwest::Client>,
    api_key: String,
    model: String,
}

#[derive(Debug, Deserialize)]
struct ChatResponse {
    choices: Vec<ChatChoice>,
}

#[derive(Debug, Deserialize)]
struct ChatChoice {
    message: ChatMessage,
}

#[derive(Debug, Deserialize)]
struct ChatMessage {
    content: String,
}

impl ChatClient {
    fn from_env() -> Option<Self> {
        let api_key = env::var("OPENAI_API_KEY").ok()?;
        let model = env::var("OPENAI_MODEL").unwrap_or_else(|_| "gpt-4o-mini".to_string());

        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(60))
            .build()
            .expect("failed to build reqwest client");

        Some(ChatClient {
            http: Arc::new(http),
            api_key,
            model,
        })
    }

    async fn generate_insight(
        &self,
        instrument: &InstrumentDetail,
        kind: &str,
        horizon_days: i32,
        db_pool: &PgPool,
    ) -> anyhow::Result<String> {
        eprintln!("🚨🚨🚨 generate_insight CALLED: instrument_id={}, ticker={}, kind={}, horizon_days={} 🚨🚨🚨", instrument.id, instrument.ticker, kind, horizon_days);
        info!(
            "generate_insight called: instrument_id={}, ticker={}, kind={}, horizon_days={}",
            instrument.id, instrument.ticker, kind, horizon_days
        );
        
        let system = match kind {
            "overview" => "You are a financial research assistant. Produce a concise overview of the instrument, including what it is, key characteristics, and why it might be interesting to an event-driven trader.",
            "recent" => "You are a financial research assistant. Your task is to summarize recent developments for this instrument. CRITICAL: If recent news articles are provided in the user's message, you MUST use those articles as the PRIMARY source for your summary. Reference specific headlines, dates, and key details from the provided news articles. Do not make up or reference information that is not in the provided news articles.",
            _ => "You are a financial research assistant. Provide concise, relevant information about the instrument.",
        };

        // Fetch recent news articles for this instrument
        info!(
            "🔍 Fetching news for instrument_id={}, horizon_days={}, db_pool={:p}",
            instrument.id, horizon_days, db_pool as *const _
        );
        let news_query_result = sqlx::query_as::<_, NewsArticleDto>(
            r#"
            SELECT
                id,
                source,
                publisher,
                headline,
                summary,
                url,
                published_at
            FROM news_articles
            WHERE instrument_id = $1
              AND published_at >= NOW() - INTERVAL '1 day' * $2
            ORDER BY published_at DESC
            LIMIT 10
            "#,
        )
        .bind(instrument.id)
        .bind(horizon_days);
        
        eprintln!("🚨🚨🚨 EXECUTING NEWS QUERY: instrument_id={}, horizon_days={} 🚨🚨🚨", instrument.id, horizon_days);
        info!("🔍 Executing news query with instrument_id={}, horizon_days={}", instrument.id, horizon_days);
        let news_context = match news_query_result
        .fetch_all(db_pool)
        .await
        {
            Ok(articles) if !articles.is_empty() => {
                eprintln!("🚨🚨🚨 FOUND {} NEWS ARTICLES for instrument_id={} 🚨🚨🚨", articles.len(), instrument.id);
                info!(
                    "Found {} news articles for instrument_id={}, kind={}",
                    articles.len(),
                    instrument.id,
                    kind
                );
                let mut news_text = String::from("\n\n=== RECENT NEWS ARTICLES (USE THESE AS YOUR PRIMARY SOURCE) ===\n");
                for (idx, article) in articles.iter().take(5).enumerate() {
                    news_text.push_str(&format!(
                        "\n**Article {}: {}**\nPublished by: {}\nSummary: {}\n",
                        idx + 1,
                        article.headline,
                        article
                            .publisher
                            .as_ref()
                            .map(|s| s.as_str())
                            .unwrap_or("Unknown"),
                        article
                            .summary
                            .as_ref()
                            .map(|s| s.as_str())
                            .unwrap_or("No summary")
                    ));
                }
                news_text.push_str("\n=== END OF NEWS ARTICLES ===\n");
                news_text.push_str("\nINSTRUCTIONS: Base your recent insights summary primarily on the news articles above. Reference specific headlines, dates, and developments from these articles. Do not include information that is not mentioned in these articles.\n");
                news_text
            }
            Ok(_) => {
                info!(
                    "No news articles found for instrument_id={}, kind={}",
                    instrument.id, kind
                );
                String::new()
            }
            Err(e) => {
                error!(
                    "Failed to fetch news for instrument_id={}, kind={}: {}",
                    instrument.id, kind, e
                );
                String::new()
            }
        };

        eprintln!("🚨🚨🚨 NEWS CONTEXT: length={}, is_empty={} 🚨🚨🚨", news_context.len(), news_context.is_empty());
        if !news_context.is_empty() {
            eprintln!("🚨🚨🚨 NEWS CONTEXT PREVIEW (first 500 chars): {} 🚨🚨🚨", &news_context[..news_context.len().min(500)]);
        } else {
            eprintln!("🚨🚨🚨 WARNING: NEWS CONTEXT IS EMPTY! 🚨🚨🚨");
        }
        info!(
            "News context length: {} chars, is_empty: {}",
            news_context.len(),
            news_context.is_empty()
        );
        if !news_context.is_empty() {
            info!("News context preview: {}", &news_context[..news_context.len().min(200)]);
        }
        
        let prompt = if !news_context.is_empty() {
            format!(
                "Instrument: {name} ({ticker})\n\
                 Asset class: {asset_class}\n\
                 Exchange: {exchange}\n\
                 Region: {region:?}\n\
                 Country: {country:?}\n\
                 Horizon: last {horizon_days} days\n\
                 {news_context}\n\n\
                 TASK: Write a short, focused recent insights summary based on the news articles provided above. \
                 Use markdown, keep it under ~300 words. \
                 IMPORTANT: Your summary must be based primarily on the news articles provided. Reference specific headlines and key developments from those articles.",
                name = instrument.name,
                ticker = instrument.ticker,
                asset_class = instrument.asset_class,
                exchange = instrument
                    .exchange
                    .clone()
                    .unwrap_or_else(|| "UNKNOWN".to_string()),
                region = instrument.region,
                country = instrument.country_code,
                news_context = news_context,
            )
        } else {
            format!(
                "Instrument: {name} ({ticker})\n\
                 Asset class: {asset_class}\n\
                 Exchange: {exchange}\n\
                 Region: {region:?}\n\
                 Country: {country:?}\n\
                 Horizon: last {horizon_days} days\n\n\
                 Write a short, focused {kind} insight, suitable for a dashboard. \
                 Use markdown, keep it under ~300 words, and avoid fluff.",
                name = instrument.name,
                ticker = instrument.ticker,
                asset_class = instrument.asset_class,
                exchange = instrument
                    .exchange
                    .clone()
                    .unwrap_or_else(|| "UNKNOWN".to_string()),
                region = instrument.region,
                country = instrument.country_code,
                kind = kind,
            )
        };

        let body = json!({
            "model": self.model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": prompt}
            ],
            "max_tokens": 500,
            "temperature": 0.3
        });

        let resp = self
            .http
            .post("https://api.openai.com/v1/chat/completions")
            .bearer_auth(&self.api_key)
            .json(&body)
            .send()
            .await?
            .error_for_status()?
            .json::<ChatResponse>()
            .await?;

        let text = resp
            .choices
            .into_iter()
            .next()
            .map(|c| c.message.content)
            .unwrap_or_else(|| "No response from model.".to_string());

        Ok(text)
    }
}

// ---------------------------------------------------------------------
// main
// ---------------------------------------------------------------------

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,tower_http=info,sqlx=warn".into()),
        )
        .with(fmt::layer())
        .init();

    // Try to load .env from project root (parent directory)
    // First try current directory, then parent directory
    let mut env_loaded = dotenvy::dotenv().is_ok();
    if !env_loaded {
        // If not found in current dir, try parent directory (project root)
        let parent_env = std::path::Path::new("../.env");
        let grandparent_env = std::path::Path::new("../../.env");
        if parent_env.exists() {
            match dotenvy::from_path(parent_env) {
                Ok(_) => {
                    info!("Loaded .env from ../.env");
                    env_loaded = true;
                }
                Err(e) => info!("Failed to load .env from ../.env: {}", e),
            }
        }
        if !env_loaded && grandparent_env.exists() {
            match dotenvy::from_path(grandparent_env) {
                Ok(_) => {
                    info!("Loaded .env from ../../.env");
                    env_loaded = true;
                }
                Err(e) => info!("Failed to load .env from ../../.env: {}", e),
            }
        }
        if !env_loaded {
            info!("No .env file found in current, parent, or grandparent directory");
        }
    }

    // Redis
    let redis_url = env::var("REDIS_URL")
        .unwrap_or_else(|_| "redis://127.0.0.1:6379".to_string());

    let mut redis_cfg = RedisConfig::default();
    redis_cfg.url = Some(redis_url);
    redis_cfg.connection = None;

    let redis_pool = redis_cfg
        .create_pool(Some(deadpool_redis::Runtime::Tokio1))
        .expect("Failed to create Redis pool");

    // Postgres
    let default_db_url = "postgres://app:app@localhost:5433/fmhub".to_string();
    let database_url = env::var("DATABASE_URL").unwrap_or(default_db_url);

    info!("Connecting to Postgres at {database_url}…");
    let db_pool = PgPool::connect(&database_url).await?;
    info!("Connected to Postgres");

    let chat_client = ChatClient::from_env();
    if chat_client.is_none() {
        info!("OPENAI_API_KEY not set; insight generation will fall back to cache-only.");
    }

    let env_config = EnvConfig::from_env();
    info!(
        "Environment config: env={}, version={}, commit={}",
        env_config.env, env_config.api_version, env_config.commit_sha
    );

    let state = AppState {
        db_pool,
        redis_pool,
        chat_client,
        env_config: env_config.clone(),
    };

    // CORS
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // Versioned API routes - catch-all for any path under /v1 or /v1-staged
    // Handle both empty path (just /v1 or /v1-staged) and paths with content
    let v1_routes = Router::new()
        .route("/", get(coming_soon_v1_root_handler))
        .route("/{*path}", get(coming_soon_v1_handler))
        .with_state(state.clone());

    let v1_staged_routes = Router::new()
        .route("/", get(coming_soon_v1_staged_root_handler))
        .route("/{*path}", get(coming_soon_v1_staged_handler))
        .with_state(state.clone());

    let app = Router::new()
        .route("/health", get(health_handler))
        .route("/system/health", get(system_health::get_system_health))
        // Versioned API routes
        .nest("/v1", v1_routes)
        .nest("/v1-staged", v1_staged_routes)
        // Legacy routes (keep for backward compatibility during migration)
        .route("/instruments", get(list_instruments_handler))
        .route("/instruments/{id}", get(get_instrument_handler))
        .route("/instruments/{id}/news", get(list_instrument_news_handler))
        .route(
            "/instruments/{id}/insights/{kind}",
            get(get_instrument_insight_handler),
        )
        .route("/focus/ticker-strip", get(get_focus_ticker_strip))
        .route("/focus/market-data", get(get_focus_market_data_handler))
        .route("/market/status", get(get_market_status_handler))
        // Kalshi endpoints
        .route("/kalshi/markets", get(kalshi::list_kalshi_markets_handler))
        .route("/kalshi/markets/{ticker}", get(kalshi::get_kalshi_market_handler))
        .route("/kalshi/users/{user_id}/account", get(kalshi::get_kalshi_user_account_handler))
        .route("/kalshi/users/{user_id}/balance", get(kalshi::get_kalshi_user_balance_handler))
        .route("/kalshi/users/{user_id}/positions", get(kalshi::get_kalshi_user_positions_handler))
        // FRED endpoints
        .route("/fred/releases/upcoming", get(fred::get_upcoming_releases_handler))
        .with_state(state)
        .layer(cors);

    let port: u16 = env::var("PORT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(3000);

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = TcpListener::bind(addr).await?;
    info!(
        "🚀 fmhub-api listening on http://{}",
        listener.local_addr()?
    );

    axum::serve(listener, app).await?;

    Ok(())
}

// ---------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------

async fn health_handler(State(state): State<AppState>) -> impl IntoResponse {
    let config = &state.env_config;
    let timestamp = chrono::Utc::now().to_rfc3339();

    // Check database connectivity
    let db_ok = match sqlx::query_scalar::<_, i32>("SELECT 1")
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
        env: config.env.clone(),
        status: "ok".to_string(),
        version: config.api_version.clone(),
        message: config.health_message(),
        commit: config.commit_sha.clone(),
        timestamp,
        db_ok,
        preview_versions: config.preview_versions(),
    };

    (StatusCode::OK, Json(body))
}

/// Handler for /v1 root route
async fn coming_soon_v1_root_handler(State(state): State<AppState>) -> impl IntoResponse {
    let config = &state.env_config;
    let route = "/v1".to_string();

    let body = ComingSoonResponse {
        env: config.env.clone(),
        status: "coming_soon".to_string(),
        route,
        message: "Endpoint defined but not yet implemented.".to_string(),
    };

    (StatusCode::NOT_IMPLEMENTED, Json(body))
}

/// Catch-all handler for /v1/* routes that aren't yet implemented
async fn coming_soon_v1_handler(
    State(state): State<AppState>,
    Path(path): Path<String>,
) -> impl IntoResponse {
    let config = &state.env_config;
    let route = format!("/v1/{}", path);

    let body = ComingSoonResponse {
        env: config.env.clone(),
        status: "coming_soon".to_string(),
        route,
        message: "Endpoint defined but not yet implemented.".to_string(),
    };

    (StatusCode::NOT_IMPLEMENTED, Json(body))
}

/// Handler for /v1-staged root route
async fn coming_soon_v1_staged_root_handler(State(state): State<AppState>) -> impl IntoResponse {
    let config = &state.env_config;
    let route = "/v1-staged".to_string();

    let body = ComingSoonResponse {
        env: config.env.clone(),
        status: "coming_soon".to_string(),
        route,
        message: "Endpoint defined but not yet implemented.".to_string(),
    };

    (StatusCode::NOT_IMPLEMENTED, Json(body))
}

/// Catch-all handler for /v1-staged/* routes that aren't yet implemented
async fn coming_soon_v1_staged_handler(
    State(state): State<AppState>,
    Path(path): Path<String>,
) -> impl IntoResponse {
    let config = &state.env_config;
    let route = format!("/v1-staged/{}", path);

    let body = ComingSoonResponse {
        env: config.env.clone(),
        status: "coming_soon".to_string(),
        route,
        message: "Endpoint defined but not yet implemented.".to_string(),
    };

    (StatusCode::NOT_IMPLEMENTED, Json(body))
}

async fn list_instruments_handler(
    State(state): State<AppState>,
    Query(params): Query<ListInstrumentsParams>,
) -> impl IntoResponse {
    let limit = params.limit.unwrap_or(100).clamp(1, 1_000);
    let offset = params.offset.unwrap_or(0).max(0);

    let result = sqlx::query_as::<_, InstrumentSummary>(
        r#"
        SELECT
            id,
            ticker,
            name,
            asset_class::text AS asset_class
        FROM instruments
        WHERE status = 'active'
        ORDER BY ticker
        LIMIT $1
        OFFSET $2
        "#,
    )
    .bind(limit)
    .bind(offset)
    .fetch_all(&state.db_pool)
    .await;

    match result {
        Ok(rows) => (StatusCode::OK, Json(rows)),
        Err(err) => {
            error!("Failed to list instruments: {err}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(Vec::<InstrumentSummary>::new()),
            )
        }
    }
}

async fn get_instrument_handler(
    State(state): State<AppState>,
    Path(id): Path<i64>,
) -> impl IntoResponse {
    let result = sqlx::query_as::<_, InstrumentDetail>(
        r#"
        SELECT
            id,
            ticker,
            name,
            asset_class::text AS asset_class,
            exchange,
            currency_code,
            region,
            country_code,
            primary_source,
            status::text AS status
        FROM instruments
        WHERE id = $1
        "#,
    )
    .bind(id)
    .fetch_optional(&state.db_pool)
    .await;

    match result {
        Ok(Some(instr)) => (StatusCode::OK, Json(json!(instr))),
        Ok(None) => (StatusCode::NOT_FOUND, Json(json!({"error": "not_found"}))),
        Err(err) => {
            error!("Failed to fetch instrument {id}: {err}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": "internal_error"})),
            )
        }
    }
}

async fn list_instrument_news_handler(
    State(state): State<AppState>,
    Path(id): Path<i64>,
    Query(params): Query<ListNewsParams>,
) -> impl IntoResponse {
    let limit = params.limit.unwrap_or(50).clamp(1, 500);
    let offset = params.offset.unwrap_or(0).max(0);

    let result = sqlx::query_as::<_, NewsArticleDto>(
        r#"
        SELECT
            id,
            source,
            publisher,
            headline,
            summary,
            url,
            published_at
        FROM news_articles
        WHERE instrument_id = $1
        ORDER BY published_at DESC
        LIMIT $2
        OFFSET $3
        "#,
    )
    .bind(id)
    .bind(limit)
    .bind(offset)
    .fetch_all(&state.db_pool)
    .await;

    match result {
        Ok(rows) => (StatusCode::OK, Json(rows)),
        Err(err) => {
            error!("Failed to list news for instrument {id}: {err}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(Vec::<NewsArticleDto>::new()),
            )
        }
    }
}

/// LLM insight handler with Redis cache + DB + LLM fallback
async fn get_instrument_insight_handler(
    State(state): State<AppState>,
    Path((id, kind)): Path<(i64, String)>,
    Query(params): Query<InsightQueryParams>,
) -> impl IntoResponse {
    let horizon_days = params.horizon_days.unwrap_or(30);
    let kind = kind.to_lowercase();
    let cache_key = format!("instrument_insight:{}:{}", id, kind);
    let ttl_seconds: u64 = 3600;

    // 0. Redis cache
    // Skip Redis cache for "recent" insights to ensure we check for newer news in DB
    if kind != "recent" {
        if let Ok(mut conn) = state.redis_pool.get().await {
            match conn.get::<_, Option<String>>(&cache_key).await {
                Ok(Some(cached)) => {
                    match serde_json::from_str::<InstrumentInsightRecord>(&cached) {
                        Ok(rec) => {
                            info!(
                                "instrument_insight cache hit (key={}, id={}, kind={})",
                                cache_key, id, kind
                            );
                            return (
                                StatusCode::OK,
                                Json(json!({
                                    "source": "cache",
                                    "insight": rec,
                                })),
                            );
                        }
                        Err(err) => {
                            error!(
                                "instrument_insight: failed to deserialize cached value (key={}): {}",
                                cache_key, err
                            );
                        }
                    }
                }
                Ok(None) => {
                    info!(
                        "instrument_insight cache miss (key={}): no value present",
                        cache_key
                    );
                }
                Err(err) => {
                    info!(
                        "instrument_insight cache GET error (key={}): {}",
                        cache_key, err
                    );
                }
            }
        } else {
            error!("instrument_insight: failed to get Redis connection from pool");
        }
    } else {
        info!(
            "Skipping Redis cache for 'recent' insight (instrument_id={}) to check for newer news",
            id
        );
    }

    // 1. DB cache
    let cached_db = sqlx::query_as::<_, InstrumentInsightRecord>(
        r#"
        SELECT
            id,
            content_markdown,
            model_name,
            created_at
        FROM instrument_insights
        WHERE instrument_id = $1
          AND insight_type = $2
        ORDER BY created_at DESC
        LIMIT 1
        "#,
    )
    .bind(id)
    .bind(&kind)
    .fetch_optional(&state.db_pool)
    .await;

    match cached_db {
        Ok(Some(rec)) => {
            // For "recent" insights, check if there's newer news than when the insight was created
            // If so, we should regenerate to include the latest news
            if kind == "recent" {
                let has_newer_news = sqlx::query_scalar::<_, bool>(
                    r#"
                    SELECT EXISTS(
                        SELECT 1
                        FROM news_articles
                        WHERE instrument_id = $1
                          AND published_at > $2
                          AND published_at >= NOW() - INTERVAL '1 day' * $3
                        LIMIT 1
                    )
                    "#,
                )
                .bind(id)
                .bind(rec.created_at)
                .bind(horizon_days)
                .fetch_one(&state.db_pool)
                .await;

                match has_newer_news {
                    Ok(true) => {
                        info!(
                            "Cached 'recent' insight for instrument_id={id} is stale (newer news available); regenerating."
                        );
                        // Fall through to LLM generation
                    }
                    Ok(false) => {
                        // No newer news, use cached insight
                        info!(
                            "Using cached 'recent' insight for instrument_id={id} (no newer news available)."
                        );
                        // best-effort backfill to Redis
                        if let Ok(payload) = serde_json::to_string(&rec) {
                            if let Ok(mut conn) = state.redis_pool.get().await {
                                let _ = conn
                                    .set_ex::<_, _, ()>(&cache_key, payload, ttl_seconds)
                                    .await;
                            }
                        }

                        return (
                            StatusCode::OK,
                            Json(json!({
                                "source": "cache",
                                "insight": rec,
                            })),
                        );
                    }
                    Err(err) => {
                        error!(
                            "Failed to check for newer news for instrument_id={id}: {err}. Proceeding with cache."
                        );
                        // On error, use cached insight
                        if let Ok(payload) = serde_json::to_string(&rec) {
                            if let Ok(mut conn) = state.redis_pool.get().await {
                                let _ = conn
                                    .set_ex::<_, _, ()>(&cache_key, payload, ttl_seconds)
                                    .await;
                            }
                        }

                        return (
                            StatusCode::OK,
                            Json(json!({
                                "source": "cache",
                                "insight": rec,
                            })),
                        );
                    }
                }
            } else {
                // For non-"recent" insights, use cache as normal
                // best-effort backfill to Redis
                if let Ok(payload) = serde_json::to_string(&rec) {
                    if let Ok(mut conn) = state.redis_pool.get().await {
                        let _ = conn
                            .set_ex::<_, _, ()>(&cache_key, payload, ttl_seconds)
                            .await;
                    }
                }

                return (
                    StatusCode::OK,
                    Json(json!({
                        "source": "cache",
                        "insight": rec,
                    })),
                );
            }
        }
        Ok(None) => {
            info!(
                "No cached insight in DB for instrument_id={id}, kind={kind}; attempting LLM generation."
            );
        }
        Err(err) => {
            error!("Failed to query cached insight for {id}, kind={kind}: {err}");
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": "internal_error"})),
            );
        }
    }

    // 2. LLM generation (if configured)
    let chat_client = match &state.chat_client {
        Some(c) => c.clone(),
        None => {
            info!("chat_client not configured; cannot generate new insight.");
            return (
                StatusCode::SERVICE_UNAVAILABLE,
                Json(json!({"error": "llm_unavailable"})),
            );
        }
    };

    // Fetch instrument details for context
    let instrument = match sqlx::query_as::<_, InstrumentDetail>(
        r#"
        SELECT
            id,
            ticker,
            name,
            asset_class::text AS asset_class,
            exchange,
            currency_code,
            region,
            country_code,
            primary_source,
            status::text AS status
        FROM instruments
        WHERE id = $1
        "#,
    )
    .bind(id)
    .fetch_optional(&state.db_pool)
    .await
    {
        Ok(Some(instr)) => instr,
        Ok(None) => {
            return (StatusCode::NOT_FOUND, Json(json!({"error": "not_found"})));
        }
        Err(err) => {
            error!("Failed to fetch instrument for insight generation {id}: {err}");
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": "internal_error"})),
            );
        }
    };

    // Call LLM
    eprintln!("🚨🚨🚨 ABOUT TO CALL generate_insight: instrument_id={}, kind={}, horizon_days={} 🚨🚨🚨", instrument.id, kind, horizon_days);
    info!(
        "About to call generate_insight for instrument_id={}, kind={}, horizon_days={}",
        instrument.id, kind, horizon_days
    );
    let text = match chat_client
        .generate_insight(&instrument, &kind, horizon_days, &state.db_pool)
        .await
    {
        Ok(t) => {
            eprintln!("🚨🚨🚨 generate_insight COMPLETED: instrument_id={}, response_length={} 🚨🚨🚨", instrument.id, t.len());
            info!(
                "generate_insight completed successfully for instrument_id={}, kind={}, response_length={}",
                instrument.id, kind, t.len()
            );
            t
        }
        Err(err) => {
            error!(
                "LLM generation failed for instrument_id={id}, kind={kind}: {err}"
            );
            return (
                StatusCode::BAD_GATEWAY,
                Json(json!({"error": "llm_error"})),
            );
        }
    };

    // Persist new insight to DB
    let model_name = Some(chat_client.model.clone());
    let inserted = sqlx::query_as::<_, InstrumentInsightRecord>(
        r#"
        INSERT INTO instrument_insights (
            instrument_id,
            insight_type,
            content_markdown,
            model_name
        )
        VALUES ($1, $2, $3, $4)
        RETURNING
            id,
            content_markdown,
            model_name,
            created_at
        "#,
    )
    .bind(id)
    .bind(&kind)
    .bind(&text)
    .bind(&model_name)
    .fetch_one(&state.db_pool)
    .await;

    match inserted {
        Ok(rec) => {
            // Best-effort write to Redis
            if let Ok(payload) = serde_json::to_string(&rec) {
                if let Ok(mut conn) = state.redis_pool.get().await {
                    let _ = conn
                        .set_ex::<_, _, ()>(&cache_key, payload, ttl_seconds)
                        .await;
                }
            }

            (
                StatusCode::OK,
                Json(json!({
                    "source": "llm",
                    "insight": rec,
                })),
            )
        }
        Err(err) => {
            error!("Failed to persist generated insight for {id}, kind={kind}: {err}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": "internal_error"})),
            )
        }
    }
}

/// Focus ticker strip with Redis cache
async fn get_focus_ticker_strip(
    State(state): State<AppState>,
    Query(params): Query<FocusStripParams>,
) -> impl IntoResponse {
    let limit = params.limit.unwrap_or(50).clamp(1, 500);
    let cache_key = format!("focus_ticker_strip:limit={}", limit);
    let ttl_seconds: u64 = 60;

    // 1) Try Redis
    if let Ok(mut conn) = state.redis_pool.get().await {
        match conn.get::<_, Option<String>>(&cache_key).await {
            Ok(Some(cached)) => {
                match serde_json::from_str::<Vec<FocusTickerStripRow>>(&cached) {
                    Ok(rows) => {
                        info!(
                            "focus_ticker_strip cache hit (key={}, rows={})",
                            cache_key,
                            rows.len()
                        );
                        return (StatusCode::OK, Json(rows));
                    }
                    Err(err) => {
                        error!(
                            "focus_ticker_strip: failed to deserialize cached value (key={}): {}",
                            cache_key, err
                        );
                    }
                }
            }
            Ok(None) => {
                info!(
                    "focus_ticker_strip cache miss (key={}): no value present",
                    cache_key
                );
            }
            Err(err) => {
                info!(
                    "focus_ticker_strip cache GET error (key={}): {}",
                    cache_key, err
                );
            }
        }
    } else {
        error!("focus_ticker_strip: failed to get Redis connection from pool");
    }

    // 2) DB fallback
    let result = sqlx::query_as::<_, FocusTickerStripRow>(
        r#"
        WITH latest_focus AS (
            SELECT MAX(as_of_date) AS as_of_date
            FROM instrument_focus_universe
        )
        SELECT
            fu.instrument_id,
            i.ticker,
            i.name,
            i.asset_class::text AS asset_class,
            fu.last_close_price,
            overview_insight.content_markdown AS short_insight,
            recent_insight.content_markdown AS recent_insight
        FROM instrument_focus_universe fu
        JOIN latest_focus lf
          ON fu.as_of_date = lf.as_of_date
        JOIN instruments i
          ON i.id = fu.instrument_id
        LEFT JOIN LATERAL (
            SELECT content_markdown
            FROM instrument_insights ii
            WHERE ii.instrument_id = fu.instrument_id
              AND ii.insight_type = 'overview'
            ORDER BY ii.created_at DESC
            LIMIT 1
        ) AS overview_insight ON TRUE
        LEFT JOIN LATERAL (
            SELECT content_markdown
            FROM instrument_insights ii
            WHERE ii.instrument_id = fu.instrument_id
              AND ii.insight_type = 'recent'
            ORDER BY ii.created_at DESC
            LIMIT 1
        ) AS recent_insight ON TRUE
        ORDER BY fu.activity_rank_global ASC
        LIMIT $1
        "#,
    )
    .bind(limit)
    .fetch_all(&state.db_pool)
    .await;

    match result {
        Ok(rows) => {
            // 3) Write-through to Redis
            if let Ok(payload) = serde_json::to_string(&rows) {
                if let Ok(mut conn) = state.redis_pool.get().await {
                    match conn
                        .set_ex::<_, _, ()>(&cache_key, payload, ttl_seconds)
                        .await
                    {
                        Ok(()) => {
                            info!(
                                "focus_ticker_strip cache set (key={}, ttl={}s, rows={})",
                                cache_key,
                                ttl_seconds,
                                rows.len()
                            );
                        }
                        Err(err) => {
                            error!(
                                "focus_ticker_strip cache SET error (key={}): {}",
                                cache_key, err
                            );
                        }
                    }
                } else {
                    error!(
                        "focus_ticker_strip: failed to get Redis connection from pool for SET"
                    );
                }
            }

            (StatusCode::OK, Json(rows))
        }
        Err(err) => {
            error!("Failed to fetch focus ticker strip: {err}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(Vec::<FocusTickerStripRow>::new()),
            )
        }
    }
}

/// Get market data (price history) for focus instruments
async fn get_focus_market_data_handler(
    State(state): State<AppState>,
    Query(params): Query<FocusMarketDataParams>,
) -> impl IntoResponse {
    let limit = params.limit.unwrap_or(20).clamp(1, 100);
    let days = params.days.unwrap_or(30).clamp(1, 365);

    // Calculate start date
    let start_date = chrono::Utc::now().date_naive() - chrono::Duration::days(days as i64);

    let result = sqlx::query_as::<_, PriceDataPoint>(
        r#"
        WITH latest_focus AS (
            SELECT as_of_date
            FROM instrument_focus_universe
            GROUP BY as_of_date
            HAVING COUNT(*) >= 500
            ORDER BY as_of_date DESC
            LIMIT 1
        ),
        focus_instruments AS (
            SELECT fu.instrument_id
            FROM instrument_focus_universe fu
            JOIN latest_focus lf ON fu.as_of_date = lf.as_of_date
            ORDER BY fu.activity_rank_global ASC
            LIMIT $1
        )
        SELECT
            i.id AS instrument_id,
            i.ticker,
            i.name,
            p.price_date,
            p.open,
            p.high,
            p.low,
            p.close,
            p.volume
        FROM focus_instruments fi
        JOIN instruments i ON i.id = fi.instrument_id
        JOIN instrument_price_daily p ON p.instrument_id = i.id
        WHERE p.price_date >= $2
          AND p.data_source IN ('polygon_prev', 'polygon_historical')
        ORDER BY i.ticker, p.price_date ASC
        "#,
    )
    .bind(limit)
    .bind(start_date)
    .fetch_all(&state.db_pool)
    .await;

    match result {
        Ok(rows) => {
            info!("Successfully fetched {} price data points for focus instruments", rows.len());
            (StatusCode::OK, Json(rows))
        }
        Err(err) => {
            error!("Failed to fetch focus market data: {err}");
            error!("Query parameters: limit={}, days={}, start_date={}", limit, days, start_date);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(Vec::<PriceDataPoint>::new()),
            )
        }
    }
}

/// Market status DTO
/// Note: Field names match database columns (snake_case) and Swift expects snake_case in JSON
#[derive(Debug, Serialize, FromRow)]
struct MarketStatusDto {
    server_time: DateTime<Utc>,
    market: String,
    after_hours: bool,
    early_hours: bool,
    exchange_nasdaq: Option<String>,
    exchange_nyse: Option<String>,
    exchange_otc: Option<String>,
    currency_crypto: Option<String>,
    currency_fx: Option<String>,
    indices_groups: Option<serde_json::Value>,
}

/// Get current market status
async fn get_market_status_handler(
    State(state): State<AppState>,
) -> impl IntoResponse {
    let result = sqlx::query_as::<_, MarketStatusDto>(
        r#"
        SELECT
            server_time,
            market,
            after_hours,
            early_hours,
            exchange_nasdaq,
            exchange_nyse,
            exchange_otc,
            currency_crypto,
            currency_fx,
            indices_groups
        FROM market_status
        ORDER BY server_time DESC
        LIMIT 1
        "#,
    )
    .fetch_optional(&state.db_pool)
    .await;

    match result {
        Ok(Some(status)) => (StatusCode::OK, Json(json!(status))),
        Ok(None) => (
            StatusCode::NOT_FOUND,
            Json(json!({"error": "no_market_status"})),
        ),
        Err(err) => {
            error!("Failed to fetch market status: {err}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": "internal_error"})),
            )
        }
    }
}