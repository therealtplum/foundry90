use axum::{
    extract::Query,
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::env;
use tracing::{error, info};

/// FRED API v2 client for fetching economic releases
pub struct FredClient {
    http: reqwest::Client,
    api_key: String,
    base_url: String,
}

impl FredClient {
    pub fn from_env() -> Option<Self> {
        // Try to get FRED_API_KEY from environment
        let api_key = env::var("FRED_API_KEY").or_else(|_| {
            // Fallback: try to read from .env file in project root
            use std::io::{BufRead, BufReader};
            let env_paths = ["../../.env", "../.env", ".env"];
            for path in &env_paths {
                if let Ok(file) = std::fs::File::open(path) {
                    let reader = BufReader::new(file);
                    for line_result in reader.lines() {
                        if let Ok(line) = line_result {
                            // Skip comments and empty lines
                            let line = line.trim();
                            if line.is_empty() || line.starts_with('#') {
                                continue;
                            }
                            if line.starts_with("FRED_API_KEY=") {
                                if let Some(key) = line.splitn(2, '=').nth(1) {
                                    let key = key.trim().trim_matches('"').trim_matches('\'');
                                    if !key.is_empty() {
                                        return Ok(key.to_string());
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Err(env::VarError::NotPresent)
        }).ok()?;
        let base_url = "https://api.stlouisfed.org/fred".to_string();

        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .ok()?;

        Some(FredClient {
            http,
            api_key,
            base_url,
        })
    }

    /// Fetch upcoming economic releases within the next N days
    pub async fn fetch_upcoming_releases(&self, days: u32) -> anyhow::Result<FredReleasesResponse> {
        let today = Utc::now().date_naive();
        let end_date = today + chrono::Duration::days(days as i64);

        // Use the correct endpoint: /fred/releases/dates (not v2)
        let url = "https://api.stlouisfed.org/fred/releases/dates";
        let params = [
            ("api_key", self.api_key.as_str()),
            ("file_type", "json"),
            ("realtime_start", &today.format("%Y-%m-%d").to_string()),
            ("realtime_end", &end_date.format("%Y-%m-%d").to_string()),
            ("order_by", "release_date"),
            ("sort_order", "asc"),
            ("limit", "100"),
            ("include_release_dates_with_no_data", "true"), // Include future releases
        ];

        let response = self
            .http
            .get(url)
            .query(&params)
            .send()
            .await?;

        let status = response.status();
        let text = response.text().await?;
        
        if !status.is_success() {
            error!("FRED API error: status={}, body={}", status, text);
            anyhow::bail!("FRED API returned error: status={}, body={}", status, text);
        }

        // Log the response for debugging
        info!("FRED API response (first 200 chars): {}", &text[..text.len().min(200)]);
        
        // Try to parse the response
        let parsed: FredReleasesResponse = serde_json::from_str(&text)
            .map_err(|e| {
                error!("Failed to parse FRED API response: {}. Response: {}", e, &text[..text.len().min(500)]);
                anyhow::anyhow!("Failed to parse FRED API response: {}", e)
            })?;

        Ok(parsed)
    }
}

// MARK: - FRED API Response Models

#[derive(Debug, Serialize, Deserialize)]
pub struct FredReleasesResponse {
    #[serde(rename = "release_dates", default)]
    pub release_dates: Vec<FredReleaseDate>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct FredReleaseDate {
    #[serde(rename = "release_id")]
    pub release_id: i32,
    #[serde(rename = "release_name")]
    pub release_name: String,
    #[serde(rename = "date")]
    pub date: String, // Format: YYYY-MM-DD
}

// MARK: - API Response DTOs

#[derive(Debug, Serialize)]
pub struct EconomicReleaseDto {
    pub release_id: i32,
    pub release_name: String,
    pub release_date: String,
    pub days_until: i64,
}

#[derive(Debug, Deserialize)]
pub struct UpcomingReleasesParams {
    days: Option<u32>,
}

/// Handler for fetching upcoming economic releases
pub async fn get_upcoming_releases_handler(
    Query(params): Query<UpcomingReleasesParams>,
) -> impl IntoResponse {
    let days = params.days.unwrap_or(30);

    let client = match FredClient::from_env() {
        Some(c) => c,
        None => {
            error!("FRED_API_KEY not configured");
            return (
                StatusCode::SERVICE_UNAVAILABLE,
                Json(json!({"error": "fred_api_not_configured"})),
            );
        }
    };

    match client.fetch_upcoming_releases(days).await {
        Ok(response) => {
            let today = Utc::now().date_naive();
            let releases: Vec<EconomicReleaseDto> = response
                .release_dates
                .into_iter()
                .map(|rd| {
                    let release_date = chrono::NaiveDate::parse_from_str(&rd.date, "%Y-%m-%d")
                        .unwrap_or(today);
                    let days_until = (release_date - today).num_days();

                    EconomicReleaseDto {
                        release_id: rd.release_id,
                        release_name: rd.release_name,
                        release_date: rd.date,
                        days_until,
                    }
                })
                .filter(|r| r.days_until >= 0) // Only future releases
                .collect();

            info!("Fetched {} upcoming FRED releases", releases.len());
            (StatusCode::OK, Json(json!(releases)))
        }
        Err(err) => {
            error!("Failed to fetch FRED releases: {err}");
            (
                StatusCode::BAD_GATEWAY,
                Json(json!({"error": "fred_api_error", "message": err.to_string()})),
            )
        }
    }
}

