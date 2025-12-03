"""
Polygon WebSocket streaming service for real-time market data.

Connects to Polygon's WebSocket API to stream real-time trades, quotes, and bars.
Updates instrument_price_daily with intraday data and can aggregate to daily bars.
"""

import os
import json
import logging
import asyncio
import websockets
from datetime import datetime, timezone
from typing import Set, Dict, Optional
import psycopg2
from psycopg2.extras import execute_values

POLYGON_API_KEY = os.getenv("POLYGON_API_KEY")
if not POLYGON_API_KEY:
    raise RuntimeError("POLYGON_API_KEY environment variable is required for polygon_streaming")

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

logging.basicConfig(
    level=logging.INFO,
    format="[polygon_streaming] %(message)s",
)
log = logging.getLogger(__name__)

# Polygon WebSocket URLs
WS_URL = "wss://socket.polygon.io/stocks"

# How often to flush data to database (seconds)
FLUSH_INTERVAL = int(os.getenv("STREAMING_FLUSH_INTERVAL", "60"))

# Batch size for database inserts
BATCH_SIZE = int(os.getenv("STREAMING_BATCH_SIZE", "100"))

DATA_SOURCE = "polygon_streaming"


class PolygonStreamer:
    def __init__(self):
        self.ws = None
        self.tickers: Set[str] = set()
        self.pending_bars: Dict[str, Dict] = {}  # ticker -> latest bar data
        self.conn = None
        self.cur = None
        
    def get_conn(self):
        """Get database connection."""
        if self.conn is None or self.conn.closed:
            self.conn = psycopg2.connect(DATABASE_URL)
            self.cur = self.conn.cursor()
        return self.conn, self.cur
    
    def load_focus_tickers(self):
        """Load tickers from focus universe."""
        conn, cur = self.get_conn()
        cur.execute("""
            WITH latest_focus AS (
                SELECT as_of_date
                FROM instrument_focus_universe
                GROUP BY as_of_date
                HAVING COUNT(*) >= 500
                ORDER BY as_of_date DESC
                LIMIT 1
            )
            SELECT i.ticker
            FROM instrument_focus_universe fu
            JOIN latest_focus lf ON fu.as_of_date = lf.as_of_date
            JOIN instruments i ON i.id = fu.instrument_id
            ORDER BY fu.activity_rank_global ASC
            LIMIT 50;
        """)
        rows = cur.fetchall()
        self.tickers = {row[0] for row in rows}
        log.info(f"Loaded {len(self.tickers)} tickers from focus universe")
        return list(self.tickers)
    
    async def authenticate(self, ws):
        """Authenticate with Polygon WebSocket."""
        auth_msg = {
            "action": "auth",
            "params": POLYGON_API_KEY
        }
        await ws.send(json.dumps(auth_msg))
        log.info("Sent authentication to Polygon WebSocket")
    
    async def subscribe(self, ws, tickers: list[str]):
        """Subscribe to tickers for real-time bars."""
        # Subscribe to minute bars (A = aggregates)
        subscribe_msg = {
            "action": "subscribe",
            "params": ",".join([f"A.{ticker}" for ticker in tickers])
        }
        await ws.send(json.dumps(subscribe_msg))
        log.info(f"Subscribed to {len(tickers)} tickers for real-time bars")
    
    def process_bar(self, bar_data: dict):
        """Process a real-time bar update."""
        event = bar_data.get("ev")
        if event != "A":  # A = aggregate (bar)
            return
        
        ticker = bar_data.get("sym")
        if not ticker:
            return
        
        # Store latest bar data
        self.pending_bars[ticker] = {
            "ticker": ticker,
            "open": bar_data.get("o"),
            "high": bar_data.get("h"),
            "low": bar_data.get("l"),
            "close": bar_data.get("c"),
            "volume": bar_data.get("v"),
            "timestamp_ms": bar_data.get("s"),  # Start time of bar
        }
    
    async def flush_to_db(self):
        """Flush pending bars to database."""
        if not self.pending_bars:
            return
        
        conn, cur = self.get_conn()
        
        # Get instrument IDs for tickers
        tickers_list = list(self.pending_bars.keys())
        placeholders = ",".join(["%s"] * len(tickers_list))
        cur.execute(f"SELECT id, ticker FROM instruments WHERE ticker IN ({placeholders})", tickers_list)
        ticker_to_id = {row[1]: row[0] for row in cur.fetchall()}
        
        # Prepare rows for upsert
        rows = []
        today = datetime.now(timezone.utc).date()
        
        for ticker, bar in self.pending_bars.items():
            if ticker not in ticker_to_id:
                continue
            
            # Convert timestamp to date (for daily aggregation, use today)
            # For intraday, you might want to store in a separate table
            price_date = today
            
            rows.append({
                "instrument_id": ticker_to_id[ticker],
                "price_date": price_date,
                "open": bar["open"],
                "high": bar["high"],
                "low": bar["low"],
                "close": bar["close"],
                "adj_close": bar["close"],
                "volume": bar["volume"],
                "data_source": DATA_SOURCE,
            })
        
        if not rows:
            return
        
        # Upsert to database
        sql = """
            INSERT INTO instrument_price_daily (
                instrument_id, price_date, open, high, low, close, adj_close, volume, data_source
            )
            VALUES %s
            ON CONFLICT (instrument_id, price_date, data_source)
            DO UPDATE SET
                open = GREATEST(EXCLUDED.open, instrument_price_daily.open),
                high = GREATEST(EXCLUDED.high, instrument_price_daily.high),
                low = LEAST(EXCLUDED.low, instrument_price_daily.low),
                close = EXCLUDED.close,
                adj_close = EXCLUDED.adj_close,
                volume = instrument_price_daily.volume + EXCLUDED.volume,
                updated_at = NOW();
        """
        
        execute_values(cur, sql, [
            (r["instrument_id"], r["price_date"], r["open"], r["high"], r["low"], 
             r["close"], r["adj_close"], r["volume"], r["data_source"])
            for r in rows
        ])
        conn.commit()
        
        log.info(f"Flushed {len(rows)} bars to database")
        self.pending_bars.clear()
    
    async def run(self):
        """Main streaming loop."""
        tickers = self.load_focus_tickers()
        if not tickers:
            log.error("No tickers to stream")
            return
        
        try:
            async with websockets.connect(WS_URL) as ws:
                # Authenticate
                await self.authenticate(ws)
                
                # Wait for auth confirmation
                auth_response = await ws.recv()
                log.info(f"Auth response: {auth_response}")
                
                # Subscribe to tickers
                await self.subscribe(ws, tickers)
                
                # Wait for subscription confirmation
                sub_response = await ws.recv()
                log.info(f"Subscribe response: {sub_response}")
                
                # Start flush task
                flush_task = asyncio.create_task(self.periodic_flush())
                
                # Main message loop
                async for message in ws:
                    try:
                        data = json.loads(message)
                        
                        # Handle array of events
                        if isinstance(data, list):
                            for event in data:
                                self.process_bar(event)
                        else:
                            self.process_bar(data)
                            
                    except json.JSONDecodeError as e:
                        log.warning(f"Failed to decode message: {e}")
                    except Exception as e:
                        log.error(f"Error processing message: {e}")
                
                flush_task.cancel()
                
        except Exception as e:
            log.exception(f"Error in streaming loop: {e}")
            raise
    
    async def periodic_flush(self):
        """Periodically flush data to database."""
        while True:
            await asyncio.sleep(FLUSH_INTERVAL)
            await self.flush_to_db()


async def main():
    streamer = PolygonStreamer()
    await streamer.run()


if __name__ == "__main__":
    asyncio.run(main())

