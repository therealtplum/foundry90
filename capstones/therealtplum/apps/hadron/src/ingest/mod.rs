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
pub struct IngestManager {
    tx: mpsc::Sender<RawEvent>,
}

impl IngestManager {
    pub fn new(tx: mpsc::Sender<RawEvent>) -> Self {
        Self { tx }
    }

    /// Start ingesting from Polygon WebSocket
    pub async fn start(&self) -> Result<()> {
        let api_key = env::var("POLYGON_API_KEY")
            .context("POLYGON_API_KEY environment variable not set")?;

        // Polygon/Massive.com WebSocket URL (no API key in URL - auth happens via message)
        // Real-time: wss://socket.massive.com/stocks
        // Delayed: wss://delayed.massive.com/stocks
        let url = "wss://socket.massive.com/stocks";

        info!("Connecting to Polygon WebSocket: {}", url);

        loop {
            match self.connect_and_stream(&url, &api_key).await {
                Ok(()) => {
                    warn!("Polygon connection closed, reconnecting in 5 seconds...");
                    tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
                }
                Err(e) => {
                    error!("Polygon connection error: {}. Reconnecting in 5 seconds...", e);
                    tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
                }
            }
        }
    }

    async fn connect_and_stream(&self, url: &str, api_key: &str) -> Result<()> {
        let (ws_stream, _) = connect_async(url)
            .await
            .context("Failed to connect to Polygon WebSocket")?;

        info!("Connected to Polygon WebSocket");

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
                        info!("Polygon message #{}: {}", messages_received, text);
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
                                        info!("Polygon WebSocket connected, authenticating...");
                                        let auth_msg = json!({
                                            "action": "auth",
                                            "params": api_key
                                        });

                                        if let Err(e) = write.send(Message::Text(serde_json::to_string(&auth_msg)?)).await {
                                            error!("Failed to send auth message: {}", e);
                                            break;
                                        }
                                    } else if status == "auth_success" && !subscribed {
                                        authenticated = true;
                                        info!("Polygon authentication successful");
                                        
                                        // Now subscribe to trades for a few popular tickers
                                        // Polygon expects params as comma-separated string: "T.AAPL,T.MSFT"
                                        let tickers = vec!["AAPL", "MSFT", "GOOGL", "AMZN", "TSLA"];
                                        let subscribe_params: String = tickers.iter()
                                            .map(|t| format!("T.{}", t))
                                            .collect::<Vec<_>>()
                                            .join(",");
                                        
                                        let subscribe_msg = json!({
                                            "action": "subscribe",
                                            "params": subscribe_params
                                        });

                                        if let Err(e) = write.send(Message::Text(serde_json::to_string(&subscribe_msg)?)).await {
                                            error!("Failed to send subscribe message: {}", e);
                                            break;
                                        }

                                        subscribed = true;
                                        info!("Subscribed to Polygon trades for: {:?}", tickers);
                                    } else if status == "auth_failed" {
                                        error!("Polygon authentication failed: {:?}", payload);
                                        break;
                                    } else if status == "error" {
                                        // "not authorized" might mean API key doesn't have WebSocket access
                                        // Continue running but log the issue
                                        if let Some(msg) = payload.get("message").and_then(|v| v.as_str()) {
                                            warn!("Polygon subscription error: {} - This may indicate the API key doesn't have WebSocket access. System will continue running.", msg);
                                            // Don't break - keep connection alive in case it's a temporary issue
                                        }
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
                    info!("Polygon WebSocket closed by server");
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
}

