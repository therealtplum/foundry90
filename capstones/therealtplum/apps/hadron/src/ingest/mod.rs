use crate::schemas::RawEvent;
use anyhow::{Context, Result};
use chrono::Utc;
use futures_util::{SinkExt, StreamExt};
use serde_json::json;
use std::env;
use tokio::sync::mpsc;
use tokio_tungstenite::{connect_async, tungstenite::Message};
use tracing::{error, info, warn};

/// Ingest manager for Polygon WebSocket feed
/// Supports multiple API keys for load distribution and redundancy
pub struct IngestManager {
    tx: mpsc::Sender<RawEvent>,
    api_keys: Vec<String>,
    connection_id: Option<String>,
}

impl IngestManager {
    /// Create a new ingest manager with a single API key (backward compatible)
    pub fn new(tx: mpsc::Sender<RawEvent>) -> Self {
        Self {
            tx,
            api_keys: Vec::new(),
            connection_id: None,
        }
    }

    /// Create a new ingest manager with a specific API key and connection ID
    pub fn with_api_key(tx: mpsc::Sender<RawEvent>, api_key: String, connection_id: String) -> Self {
        Self {
            tx,
            api_keys: vec![api_key],
            connection_id: Some(connection_id),
        }
    }

    /// Get API keys from environment variables
    /// Supports: POLYGON_API_KEY, HADRON_API_KEY_1, HADRON_API_KEY_2, etc.
    pub fn get_api_keys() -> Vec<String> {
        let mut keys = Vec::new();

        // Primary key (backward compatible)
        if let Ok(key) = env::var("POLYGON_API_KEY") {
            keys.push(key);
        }

        // Multiple keys: HADRON_API_KEY_1, HADRON_API_KEY_2, etc.
        for i in 1..=10 {
            let var_name = format!("HADRON_API_KEY_{}", i);
            if let Ok(key) = env::var(&var_name) {
                if !key.is_empty() {
                    keys.push(key);
                }
            }
        }

        keys
    }

    /// Start ingesting from Polygon WebSocket
    pub async fn start(&self) -> Result<()> {
        // Use provided API keys or get from environment
        let api_keys = if !self.api_keys.is_empty() {
            self.api_keys.clone()
        } else {
            Self::get_api_keys()
        };

        if api_keys.is_empty() {
            anyhow::bail!("No Polygon API keys found. Set POLYGON_API_KEY or HADRON_API_KEY_1, etc.");
        }

        let api_key = api_keys[0].clone(); // Use first key for this connection
        let connection_id = self.connection_id.clone().unwrap_or_else(|| "default".to_string());

        // Polygon/Massive.com WebSocket URL (no API key in URL - auth happens via message)
        // Real-time: wss://socket.massive.com/stocks (requires real-time plan)
        // Delayed: wss://delayed.massive.com/stocks (15-minute delayed, included in most plans)
        // Use delayed endpoint by default (can be overridden via HADRON_WEBSOCKET_MODE env var)
        let url = match env::var("HADRON_WEBSOCKET_MODE").as_deref() {
            Ok("realtime") => "wss://socket.massive.com/stocks",
            Ok("delayed") | Ok(_) | Err(_) => "wss://delayed.massive.com/stocks",
        };

        info!("[{}] Connecting to Polygon WebSocket: {}", connection_id, url);

        loop {
            match self.connect_and_stream(&url, &api_key, &connection_id).await {
                Ok(()) => {
                    warn!("[{}] Polygon connection closed, reconnecting in 5 seconds...", connection_id);
                    tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
                }
                Err(e) => {
                    error!("[{}] Polygon connection error: {}. Reconnecting in 5 seconds...", connection_id, e);
                    tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
                }
            }
        }
    }

