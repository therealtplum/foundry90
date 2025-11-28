import os
import json
import logging
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests
import psycopg2
from psycopg2.extras import execute_batch

POLYGON_API_KEY = os.getenv("POLYGON_API_KEY")
if not POLYGON_API_KEY:
    raise RuntimeError("POLYGON_API_KEY environment variable is required for polygon_news ETL")

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

# How many news articles to fetch per ticker
NEWS_LIMIT_PER_TICKER = int(os.getenv("POLYGON_NEWS_LIMIT_PER_TICKER", "3"))

# Small sleep between requests to be nice to Polygon
REQUEST_SLEEP_SECS = float(os.getenv("POLYGON_NEWS_SLEEP_SECS", "0.1"))

# Where to find sample_tickers.json
# In Docker, the volume mount is at /export/web-data
# Default: /export/web-data/sample_tickers.json (Docker) or apps/web/data/sample_tickers.json (local)
if os.path.exists("/export/web-data/sample_tickers.json"):
    # Running in Docker with volume mount
    DEFAULT_SAMPLE_TICKERS_PATH = Path("/export/web-data/sample_tickers.json")
else:
    # Running locally, use relative path
    DEFAULT_SAMPLE_TICKERS_PATH = (
        Path(__file__).resolve().parents[2]  # .../apps
        / "web"
        / "data"
        / "sample_tickers.json"
    )
SAMPLE_TICKERS_PATH = Path(
    os.getenv("SAMPLE_TICKERS_JSON_PATH", str(DEFAULT_SAMPLE_TICKERS_PATH))
)

logging.basicConfig(
    level=logging.INFO,
    format="[polygon_news] %(message)s",
)
log = logging.getLogger(__name__)

