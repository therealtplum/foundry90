use axum::{extract::State, Json};
use serde::{Serialize, Deserialize};
use serde_json;
use sqlx::{Row, PgPool};
use tracing::{error, info, warn};

use crate::AppState;
use deadpool_redis::redis::cmd;
use reqwest::Client;
use std::env;

// --------------------------------------------------
// Public JSON types
// --------------------------------------------------

#[derive(Serialize)]
pub struct SystemHealth {
    pub api: String,
    pub db: String,
    pub redis: String,
    pub useq_status: Option<String>,    // "open" | "closed" | "extended-hours"
    pub usopt_status: Option<String>,   // "open" | "closed"
    pub fx_status: Option<String>,      // "open" | "closed"
    pub crypto_status: Option<String>,  // "open" | "closed"
    pub kalshi_status: Option<String>,  // "active" | "inactive" (based on active markets)
    pub last_etl_run_utc: Option<String>,
    pub etl_status: String,
    pub recent_errors: i32,
    pub db_tables: Vec<String>,
    pub web_local: Option<WebHealth>,
    pub web_prod: Option<WebHealth>,
    pub regression_test: Option<RegressionTestResults>,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct RegressionTestResults {
    pub last_run_utc: Option<String>,
    pub passed: i32,
    pub failed: i32,
    pub warnings: i32,
    pub success: bool,
}

#[derive(Serialize, Clone)]
pub struct WebHealth {
    pub status: String,                // "up" | "down" | "degraded"
    pub url: String,
    pub http_status: Option<u16>,
    pub build_commit: Option<String>,  // from /api/version
    pub build_branch: Option<String>,
    pub deployed_at_utc: Option<String>,
    pub is_latest: Option<bool>,       // compared to Vercel API (if available)
    pub last_checked_utc: Option<String>,
}

// --------------------------------------------------
// Internal helper types for JSON decoding
// --------------------------------------------------

#[derive(Deserialize)]
struct FrontendVersionResponse {
    status: String,
    app: String,
    env: String,
    url: String,
    build: FrontendBuildInfo,
}

#[derive(Deserialize)]
struct FrontendBuildInfo {
    commit: String,
    branch: String,
    deployed_at_utc: Option<String>,
}

#[derive(Deserialize)]
struct VercelDeploymentsResponse {
    deployments: Vec<VercelDeployment>,
}

#[derive(Deserialize)]
struct VercelDeployment {
    uid: String,
    meta: Option<VercelDeploymentMeta>,
}

#[derive(Deserialize)]
struct VercelDeploymentMeta {
    #[serde(rename = "gitCommitSha")]
    git_commit_sha: Option<String>,
    #[serde(rename = "githubCommitSha")]
    github_commit_sha: Option<String>,
}

// --------------------------------------------------
// Regression test helper
// --------------------------------------------------

/// Read regression test results from JSON file.
/// The file is written to the project's logs directory, which should be accessible
/// via a volume mount or the same filesystem.
async fn get_regression_test_results() -> Option<RegressionTestResults> {
    use std::fs;

    // The regression script writes to PROJECT_ROOT/logs/regression_results.json
    // When the API runs in Docker, the logs directory is mounted at /app/logs
    let possible_paths = vec![
        "/app/logs/regression_results.json",     // Docker mount point
        "./logs/regression_results.json",       // Relative to current dir
        "../logs/regression_results.json",      // One level up
        "../../logs/regression_results.json",    // Two levels up (from apps/rust-api)
    ];

    for path in possible_paths {
        if let Ok(contents) = fs::read_to_string(path) {
            if let Ok(parsed) = serde_json::from_str::<RegressionTestResults>(&contents) {
                info!("Loaded regression test results from {}", path);
                return Some(parsed);
            } else {
                warn!("Failed to parse regression results from {}", path);
            }
        }
    }

    None
}

// --------------------------------------------------
// ETL helper
// --------------------------------------------------

/// Safely derive last_etl_run_utc from instrument_focus_universe.as_of_date.
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
                Ok(_) => None,
                Err(err) => {
                    error!("Failed to read last_run_utc column: {err}");
                    None
                }
            }
        }
        Ok(None) => None,
        Err(err) => {
            error!(
                "Failed to fetch last_etl_run_utc from instrument_focus_universe: {err}"
            );
            None
        }
    }
}

