"""
WebSocket service for streaming Kalshi market data.

This service connects to Kalshi's WebSocket API and streams real-time
market data updates, storing them in Redis for fast access and optionally
in the database for historical tracking.
"""

import os
import json
import asyncio
import logging
import websockets
from datetime import datetime, timezone
from typing import Optional, Dict, Any
import redis.asyncio as aioredis

# Kalshi WebSocket configuration
KALSHI_WS_URL = os.getenv(
    "KALSHI_WS_URL", 
    "wss://api.elections.kalshi.com/trade-api/ws/v2"
)
KALSHI_WS_DEMO_URL = os.getenv(
    "KALSHI_WS_DEMO_URL",
    "wss://demo-api.kalshi.co/trade-api/ws/v2"
)

# Redis configuration
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")

# Use demo environment if specified
USE_DEMO = os.getenv("KALSHI_USE_DEMO", "false").lower() == "true"

logging.basicConfig(
    level=logging.INFO,
    format="[kalshi_websocket] %(message)s",
)
log = logging.getLogger(__name__)


class KalshiWebSocketClient:
    """
    WebSocket client for streaming Kalshi market data.
    
    Handles:
    - Connection management and reconnection
    - Subscribing to market updates
    - Processing and storing market data
    - Error handling and recovery
    """
    
    def __init__(
        self,
        ws_url: Optional[str] = None,
        redis_url: Optional[str] = None,
        api_key: Optional[str] = None,
        api_secret: Optional[str] = None,
    ):
        self.ws_url = ws_url or (KALSHI_WS_DEMO_URL if USE_DEMO else KALSHI_WS_URL)
        self.redis_url = redis_url or REDIS_URL
        self.api_key = api_key
        self.api_secret = api_secret
        
        self.redis_client: Optional[aioredis.Redis] = None
        self.ws: Optional[websockets.WebSocketClientProtocol] = None
        self.running = False
        self.subscribed_markets: set[str] = set()
        
    async def connect_redis(self):
        """Connect to Redis for caching market data."""
        try:
            self.redis_client = await aioredis.from_url(
                self.redis_url,
                decode_responses=True,
            )
            await self.redis_client.ping()
            log.info("Connected to Redis")
        except Exception as e:
            log.error(f"Failed to connect to Redis: {e}")
            raise
    
    async def disconnect_redis(self):
        """Disconnect from Redis."""
        if self.redis_client:
            await self.redis_client.close()
            log.info("Disconnected from Redis")
    
    def _generate_auth_headers(self) -> Dict[str, str]:
        """
        Generate authentication headers for WebSocket connection.
        
        Kalshi uses RSA-PSS signing for authentication. This is a placeholder
        that should be implemented with proper RSA-PSS signing.
        """
        if not self.api_key or not self.api_secret:
            return {}
        
        # TODO: Implement RSA-PSS signing
        # For now, return empty headers (public endpoints may work)
        return {}
    
    async def connect_websocket(self):
        """Connect to Kalshi WebSocket."""
        try:
            headers = self._generate_auth_headers()
            self.ws = await websockets.connect(
                self.ws_url,
                extra_headers=headers,
            )
            log.info(f"Connected to Kalshi WebSocket: {self.ws_url}")
        except Exception as e:
            log.error(f"Failed to connect to WebSocket: {e}")
            raise
    
    async def subscribe_to_market(self, ticker: str):
        """
        Subscribe to real-time updates for a specific market.
        
        Args:
            ticker: Kalshi market ticker (e.g., "BIDEN-2024")
        """
        if not self.ws:
            raise RuntimeError("WebSocket not connected")
        
        # Kalshi WebSocket subscription message format
        # This may need adjustment based on actual API documentation
        subscribe_msg = {
            "action": "subscribe",
            "ticker": ticker,
        }
        
        await self.ws.send(json.dumps(subscribe_msg))
        self.subscribed_markets.add(ticker)
        log.info(f"Subscribed to market: {ticker}")
    
    async def subscribe_to_markets(self, tickers: list[str]):
        """Subscribe to multiple markets at once."""
        for ticker in tickers:
            await self.subscribe_to_market(ticker)
    
    async def unsubscribe_from_market(self, ticker: str):
        """Unsubscribe from a market."""
        if not self.ws:
            return
        
        unsubscribe_msg = {
            "action": "unsubscribe",
            "ticker": ticker,
        }
        
        await self.ws.send(json.dumps(unsubscribe_msg))
        self.subscribed_markets.discard(ticker)
        log.info(f"Unsubscribed from market: {ticker}")
    
    async def process_market_update(self, data: Dict[str, Any]):
        """
        Process a market data update from WebSocket.
        
        Stores the update in Redis with a TTL for fast access.
        Format: kalshi:market:{ticker} -> JSON market data
        """
        ticker = data.get("ticker")
        if not ticker:
            return
        
        # Store in Redis with 1 hour TTL
        redis_key = f"kalshi:market:{ticker}"
        await self.redis_client.setex(
            redis_key,
            3600,  # 1 hour TTL
            json.dumps(data),
        )
        
        # Also store latest price in a separate key for quick access
        if "yes_price" in data or "yes_bid" in data:
            price_data = {
                "ticker": ticker,
                "yes_price": data.get("yes_price") or 
                           ((data.get("yes_bid", 0) + data.get("yes_ask", 0)) / 2),
                "volume": data.get("volume", 0),
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
            price_key = f"kalshi:price:{ticker}"
            await self.redis_client.setex(
                price_key,
                3600,
                json.dumps(price_data),
            )
    
    async def handle_message(self, message: str):
        """Handle incoming WebSocket message."""
        try:
            data = json.loads(message)
            
            # Handle different message types
            msg_type = data.get("type") or data.get("action")
            
            if msg_type == "market_update" or "ticker" in data:
                await self.process_market_update(data)
            elif msg_type == "error":
                log.error(f"WebSocket error: {data.get('message')}")
            elif msg_type == "ping":
                # Respond to ping
                await self.ws.send(json.dumps({"type": "pong"}))
            else:
                log.debug(f"Received message type: {msg_type}")
                
        except json.JSONDecodeError as e:
            log.warning(f"Failed to parse WebSocket message: {e}")
        except Exception as e:
            log.error(f"Error handling WebSocket message: {e}")
    
    async def listen(self):
        """Main listening loop for WebSocket messages."""
        if not self.ws:
            raise RuntimeError("WebSocket not connected")
        
        self.running = True
        log.info("Starting WebSocket listener...")
        
        try:
            async for message in self.ws:
                if not self.running:
                    break
                await self.handle_message(message)
        except websockets.exceptions.ConnectionClosed:
            log.warning("WebSocket connection closed")
        except Exception as e:
            log.error(f"Error in WebSocket listener: {e}")
        finally:
            self.running = False
    
    async def start(self, tickers: Optional[list[str]] = None):
        """
        Start the WebSocket client.
        
        Args:
            tickers: Optional list of market tickers to subscribe to initially
        """
        await self.connect_redis()
        await self.connect_websocket()
        
        if tickers:
            await self.subscribe_to_markets(tickers)
        
        # Start listening
        await self.listen()
    
    async def stop(self):
        """Stop the WebSocket client."""
        self.running = False
        
        if self.ws:
            await self.ws.close()
        
        await self.disconnect_redis()
        log.info("WebSocket client stopped")
    
    async def reconnect(self, max_retries: int = 5, delay: int = 5):
        """Reconnect with exponential backoff."""
        for attempt in range(max_retries):
            try:
                log.info(f"Reconnection attempt {attempt + 1}/{max_retries}")
                await self.connect_websocket()
                
                # Resubscribe to all markets
                if self.subscribed_markets:
                    await self.subscribe_to_markets(list(self.subscribed_markets))
                
                # Resume listening
                await self.listen()
                return
            except Exception as e:
                log.error(f"Reconnection attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    await asyncio.sleep(delay * (2 ** attempt))
        
        log.error("Failed to reconnect after all retries")


async def main():
    """
    Main entry point for running the WebSocket service.
    
    Can be run as a standalone service or integrated into the ETL pipeline.
    """
    # Example: Subscribe to a few markets
    # In production, you'd fetch the list from the database
    example_tickers = [
        # Add example tickers here
    ]
    
    client = KalshiWebSocketClient()
    
    try:
        await client.start(tickers=example_tickers if example_tickers else None)
    except KeyboardInterrupt:
        log.info("Received interrupt signal")
    finally:
        await client.stop()


if __name__ == "__main__":
    asyncio.run(main())