DATA_SOURCE = "polygon"


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def load_sample_tickers() -> List[Dict[str, Any]]:
    """
    Load tickers from sample_tickers.json.
    Returns list of dicts with at least 'ticker' and 'instrument_id' keys.
    """
    if not SAMPLE_TICKERS_PATH.exists():
        raise FileNotFoundError(
            f"sample_tickers.json not found at {SAMPLE_TICKERS_PATH}. "
            "Run export_sample_tickers_json.py first."
        )

    with open(SAMPLE_TICKERS_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    if not isinstance(data, list):
        raise ValueError("sample_tickers.json must contain a JSON array")

    log.info(f"Loaded {len(data)} tickers from {SAMPLE_TICKERS_PATH}")
    return data


def get_instrument_id_by_ticker(cur, ticker: str) -> Optional[int]:
    """
    Look up instrument_id by ticker from the instruments table.
    Returns the most recent active instrument for this ticker.
    """
    cur.execute(
        """
        SELECT id
        FROM instruments
        WHERE ticker = %s
          AND status = 'active'
        ORDER BY source_last_seen_at DESC NULLS LAST, created_at DESC
        LIMIT 1
        """,
        (ticker,),
    )
    row = cur.fetchone()
    return row[0] if row else None


def fetch_news_from_polygon(ticker: str) -> List[Dict[str, Any]]:
    """
    Fetch recent news articles from Polygon API for a given ticker.
    Returns list of article dicts, or empty list on error.
    """
    # Calculate date range: last 30 days
    end_date = datetime.now(timezone.utc)
    start_date = end_date - timedelta(days=30)

    url = "https://api.polygon.io/v2/reference/news"
    params = {
        "ticker": ticker,
        "limit": NEWS_LIMIT_PER_TICKER,
        "order": "desc",
        "published_utc.gte": start_date.strftime("%Y-%m-%dT00:00:00Z"),
        "published_utc.lte": end_date.strftime("%Y-%m-%dT23:59:59Z"),
        "apiKey": POLYGON_API_KEY,
    }

    try:
        resp = requests.get(url, params=params, timeout=30)
        resp.raise_for_status()
        data = resp.json()

        if data.get("status") != "OK":
            log.warning(f"ticker={ticker}: non-OK status from Polygon news: {data}")
            return []

        results = data.get("results", []) or []
        log.info(f"ticker={ticker}: fetched {len(results)} news articles")
        return results

    except requests.exceptions.RequestException as e:
        log.warning(f"ticker={ticker}: request error from Polygon news: {e}")
        return []
    except json.JSONDecodeError as e:
        log.warning(f"ticker={ticker}: failed to decode JSON: {e}")
        return []


def parse_published_at(article: Dict[str, Any]) -> Optional[datetime]:
    """
    Parse published_utc from Polygon article response.
    Returns datetime in UTC, or None if parsing fails.
    """
    pub_str = article.get("published_utc")
    if not pub_str:
        return None

    # Polygon returns ISO format strings like "2024-01-15T10:30:00Z"
    try:
        # Try parsing with timezone info
        if pub_str.endswith("Z"):
            pub_str = pub_str[:-1] + "+00:00"
        dt = datetime.fromisoformat(pub_str.replace("Z", "+00:00"))
        # Ensure it's timezone-aware
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception as e:
        log.warning(f"Failed to parse published_utc '{pub_str}': {e}")
        return None


def get_instrument_ids_for_tickers(cur, tickers: List[str]) -> Dict[str, int]:
    """
    Look up instrument_ids for a list of tickers.
    Returns dict mapping ticker -> instrument_id (only for tickers that exist).
    """
    if not tickers:
        return {}
    
    cur.execute(
        """
        SELECT DISTINCT ON (ticker)
            ticker, id
        FROM instruments
        WHERE ticker = ANY(%s)
          AND status = 'active'
        ORDER BY ticker, source_last_seen_at DESC NULLS LAST, created_at DESC
        """,
        (tickers,),
    )
    rows = cur.fetchall()
    return {row[0]: row[1] for row in rows}


def upsert_news_articles(cur, articles: List[Dict[str, Any]], primary_instrument_id: int, primary_ticker: str):
    """
    Upsert news articles into the news_articles table.
    For articles that mention multiple tickers, stores the article for ALL mentioned instruments.
    Uses ON CONFLICT to handle duplicates based on (source, url, published_at, instrument_id).
    """
    if not articles:
        return

    sql = """
        INSERT INTO news_articles (
            instrument_id,
            source,
            publisher,
            headline,
            summary,
            url,
            published_at,
            tickers,
            raw_payload
        )
        VALUES (
            %(instrument_id)s,
            %(source)s,
            %(publisher)s,
            %(headline)s,
            %(summary)s,
            %(url)s,
            %(published_at)s,
            %(tickers)s,
            %(raw_payload)s
        )
        ON CONFLICT (source, url, published_at, instrument_id)
        DO UPDATE SET
            publisher = EXCLUDED.publisher,
            headline = EXCLUDED.headline,
            summary = EXCLUDED.summary,
            tickers = EXCLUDED.tickers,
            raw_payload = EXCLUDED.raw_payload,
            updated_at = NOW();
    """

    param_rows = []
    for article in articles:
        published_at = parse_published_at(article)
        if not published_at:
            log.warning(f"ticker={primary_ticker}: skipping article with invalid published_at")
            continue

        # Extract tickers from article (Polygon may include multiple)
        article_tickers = article.get("tickers", [])
        if isinstance(article_tickers, str):
            article_tickers = [article_tickers]
        elif not isinstance(article_tickers, list):
            article_tickers = []

        # If no tickers in article, use the primary ticker
        if not article_tickers:
            article_tickers = [primary_ticker]

        # Look up instrument_ids for all mentioned tickers
        ticker_to_instrument_id = get_instrument_ids_for_tickers(cur, article_tickers)
        
        # If primary ticker not found in article tickers, ensure we include it
        if primary_ticker not in ticker_to_instrument_id and primary_instrument_id:
            ticker_to_instrument_id[primary_ticker] = primary_instrument_id

        # Store article for each instrument mentioned
        for ticker, instrument_id in ticker_to_instrument_id.items():
            param_rows.append(
                {
                    "instrument_id": instrument_id,
                    "source": DATA_SOURCE,
                    "publisher": article.get("publisher", {}).get("name") if isinstance(article.get("publisher"), dict) else article.get("publisher"),
                    "headline": article.get("title") or article.get("headline") or "No headline",
                    "summary": article.get("description") or article.get("summary"),
                    "url": article.get("article_url") or article.get("url") or "",
                    "published_at": published_at,
                    "tickers": json.dumps(article_tickers) if article_tickers else None,
                    "raw_payload": json.dumps(article),
                }
            )

    if param_rows:
        execute_batch(cur, sql, param_rows, page_size=100)
        unique_articles = len(set((r["url"], r["published_at"]) for r in param_rows))
        log.info(f"ticker={primary_ticker}: upserted {len(param_rows)} news article-instrument links ({unique_articles} unique articles)")


def main():
    """
    Main ETL routine:
    1. Load tickers from sample_tickers.json
    2. For each ticker, look up instrument_id in DB
    3. Fetch recent news from Polygon API
    4. Upsert news articles into news_articles table
    """
    log.info(
        f"Starting polygon_news ETL (limit={NEWS_LIMIT_PER_TICKER} per ticker, "
        f"sleep={REQUEST_SLEEP_SECS}s)"
    )

    # Load tickers
    try:
        sample_tickers = load_sample_tickers()
    except Exception as e:
        log.error(f"Failed to load sample_tickers.json: {e}")
        raise

    if not sample_tickers:
        log.warning("No tickers found in sample_tickers.json; nothing to do.")
        return

    # Connect to DB
    conn = get_conn()
    conn.autocommit = False
    cur = conn.cursor()

    total_articles = 0
    processed = 0
    skipped_no_instrument = 0

    try:
        for idx, ticker_data in enumerate(sample_tickers, start=1):
            ticker = ticker_data.get("ticker")
            if not ticker:
                log.warning(f"Row {idx}: missing ticker field, skipping")
                continue

            # Try to get instrument_id from JSON first, fallback to DB lookup
            instrument_id = ticker_data.get("instrument_id")
            if instrument_id:
                # Verify it exists in DB
                cur.execute("SELECT id FROM instruments WHERE id = %s", (instrument_id,))
                if not cur.fetchone():
                    instrument_id = None

            if not instrument_id:
                instrument_id = get_instrument_id_by_ticker(cur, ticker)

            if not instrument_id:
                log.warning(f"ticker={ticker}: no instrument_id found in DB, skipping")
                skipped_no_instrument += 1
                continue

            log.info(f"[{idx}/{len(sample_tickers)}] Processing {ticker} (instrument_id={instrument_id})")

            # Fetch news from Polygon
            articles = fetch_news_from_polygon(ticker)
            if not articles:
                if REQUEST_SLEEP_SECS > 0:
                    time.sleep(REQUEST_SLEEP_SECS)
                continue

            # Upsert articles
            upsert_news_articles(cur, articles, instrument_id, ticker)
            conn.commit()

            total_articles += len(articles)
            processed += 1

            if REQUEST_SLEEP_SECS > 0:
                time.sleep(REQUEST_SLEEP_SECS)

        log.info(
            f"polygon_news ETL completed. "
            f"Processed {processed} tickers, "
            f"upserted {total_articles} articles, "
            f"skipped {skipped_no_instrument} tickers (no instrument_id)"
        )

    except Exception as e:
        log.exception(f"Error in polygon_news ETL: {e}")
        conn.rollback()
        raise

    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
