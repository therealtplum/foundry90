use crate::schemas::RawEvent;
use anyhow::{Context, Result};
use base64::{engine::general_purpose, Engine as _};
use chrono::Utc;
use futures_util::{SinkExt, StreamExt};
use rsa::{
    pss::BlindedSigningKey,
    sha2::Sha256,
    signature::{RandomizedSigner, SignatureEncoding},
    RsaPrivateKey,
};
use pkcs1::DecodeRsaPrivateKey;
use pkcs8::DecodePrivateKey;
use serde_json::json;
use std::env;
use std::fs;
use tokio::sync::mpsc;
use tokio_tungstenite::{
    connect_async,
    tungstenite::http::{HeaderMap, HeaderValue},
    tungstenite::Message,
};
use tracing::{error, info, warn};

/// Kalshi WebSocket ingest manager
/// Handles RSA-PSS authentication and market data streaming
pub struct KalshiIngestManager {
    tx: mpsc::Sender<RawEvent>,
    api_key: String,
    private_key_path: String,
    connection_id: String,
    ws_url: String,
}

impl KalshiIngestManager {
    /// Create a new Kalshi ingest manager
    pub fn new(
        tx: mpsc::Sender<RawEvent>,
        api_key: String,
        private_key_path: String,
        connection_id: String,
    ) -> Self {
        let ws_url = env::var("KALSHI_WS_URL")
            .unwrap_or_else(|_| "wss://api.elections.kalshi.com/trade-api/ws/v2".to_string());

        Self {
            tx,
            api_key,
            private_key_path,
            connection_id,
            ws_url,
        }
    }

    /// Get Kalshi API keys from environment
    /// Supports: KALSHI_API_KEY_1, KALSHI_API_KEY_2, etc.
    pub fn get_api_keys() -> Vec<(String, String)> {
        let mut keys = Vec::new();

        for i in 1..=10 {
            let key_var = format!("KALSHI_API_KEY_{}", i);
            let path_var = format!("KALSHI_PRIVATE_KEY_{}_PATH", i);

            if let (Ok(api_key), Ok(key_path)) = (env::var(&key_var), env::var(&path_var)) {
                if !api_key.is_empty() && !key_path.is_empty() {
                    keys.push((api_key, key_path));
                }
            }
        }

        // Also check for single key (backward compatible)
        if let (Ok(api_key), Ok(key_path)) = (
            env::var("KALSHI_API_KEY"),
            env::var("KALSHI_PRIVATE_KEY_PATH"),
        ) {
            if !api_key.is_empty() && !key_path.is_empty() {
                keys.push((api_key, key_path));
            }
        }

        keys
    }

    /// Load RSA private key from file
    fn load_private_key(path: &str) -> Result<RsaPrivateKey> {
        let key_data = fs::read_to_string(path)
            .with_context(|| format!("Failed to read private key from {}", path))?;

        // Remove any whitespace/newlines
        let key_data = key_data.trim();

        // Parse PEM format - try PKCS1 first, then PKCS8
        let private_key = RsaPrivateKey::from_pkcs1_pem(key_data)
            .or_else(|_| RsaPrivateKey::from_pkcs8_pem(key_data))
            .with_context(|| "Failed to parse RSA private key from PEM (tried both PKCS1 and PKCS8)")?;

        Ok(private_key)
    }

    /// Generate authentication headers for WebSocket connection
    fn generate_auth_headers(&self) -> Result<HeaderMap> {
        let private_key = Self::load_private_key(&self.private_key_path)?;

        // Create signing key for RSA-PSS
        let signing_key: BlindedSigningKey<Sha256> = BlindedSigningKey::new(private_key);

        // Generate timestamp (milliseconds since epoch)
        let timestamp_ms = Utc::now().timestamp_millis().to_string();

        // Create message to sign: timestamp + "GET" + "/trade-api/ws/v2"
        let message = format!("{}GET/trade-api/ws/v2", timestamp_ms);

        // Sign with RSA-PSS (randomized signing)
        let mut rng = rand::thread_rng();
        let signature = signing_key.sign_with_rng(&mut rng, message.as_bytes());
        // Convert signature to bytes using SignatureEncoding trait
        let signature_b64 = general_purpose::STANDARD.encode(signature.to_bytes());

        // Build headers
        let mut headers = HeaderMap::new();
        headers.insert(
            "KALSHI-ACCESS-KEY",
            HeaderValue::from_str(&self.api_key)
                .context("Invalid API key for header")?,
        );
        headers.insert(
            "KALSHI-ACCESS-SIGNATURE",
            HeaderValue::from_str(&signature_b64)
                .context("Invalid signature for header")?,
        );
        headers.insert(
            "KALSHI-ACCESS-TIMESTAMP",
            HeaderValue::from_str(&timestamp_ms)
                .context("Invalid timestamp for header")?,
        );

        Ok(headers)
    }

