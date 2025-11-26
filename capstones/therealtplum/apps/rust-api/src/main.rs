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

use deadpool_redis::{Config as RedisConfig, Pool as RedisPool};
use deadpool_redis::redis::AsyncCommands;

/// Shared application state
#[derive(Clone)]
pub struct AppState {
    pub db_pool: PgPool,
    pub redis_pool: RedisPool,
    pub(crate) chat_client: Option<ChatClient>,
}

#[derive(Serialize)]
struct HealthResponse {
    status: String,
    db_ok: bool,
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

/// Instrument insight record from DB
#[derive(Debug, Serialize, FromRow)]
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
        let model = env::var("OPENAI_MODEL").unwrap_or_else(|_| "gpt-4.1-mini".to_string());

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
    ) -> anyhow::Result<String> {
        let system = match kind {
            "overview" => "You are a financial research assistant. Produce a concise overview of the instrument, including what it is, key characteristics, and why it might be interesting to an event-driven trader.",
            "recent" => "You are a financial research assistant. Summarize the most important recent developments, news, and catalysts for this instrument over the requested horizon.",
            _ => "You are a financial research assistant. Provide concise, relevant information about the instrument.",
        };

        let prompt = format!(
            "Instrument: {name} ({ticker})\n\
             Asset class: {asset_class}\n\
             Exchange: {exchange}\n\
             Region: {region:?}\n\
             Country: {country:?}\n\
             Horizon: last {horizon_days} days.\n\n\
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
        );

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
    // Logging setup
    tracing_subscriber::registry()
        .with(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,tower_http=info,sqlx=warn".into()),
        )
        .with(fmt::layer())
        .init();

    dotenvy::dotenv().ok();

    // --- Redis setup ---
    let redis_url = env::var("REDIS_URL")
        .unwrap_or_else(|_| "redis://127.0.0.1:6379".to_string());

    let mut redis_cfg = RedisConfig::default();
    redis_cfg.url = Some(redis_url);
    redis_cfg.connection = None;

    let redis_pool = redis_cfg
        .create_pool(Some(deadpool_redis::Runtime::Tokio1))
        .expect("Failed to create Redis pool");

    // Default for local dev with `cargo run`
    let default_db_url = "postgres://app:app@localhost:5433/fmhub".to_string();
    let database_url = env::var("DATABASE_URL").unwrap_or(default_db_url);

    info!("Connecting to Postgres at {database_url}…");
    let db_pool = PgPool::connect(&database_url).await?;
    info!("Connected to Postgres");

    let chat_client = ChatClient::from_env();
    if chat_client.is_none() {
        info!("OPENAI_API_KEY not set; insight generation will fall back to cache-only.");
    }

    let state = AppState {
        db_pool,
        redis_pool,
        chat_client,
    };

    // Permissive CORS for local dev
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/health", get(health_handler))
        .route("/system/health", get(system_health::get_system_health))
        .route("/instruments", get(list_instruments_handler))
        .route("/instruments/{id}", get(get_instrument_handler))
        .route("/instruments/{id}/news", get(list_instrument_news_handler))
        .route(
            "/instruments/{id}/insights/{kind}",
            get(get_instrument_insight_handler),
        )
        .route("/focus/ticker-strip", get(get_focus_ticker_strip))
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

async fn get_instrument_insight_handler(
    State(state): State<AppState>,
    Path((id, kind)): Path<(i64, String)>,
    Query(params): Query<InsightQueryParams>,
) -> impl IntoResponse {
    let horizon_days = params.horizon_days.unwrap_or(30);
    let kind = kind.to_lowercase();

    // 1. Try latest cached insight from DB
    let cached = sqlx::query_as::<_, InstrumentInsightRecord>(
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

    match cached {
        Ok(Some(rec)) => {
            return (
                StatusCode::OK,
                Json(json!({
                    "source": "cache",
                    "insight": rec,
                })),
            )
        }
        Ok(None) => {
            info!(
                "No cached insight for instrument_id={id}, kind={kind}; attempting LLM generation."
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

    // 2. If no cache, we may generate via LLM (if configured)
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
    let text = match chat_client
        .generate_insight(&instrument, &kind, horizon_days)
        .await
    {
        Ok(t) => t,
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

    // Persist new insight
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
        Ok(rec) => (
            StatusCode::OK,
            Json(json!({
                "source": "llm",
                "insight": rec,
            })),
        ),
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

    // 1) Try cache
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

    // 2) Fallback to DB
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
            // 3) Write-through to Redis (best-effort)
            if let Ok(json_blob) = serde_json::to_string(&rows) {
                if let Ok(mut conn) = state.redis_pool.get().await {
                    match conn
                        .set_ex::<_, _, ()>(&cache_key, json_blob, ttl_seconds)
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
                                "focus_ticker_strip: failed to SETEX cache (key={}): {}",
                                cache_key, err
                            );
                        }
                    }
                } else {
                    error!("focus_ticker_strip: failed to get Redis connection for SETEX");
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