    async fn connect_and_stream(&self, url: &str, api_key: &str, connection_id: &str) -> Result<()> {
        let (ws_stream, _) = connect_async(url)
            .await
            .context("Failed to connect to Polygon WebSocket")?;

        info!("[{}] Connected to Polygon WebSocket", connection_id);

        let (mut write, mut read) = ws_stream.split();

        // Wait for connection confirmation, then authenticate
        let mut authenticated = false;
        let mut subscribed = false;
        let mut messages_received = 0;

        // Read messages
        while let Some(msg) = read.next().await {
            match msg {
                Ok(Message::Text(text)) => {
                    messages_received += 1;
                    
                    // Log first few messages for debugging
                    if messages_received <= 5 {
                        info!("[{}] Polygon message #{}: {}", connection_id, messages_received, text);
                    }

                    // Polygon sends messages as arrays
                    let messages: Vec<serde_json::Value> = match serde_json::from_str(&text) {
                        Ok(msgs) => msgs,
                        Err(_) => {
                            // Try as single object
                            match serde_json::from_str::<serde_json::Value>(&text) {
                                Ok(obj) => vec![obj],
                                Err(e) => {
                                    warn!("Failed to parse Polygon message: {} - {}", e, text);
                                    continue;
                                }
                            }
                        }
                    };

                    for payload in messages {
                        // Check for status/authentication messages
                        if let Some(ev) = payload.get("ev").and_then(|v| v.as_str()) {
                            if ev == "status" {
                                if let Some(status) = payload.get("status").and_then(|v| v.as_str()) {
                                    if status == "connected" && !authenticated {
                                        // Connection successful - now authenticate
                                        info!("[{}] Polygon WebSocket connected, authenticating...", connection_id);
                                        let auth_msg = json!({
                                            "action": "auth",
                                            "params": api_key
                                        });

                                        if let Err(e) = write.send(Message::Text(serde_json::to_string(&auth_msg)?)).await {
                                            error!("[{}] Failed to send auth message: {}", connection_id, e);
                                            break;
                                        }
                                        // Continue to wait for auth_success response
                                        continue;
                                    } else if status == "auth_success" {
                                        authenticated = true;
                                        authenticated = true;
                                        info!("[{}] Polygon authentication successful", connection_id);
                                        
                                        // Get tickers to subscribe to for this connection
                                        // For multiple connections, distribute tickers across them
                                        let tickers = self.get_tickers_for_connection(connection_id);
                                        let subscribe_params: String = tickers.iter()
                                            .map(|t| format!("T.{}", t))
                                            .collect::<Vec<_>>()
                                            .join(",");
                                        
                                        if !subscribe_params.is_empty() {
                                            let subscribe_msg = json!({
                                                "action": "subscribe",
                                                "params": subscribe_params
                                            });

                                            if let Err(e) = write.send(Message::Text(serde_json::to_string(&subscribe_msg)?)).await {
                                                error!("[{}] Failed to send subscribe message: {}", connection_id, e);
                                                break;
                                            }

                                            subscribed = true;
                                            info!("[{}] Subscribed to Polygon trades for: {:?}", connection_id, tickers);
                                        } else {
                                            warn!("[{}] No tickers to subscribe to", connection_id);
                                        }
                                    } else if status == "auth_failed" {
                                        error!("[{}] Polygon authentication failed: {:?}", connection_id, payload);
                                        break;
                                    } else if status == "error" {
                                        // Handle various error types
                                        if let Some(msg) = payload.get("message").and_then(|v| v.as_str()) {
                                            if msg.contains("not authorized") {
                                                warn!("[{}] Polygon subscription error: {} - This may indicate the API key doesn't have WebSocket access or subscription format is incorrect. System will continue running.", connection_id, msg);
                                            } else if msg.contains("max_connections") {
                                                error!("[{}] Polygon max connections exceeded: {} - Polygon allows only 1 concurrent WebSocket connection per asset class. This connection will close.", connection_id, msg);
                                                // Break this connection - it won't work anyway
                                                break;
                                            } else {
                                                warn!("[{}] Polygon error: {} - System will continue running.", connection_id, msg);
                                            }
                                        }
                                    } else if status == "max_connections" {
                                        error!("[{}] Polygon max connections exceeded - Polygon allows only 1 concurrent WebSocket connection per asset class. This connection will close.", connection_id);
                                        break;
                                    }
                                }
                            } else if ev == "T" {
                                // Trade event - handle it
                                if authenticated {
                                    let raw_event = RawEvent {
                                        source: "polygon".to_string(),
                                        venue: "polygon_ws".to_string(),
                                        raw_payload: payload,
                                        received_at: Utc::now(),
                                    };

                                    if let Err(e) = self.tx.send(raw_event).await {
                                        error!("Failed to send raw event to normalize: {}", e);
                                    }
                                }
                            }
                        }
                    }
                }
                Ok(Message::Close(_)) => {
                    info!("[{}] Polygon WebSocket closed by server", connection_id);
                    break;
                }
                Ok(Message::Ping(data)) => {
                    // Respond to ping
                    if let Err(e) = write.send(Message::Pong(data)).await {
                        error!("Failed to send pong: {}", e);
                        break;
                    }
                }
                Ok(Message::Pong(_)) => {
                    // Ignore pong
                }
                Err(e) => {
                    error!("WebSocket error: {}", e);
                    break;
                }
                _ => {}
            }
        }

        Ok(())
    }

    /// Get tickers to subscribe to for this connection
    /// For multiple connections, distributes tickers across them
    fn get_tickers_for_connection(&self, connection_id: &str) -> Vec<&'static str> {
        // All available tickers (can be expanded)
        let all_tickers = vec!["AAPL", "MSFT", "GOOGL", "AMZN", "TSLA", "META", "NVDA", "NFLX", "DIS", "JPM"];
        
        // For now, if connection_id is "default" or we only have one connection, subscribe to all
        // Later: implement round-robin distribution across connections
        if connection_id == "default" || connection_id == "hadron_1" {
            all_tickers
        } else {
            // For other connections, distribute tickers
            // Simple modulo distribution based on connection number
            let conn_num: usize = connection_id
                .strip_prefix("hadron_")
                .and_then(|s| s.parse().ok())
                .unwrap_or(1);
            
            all_tickers
                .into_iter()
                .enumerate()
                .filter(|(i, _)| i % 4 == (conn_num - 1) % 4)
                .map(|(_, ticker)| ticker)
                .collect()
        }
    }
}

