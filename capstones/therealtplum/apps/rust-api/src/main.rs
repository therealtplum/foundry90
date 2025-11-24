use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Map, Value};
use sqlx::{FromRow, PgPool};
use std::{env, net::SocketAddr};
use tokio::net::TcpListener;
use tracing::{error, info};
use tracing_subscriber::prelude::*;
use tracing_subscriber::{EnvFilter, fmt};

#[derive(Clone)]
struct AppState {
    db_pool: PgPool,
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

/// More detailed instrument view (you can extend this later)
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
    published_at: chrono::DateTime<chrono::Utc>,
}

/// Instrument insight record from DB
#[derive(Debug, FromRow)]
struct InstrumentInsightRecord {
    _id: i64,
    content_markdown: String,
    model_name: Option<String>,
    created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Deserialize)]
struct ListInstrumentsParams {
    limit: Option<i64>,
    offset: Option<i64>,
}

#[derive(Debug, Deserialize)]
struct InsightQueryParams {
    horizon_days: Option<i32>,
}

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

    // Default for local dev with `cargo run`
    let default_db_url = "postgres://app:app@localhost:5433/fmhub".to_string();
    let database_url = env::var("DATABASE_URL").unwrap_or(default_db_url);

    info!("Connecting to Postgres at {database_url}…");
    let db_pool = PgPool::connect(&database_url).await?;
    info!("Connected to Postgres");

    let state = AppState { db_pool };

    let app = Router::new()
        .route("/health", get(health_handler))
        .route("/instruments", get(list_instruments_handler))
        .route("/instruments/{id}", get(get_instrument_handler))
        .route("/instruments/{id}/news", get(list_instrument_news_handler))
        .route(
            "/instruments/{id}/insights/{kind}",
            get(get_instrument_insight_handler),
        )
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
        Ok(Some(instr)) => {
            // We wrap in `json!` so all branches return Json<Value>
            let body = json!(instr);
            (StatusCode::OK, Json(body))
        }
        Ok(None) => (
            StatusCode::NOT_FOUND,
            Json(json!({"error": "not_found"})),
        ),
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
) -> impl IntoResponse {
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
        LIMIT 50
        "#,
    )
    .bind(id)
    .fetch_all(&state.db_pool)
    .await;

    match result {
        Ok(rows) => (StatusCode::OK, Json(rows)),
        Err(err) => {
            error!("Failed to fetch news for instrument {id}: {err}");
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
          AND horizon_days = $3
        ORDER BY created_at DESC
        LIMIT 1
        "#,
    )
    .bind(id)
    .bind(&kind)
    .bind(horizon_days)
    .fetch_optional(&state.db_pool)
    .await;

    match cached {
        Ok(Some(record)) => {
            let payload = json!({
                "source": "cache",
                "instrument_id": id,
                "insight_type": kind,
                "horizon_days": horizon_days,
                "model": record.model_name,
                "created_at": record.created_at,
                "content_markdown": record.content_markdown,
            });
            return (StatusCode::OK, Json(payload));
        }
        Ok(None) => {
            // Fall through to generate below
        }
        Err(err) => {
            error!("Failed to load cached insight for {id}: {err}");
            // Fall through to try generating anyway
        }
    }

    // 2. Load minimal context: instrument + recent news titles
    let instrument = sqlx::query_as::<_, InstrumentDetail>(
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

    let instrument = match instrument {
        Ok(Some(inst)) => inst,
        Ok(None) => {
            return (
                StatusCode::NOT_FOUND,
                Json(json!({"error": "instrument_not_found"})),
            );
        }
        Err(err) => {
            error!("Failed to load instrument {id} for insight: {err}");
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": "internal_error"})),
            );
        }
    };

    let news_rows: Vec<NewsArticleDto> = sqlx::query_as::<_, NewsArticleDto>(
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
        LIMIT 10
        "#,
    )
    .bind(id)
    .fetch_all(&state.db_pool)
    .await
    .unwrap_or_else(|err| {
        error!("Failed to load news for insight generation, id={id}: {err}");
        Vec::new()
    });

    // Build JSON context using serde_json::Map<String, Value>
    let mut ctx: Map<String, Value> = Map::new();
    ctx.insert(
        "instrument".to_string(),
        serde_json::to_value(&instrument).unwrap(),
    );
    ctx.insert(
        "news".to_string(),
        serde_json::to_value(&news_rows).unwrap(),
    );
    ctx.insert("horizon_days".to_string(), json!(horizon_days));
    ctx.insert("insight_type".to_string(), json!(&kind));

    let raw_context = Value::Object(ctx);

    // 3. Call LLM (OpenAI) to generate insight
    let api_key = match env::var("OPENAI_API_KEY") {
        Ok(k) if !k.is_empty() => k,
        _ => {
            return (
                StatusCode::SERVICE_UNAVAILABLE,
                Json(json!({"error": "llm_not_configured"})),
            );
        }
    };
    let model = env::var("OPENAI_MODEL").unwrap_or_else(|_| "gpt-4.1-mini".to_string());

    let context_str = serde_json::to_string_pretty(&raw_context).unwrap_or_default();

    let llm_result = llm::generate_instrument_insight(&api_key, &model, &kind, &context_str).await;

    let content_markdown = match llm_result {
        Ok(text) => text,
        Err(err) => {
            error!("LLM call failed for instrument {id}: {err}");
            return (
                StatusCode::BAD_GATEWAY,
                Json(json!({"error": "llm_error"})),
            );
        }
    };

    // 4. Persist new insight to DB
    let inserted = sqlx::query_scalar::<_, i64>(
        r#"
        INSERT INTO instrument_insights (
            instrument_id,
            insight_type,
            horizon_days,
            context_hash,
            content_markdown,
            model_name,
            raw_context
        )
        VALUES ($1, $2, $3, NULL, $4, $5, $6)
        RETURNING id
        "#,
    )
    .bind(id)
    .bind(&kind)
    .bind(horizon_days)
    .bind(&content_markdown)
    .bind(&model)
    .bind(&raw_context)
    .fetch_one(&state.db_pool)
    .await;

    let insight_id = match inserted {
        Ok(i) => i,
        Err(err) => {
            error!("Failed to persist new insight for instrument {id}: {err}");
            let payload = json!({
                "source": "llm",
                "instrument_id": id,
                "insight_type": kind,
                "horizon_days": horizon_days,
                "model": model,
                "content_markdown": content_markdown,
            });
            return (StatusCode::OK, Json(payload));
        }
    };

    let payload = json!({
        "source": "llm",
        "instrument_id": id,
        "insight_type": kind,
        "horizon_days": horizon_days,
        "model": model,
        "insight_id": insight_id,
        "content_markdown": content_markdown,
    });

    (StatusCode::OK, Json(payload))
}

