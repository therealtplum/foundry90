import os
import time
import logging

import psycopg2
import requests


# -------------------------------------------------------------------
# Config
# -------------------------------------------------------------------

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

# Inside Docker, the API service is reachable as `api:3000`
API_BASE_URL = os.getenv("FMHUB_API_BASE_URL", "http://api:3000")

# How many focus instruments to prewarm
FOCUS_LIMIT = int(os.getenv("FOCUS_PREWARM_LIMIT", "100"))

# Horizon days for both overview & recent insights
HORIZON_DAYS = int(os.getenv("FOCUS_PREWARM_HORIZON_DAYS", "30"))

# Small delay between OpenAI calls so we don't hammer anything
SLEEP_SECONDS = float(os.getenv("FOCUS_PREWARM_SLEEP_SECONDS", "0.4"))


logging.basicConfig(
    level=logging.INFO,
    format="[prewarm_insights] %(message)s",
)


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def get_latest_focus_snapshot(cur):
    cur.execute("SELECT MAX(as_of_date) FROM instrument_focus_universe")
    row = cur.fetchone()
    if not row or row[0] is None:
        return None
    return row[0]


def get_focus_instruments(cur, as_of_date, limit):
    cur.execute(
        """
        SELECT
            fu.instrument_id,
            i.ticker,
            i.name
        FROM instrument_focus_universe fu
        JOIN instruments i
          ON i.id = fu.instrument_id
        WHERE fu.as_of_date = %s
        ORDER BY fu.activity_rank_global ASC
        LIMIT %s
        """,
        (as_of_date, limit),
    )
    rows = cur.fetchall()
    return [
        {
            "instrument_id": r[0],
            "ticker": r[1],
            "name": r[2],
        }
        for r in rows
    ]


def call_insight_api(instrument_id: int, kind: str) -> str:
    """
    Hit the fmhub-api insight endpoint.

    This endpoint already:
      - checks the DB cache
      - calls OpenAI if needed
      - persists the result

    We just call it and look at the 'source' field.
    """
    url = f"{API_BASE_URL}/instruments/{instrument_id}/insights/{kind}"
    params = {"horizon_days": HORIZON_DAYS}

    resp = requests.get(url, params=params, timeout=60)
    if resp.status_code == 404:
        logging.warning(f"instrument_id={instrument_id} not found for kind={kind}")
        return "not_found"

    resp.raise_for_status()
    data = resp.json()

    # Expected shape:
    # { "source": "cache" | "llm", ... }
    return str(data.get("source", "unknown"))


def prewarm():
    logging.info(f"Starting prewarm job (limit={FOCUS_LIMIT}, horizon={HORIZON_DAYS}d)")

    conn = get_conn()
    cur = conn.cursor()

    try:
        as_of = get_latest_focus_snapshot(cur)
        if as_of is None:
            logging.error("No instrument_focus_universe snapshots found; aborting.")
            return

        logging.info(f"Using focus snapshot as_of_date={as_of}")

        focus_rows = get_focus_instruments(cur, as_of, FOCUS_LIMIT)
        if not focus_rows:
            logging.error("No focus instruments found; aborting.")
            return

        logging.info(f"Loaded {len(focus_rows)} focus instruments.")

        total_calls = 0
        total_llm = 0
        total_cache = 0

        for idx, row in enumerate(focus_rows, start=1):
            inst_id = row["instrument_id"]
            ticker = row["ticker"]

            for kind in ("overview", "recent"):
                total_calls += 1
                try:
                    source = call_insight_api(inst_id, kind)
                    if source == "llm":
                        total_llm += 1
                    elif source == "cache":
                        total_cache += 1

                    logging.info(
                        f"[{idx}/{len(focus_rows)}] {ticker} ({inst_id}) "
                        f"kind={kind} source={source}"
                    )
                except Exception as e:
                    logging.error(
                        f"Error prewarming insight kind={kind} for "
                        f"{ticker} ({inst_id}): {e}"
                    )

                time.sleep(SLEEP_SECONDS)

        logging.info(
            f"Done prewarming. calls={total_calls}, "
            f"from_cache={total_cache}, from_llm={total_llm}"
        )

    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    prewarm()