// --------------------------------------------------
// Vercel integration (optional)
// --------------------------------------------------

async fn fetch_latest_vercel_commit(client: &Client) -> Option<String> {
    let token = match env::var("VERCEL_API_TOKEN") {
        Ok(v) if !v.is_empty() => v,
        _ => {
            warn!("VERCEL_API_TOKEN not set; skipping Vercel latest-commit check");
            return None;
        }
    };

    let project_id = match env::var("VERCEL_PROJECT_ID") {
        Ok(v) if !v.is_empty() => v,
        _ => {
            warn!("VERCEL_PROJECT_ID not set; skipping Vercel latest-commit check");
            return None;
        }
    };

    let team_id = env::var("VERCEL_TEAM_ID").ok().filter(|s| !s.is_empty());

    let mut url = format!(
        "https://api.vercel.com/v6/deployments?projectId={}&state=READY&target=production&limit=1",
        project_id
    );

    if let Some(team) = team_id {
        url.push_str(&format!("&teamId={}", team));
    }

    let resp = match client
        .get(&url)
        .bearer_auth(&token)
        .send()
        .await
    {
        Ok(r) => r,
        Err(err) => {
            warn!("Failed to query Vercel deployments: {err}");
            return None;
        }
    };

    let resp = match resp.error_for_status() {
        Ok(r) => r,
        Err(err) => {
            warn!("Non-200 from Vercel deployments: {err}");
            return None;
        }
    };

    let body: VercelDeploymentsResponse = match resp.json().await {
        Ok(b) => b,
        Err(err) => {
            warn!("Failed to decode Vercel deployments JSON: {err}");
            return None;
        }
    };

    let deployment = match body.deployments.first() {
        Some(d) => d,
        None => return None,
    };

    if let Some(meta) = &deployment.meta {
        if let Some(sha) = &meta.git_commit_sha {
            return Some(sha.clone());
        }
        if let Some(sha) = &meta.github_commit_sha {
            return Some(sha.clone());
        }
    }

    None
}

// --------------------------------------------------
// Frontend health check
// --------------------------------------------------

async fn check_frontend_health_for_url(
    client: &Client,
    url: String,
    latest_vercel_commit: Option<&str>,
) -> Option<WebHealth> {
    let resp = match client
        .get(&url)
        .timeout(std::time::Duration::from_secs(3))
        .send()
        .await
    {
        Ok(r) => r,
        Err(err) => {
            warn!("Frontend health check to {url} failed to send request: {err}");
            return Some(WebHealth {
                status: "down".to_string(),
                url,
                http_status: None,
                build_commit: None,
                build_branch: None,
                deployed_at_utc: None,
                is_latest: None,
                last_checked_utc: None,
            });
        }
    };

    let status_code = resp.status().as_u16();

    if status_code != 200 {
        warn!(
            "Frontend health check to {url} returned non-200 status: {}",
            status_code
        );
        return Some(WebHealth {
            status: "down".to_string(),
            url,
            http_status: Some(status_code),
            build_commit: None,
            build_branch: None,
            deployed_at_utc: None,
            is_latest: None,
            last_checked_utc: None,
        });
    }

    let body: FrontendVersionResponse = match resp.json().await {
        Ok(b) => b,
        Err(err) => {
            warn!("Failed to decode frontend /api/version JSON from {url}: {err}");
            return Some(WebHealth {
                status: "degraded".to_string(),
                url,
                http_status: Some(status_code),
                build_commit: None,
                build_branch: None,
                deployed_at_utc: None,
                is_latest: None,
                last_checked_utc: None,
            });
        }
    };

    let is_latest = match (latest_vercel_commit, Some(body.build.commit.as_str())) {
        (Some(latest), Some(current)) => Some(latest == current),
        _ => None,
    };

    Some(WebHealth {
        status: "up".to_string(),
        url: body.url,
        http_status: Some(status_code),
        build_commit: Some(body.build.commit),
        build_branch: Some(body.build.branch),
        deployed_at_utc: body.build.deployed_at_utc,
        is_latest,
        last_checked_utc: None,
    })
}

