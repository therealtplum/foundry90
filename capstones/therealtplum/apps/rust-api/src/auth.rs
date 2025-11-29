// apps/rust-api/src/auth.rs
// JWT validation middleware for Auth0 tokens

use axum::{
    extract::Request,
    http::{header::AUTHORIZATION, StatusCode},
    middleware::Next,
    response::Response,
};
use jsonwebtoken::{decode, DecodingKey, Validation, Algorithm};
use serde::{Deserialize, Serialize};
use std::env;

/// JWT claims structure from Auth0
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,           // User ID (e.g., "auth0|...")
    pub email: Option<String>,
    pub email_verified: Option<bool>,
    pub name: Option<String>,
    pub nickname: Option<String>,
    pub picture: Option<String>,
    pub aud: String,           // Audience (API identifier)
    pub iss: String,           // Issuer (Auth0 domain)
    pub exp: i64,              // Expiration timestamp
    pub iat: Option<i64>,      // Issued at timestamp
    pub scope: Option<String>, // OAuth scopes
}

/// Extract and validate JWT token from Authorization header
pub async fn validate_jwt(mut request: Request, next: Next) -> Result<Response, StatusCode> {
    // Get token from Authorization header
    let auth_header = request
        .headers()
        .get(AUTHORIZATION)
        .and_then(|header| header.to_str().ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Extract Bearer token
    let token = auth_header
        .strip_prefix("Bearer ")
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Get Auth0 configuration from environment
    let auth0_domain = env::var("AUTH0_DOMAIN")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let auth0_audience = env::var("AUTH0_AUDIENCE")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Fetch JWKS (JSON Web Key Set) from Auth0
    // For production, you should cache this and refresh periodically
    let jwks_url = format!("https://{}/.well-known/jwks.json", auth0_domain);
    let jwks = fetch_jwks(&jwks_url)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Decode and validate token
    let header = jsonwebtoken::decode_header(token)
        .map_err(|_| StatusCode::UNAUTHORIZED)?;

    let kid = header.kid.ok_or(StatusCode::UNAUTHORIZED)?;

    // Find the matching key from JWKS
    let key = jwks
        .keys
        .iter()
        .find(|k| k.kid == kid)
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Decode the token
    // The JWKS provides base64url-encoded RSA components
    // jsonwebtoken's from_rsa_components expects base64url-encoded strings
    let decoding_key = DecodingKey::from_rsa_components(&key.n, &key.e)
        .map_err(|e| {
            tracing::error!("Failed to create decoding key: {}", e);
            StatusCode::UNAUTHORIZED
        })?;

    let mut validation = Validation::new(Algorithm::RS256);
    validation.set_audience(&[&auth0_audience]);
    validation.set_issuer(&[&format!("https://{}", auth0_domain)]);

    let token_data = decode::<Claims>(token, &decoding_key, &validation)
        .map_err(|_| StatusCode::UNAUTHORIZED)?;

    // Add claims to request extensions for use in handlers
    request.extensions_mut().insert(token_data.claims);

    Ok(next.run(request).await)
}

/// Optional middleware - only validates if token is present
pub async fn optional_validate_jwt(
    request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    // Check if Authorization header exists
    if let Some(auth_header) = request.headers().get(AUTHORIZATION) {
        if let Ok(header_str) = auth_header.to_str() {
            if header_str.strip_prefix("Bearer ").is_some() {
                // Validate token if present
                return validate_jwt(request, next).await;
            }
        }
    }

    // No token present, continue without authentication
    Ok(next.run(request).await)
}

/// Extract claims from request extensions
pub fn get_claims(request: &Request) -> Option<&Claims> {
    request.extensions().get::<Claims>()
}

/// JWKS structure
#[derive(Debug, Deserialize)]
struct Jwks {
    keys: Vec<Jwk>,
}

#[derive(Debug, Deserialize)]
struct Jwk {
    kid: String,
    kty: String,
    r#use: String,
    n: String,
    e: String,
}

/// Fetch JWKS from Auth0
async fn fetch_jwks(url: &str) -> Result<Jwks, Box<dyn std::error::Error>> {
    let response = reqwest::get(url).await?;
    let jwks: Jwks = response.json().await?;
    Ok(jwks)
}

