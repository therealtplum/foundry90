use serde::Serialize;
use std::env;

/// Environment configuration loaded from environment variables
#[derive(Debug, Clone)]
pub struct EnvConfig {
    pub env: String,
    pub api_version: String,
    pub commit_sha: String,
}

impl EnvConfig {
    /// Load configuration from environment variables
    pub fn from_env() -> Self {
        let env = env::var("F90_ENV")
            .unwrap_or_else(|_| "dev".to_string())
            .to_lowercase();

        let api_version = env::var("F90_API_VERSION")
            .unwrap_or_else(|_| "v1".to_string())
            .to_lowercase();

        let commit_sha = env::var("F90_COMMIT_SHA")
            .unwrap_or_else(|_| "unknown".to_string());

        Self {
            env,
            api_version,
            commit_sha,
        }
    }

    /// Get environment-specific health message
    pub fn health_message(&self) -> String {
        match self.env.as_str() {
            "prod" => "FMHub API (prod) is reachable. Trading endpoints coming soon.".to_string(),
            "sim" => "FMHub API (sim) is reachable. Simulation endpoints coming soon.".to_string(),
            "demo" => "Demo API is reachable. Public demo routes coming soon.".to_string(),
            "dev" => "Dev API reachable. v1 mirrors prod, v1-staged exposes new features.".to_string(),
            _ => format!("FMHub API ({}) is reachable. Endpoints coming soon.", self.env),
        }
    }

    /// Get preview versions for dev environment
    pub fn preview_versions(&self) -> Option<Vec<String>> {
        if self.env == "dev" {
            Some(vec!["v1-staged".to_string()])
        } else {
            None
        }
    }
}

/// Health response structure
#[derive(Serialize)]
pub struct HealthResponse {
    pub env: String,
    pub status: String,
    pub version: String,
    pub message: String,
    pub commit: String,
    pub timestamp: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub preview_versions: Option<Vec<String>>,
}

/// Coming soon response structure
#[derive(Serialize)]
pub struct ComingSoonResponse {
    pub env: String,
    pub status: String,
    pub route: String,
    pub message: String,
}