    /// Start ingesting from Kalshi WebSocket
    pub async fn start(&self) -> Result<()> {
        info!(
            "[{}] Connecting to Kalshi WebSocket: {}",
            self.connection_id, self.ws_url
        );

        loop {
            match self.connect_and_stream().await {
                Ok(()) => {
                    warn!(
                        "[{}] Kalshi connection closed, reconnecting in 5 seconds...",
                        self.connection_id
                    );
                    tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
                }
                Err(e) => {
                    error!(
                        "[{}] Kalshi connection error: {}. Reconnecting in 5 seconds...",
                        self.connection_id, e
                    );
                    tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
                }
            }
        }
    }

    async fn connect_and_stream(&self) -> Result<()> {
        // Generate authentication headers
        let headers = self.generate_auth_headers()?;

        // Build request with headers using tungstenite's client builder
        let url = self.ws_url.parse::<tokio_tungstenite::tungstenite::http::Uri>()?;
        let mut request = tokio_tungstenite::tungstenite::http::Request::builder()
            .uri(&url)
            .header("Host", url.host().unwrap_or("api.elections.kalshi.com"))
            .header("Upgrade", "websocket")
            .header("Connection", "Upgrade")
            .header("Sec-WebSocket-Key", tokio_tungstenite::tungstenite::handshake::client::generate_key())
            .header("Sec-WebSocket-Version", "13")
            .body(())
            .context("Failed to build WebSocket request")?;

        // Add authentication headers
        request.headers_mut().extend(headers);

        // Connect to WebSocket
        let (ws_stream, _) = connect_async(request)
            .await
            .context("Failed to connect to Kalshi WebSocket")?;

        info!("[{}] Connected to Kalshi WebSocket", self.connection_id);

        let (mut write, mut read) = ws_stream.split();
        let mut message_id = 1u64;

        // Subscribe to ticker updates (all markets)
        let subscribe_msg = json!({
            "id": message_id,
            "cmd": "subscribe",
            "params": {
                "channels": ["ticker"]
            }
        });
        message_id += 1;

        if let Err(e) = write
            .send(Message::Text(serde_json::to_string(&subscribe_msg)?))
            .await
        {
            error!("[{}] Failed to send subscribe message: {}", self.connection_id, e);
            return Err(e.into());
        }

        info!(
            "[{}] Subscribed to Kalshi ticker updates",
            self.connection_id
        );

        // Process incoming messages
        while let Some(msg) = read.next().await {
            match msg {
                Ok(Message::Text(text)) => {
                    // Parse JSON message
                    let payload: serde_json::Value = match serde_json::from_str(&text) {
                        Ok(p) => p,
                        Err(e) => {
                            warn!(
                                "[{}] Failed to parse Kalshi message: {} - {}",
                                self.connection_id, e, text
                            );
                            continue;
                        }
                    };

                    // Check message type
                    if let Some(msg_type) = payload.get("type").and_then(|v| v.as_str()) {
                        match msg_type {
                            "subscribed" => {
                                info!(
                                    "[{}] Subscription confirmed: {:?}",
                                    self.connection_id, payload
                                );
                            }
                            "ticker" | "orderbook_delta" | "orderbook_snapshot" | "trades" => {
                                // Market data event - emit as RawEvent
                                let raw_event = RawEvent {
                                    source: "kalshi".to_string(),
                                    venue: "kalshi_ws".to_string(),
                                    raw_payload: payload,
                                    received_at: Utc::now(),
                                };

                                if let Err(e) = self.tx.send(raw_event).await {
                                    error!(
                                        "[{}] Failed to send raw event to normalize: {}",
                                        self.connection_id, e
                                    );
                                }
                            }
                            "error" => {
                                if let Some(error_msg) = payload.get("msg") {
                                    error!(
                                        "[{}] Kalshi error: {:?}",
                                        self.connection_id, error_msg
                                    );
                                }
                            }
                            _ => {
                                // Unknown message type - log but continue
                                info!(
                                    "[{}] Unknown Kalshi message type '{}': {}",
                                    self.connection_id, msg_type, text
                                );
                            }
                        }
                    }
                }
                Ok(Message::Close(_)) => {
                    info!("[{}] Kalshi WebSocket closed by server", self.connection_id);
                    break;
                }
                Ok(Message::Ping(data)) => {
                    // Respond to ping
                    if let Err(e) = write.send(Message::Pong(data)).await {
                        error!("[{}] Failed to send pong: {}", self.connection_id, e);
                        break;
                    }
                }
                Ok(Message::Pong(_)) => {
                    // Ignore pong
                }
                Err(e) => {
                    error!("[{}] WebSocket error: {}", self.connection_id, e);
                    break;
                }
                _ => {}
            }
        }

        Ok(())
    }
}