// --------------------------------------------------
// Main handler
// --------------------------------------------------

pub async fn get_system_health(State(state): State<AppState>) -> Json<SystemHealth> {
    let client = Client::new();

    // API status
    let api = "up".to_string();

    // DB status + tables
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

    // Redis
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

    // ETL
    let last_etl_run_utc = get_last_etl_run_utc(&state.db_pool).await;
    let etl_status = "idle".to_string();
    let recent_errors = 0;

    // Regression test results
    let regression_test = get_regression_test_results().await;

    // Market statuses for different asset classes
    use sqlx::Row;
    let market_status_row = sqlx::query(
        r#"
        SELECT 
            exchange_nyse,
            exchange_nasdaq,
            currency_fx,
            currency_crypto
        FROM market_status
        ORDER BY server_time DESC
        LIMIT 1
        "#,
    )
    .fetch_optional(&state.db_pool)
    .await
    .ok()
    .flatten();
    
    // Extract individual asset class statuses
    let useq_status = market_status_row.as_ref()
        .and_then(|row| {
            row.try_get::<Option<String>, _>("exchange_nyse").ok()
                .flatten()
                .or_else(|| row.try_get::<Option<String>, _>("exchange_nasdaq").ok().flatten())
        })
        .map(|s| s.to_lowercase());
    
    let usopt_status = market_status_row.as_ref()
        .and_then(|row| {
            row.try_get::<Option<String>, _>("exchange_nyse").ok()
                .flatten()
                .or_else(|| row.try_get::<Option<String>, _>("exchange_nasdaq").ok().flatten())
        })
        .map(|s| s.to_lowercase());
    
    let fx_status = market_status_row.as_ref()
        .and_then(|row| row.try_get::<Option<String>, _>("currency_fx").ok().flatten())
        .map(|s| s.to_lowercase());
    
    let crypto_status = market_status_row.as_ref()
        .and_then(|row| row.try_get::<Option<String>, _>("currency_crypto").ok().flatten())
        .map(|s| s.to_lowercase());
    
    // Kalshi status: check if there are active markets
    let kalshi_status: Option<String> = match sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)
        FROM instruments
        WHERE primary_source = 'kalshi'
          AND status = 'active'
        "#,
    )
    .fetch_one(&state.db_pool)
    .await
    {
        Ok(count) => {
            if count > 0 {
                Some("active".to_string())
            } else {
                Some("inactive".to_string())
            }
        }
        Err(err) => {
            warn!("Failed to fetch Kalshi market count: {err}");
            None
        }
    };

    // Should we hit Vercel?
    let skip_vercel = env::var("SKIP_VERCEL_COMPARE")
        .map(|v| v == "true" || v == "1")
        .unwrap_or(false);

    let latest_vercel_commit = if skip_vercel {
        None
    } else {
        fetch_latest_vercel_commit(&client).await
    };

    // Web (local)
    let local_url = env::var("FRONTEND_HEALTH_URL_LOCAL")
        .unwrap_or_else(|_| "http://fmhub_web:3000/api/version".to_string());
    let web_local =
        check_frontend_health_for_url(&client, local_url, latest_vercel_commit.as_deref()).await;

    // Web (prod)
    let prod_url = env::var("FRONTEND_HEALTH_URL_PROD")
        .unwrap_or_else(|_| "https://www.foundry90.com/api/version".to_string());
    let web_prod =
        check_frontend_health_for_url(&client, prod_url, latest_vercel_commit.as_deref()).await;

    Json(SystemHealth {
        api,
        db: db_status,
        redis: redis_status,
        useq_status,
        usopt_status,
        fx_status,
        crypto_status,
        kalshi_status,
        last_etl_run_utc,
        etl_status,
        recent_errors,
        db_tables,
        web_local,
        web_prod,
        regression_test,
    })
}