// ---------------------------------------------------------------------
// LLM client (OpenAI chat completions v1)
// ---------------------------------------------------------------------

mod llm {
    use anyhow::Result;
    use reqwest::Client;
    use serde::{Deserialize, Serialize};
    use tracing::info;

    #[derive(Debug, Serialize)]
    struct ChatMessage {
        role: String,
        content: String,
    }

    #[derive(Debug, Serialize)]
    struct ChatRequest {
        model: String,
        messages: Vec<ChatMessage>,
        max_tokens: Option<u32>,
        temperature: Option<f32>,
    }

    #[derive(Debug, Deserialize)]
    struct ChatResponse {
        choices: Vec<ChatChoice>,
    }

    #[derive(Debug, Deserialize)]
    struct ChatChoice {
        message: ChatMessageResponse,
    }

    #[derive(Debug, Deserialize)]
    struct ChatMessageResponse {
        content: String,
    }

    pub async fn generate_instrument_insight(
        api_key: &str,
        model: &str,
        kind: &str,
        context_json: &str,
    ) -> Result<String> {
        let client = Client::new();

        let system_prompt = format!(
            "You are a concise financial analyst. Generate a clear, markdown-formatted summary for a \
             single instrument, based ONLY on the provided JSON context. Insight type: {kind}. \
             Avoid speculation and do not invent data."
        );

        let user_prompt = format!(
            "Context JSON for this instrument:\n\n{}\n\n\
             Please provide a short, structured explanation (headings, bullet points) that explains \
             what's going on and any notable recent developments.",
            context_json
        );

        let req_body = ChatRequest {
            model: model.to_string(),
            messages: vec![
                ChatMessage {
                    role: "system".to_string(),
                    content: system_prompt,
                },
                ChatMessage {
                    role: "user".to_string(),
                    content: user_prompt,
                },
            ],
            max_tokens: Some(600),
            temperature: Some(0.2),
        };

        info!("Calling OpenAI model={model} for instrument insight…");

        let resp = client
            .post("https://api.openai.com/v1/chat/completions")
            .bearer_auth(api_key)
            .json(&req_body)
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