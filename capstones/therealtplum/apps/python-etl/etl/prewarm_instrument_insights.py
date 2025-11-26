import os
import time
import logging
from typing import Any, Dict, List, Optional
from datetime import datetime, date, timedelta, timezone

import psycopg2
import psycopg2.extras
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

# Small delay between *actual* OpenAI calls so we don't hammer anything
SLEEP_SECONDS = float(os.getenv("FOCUS_PREWARM_SLEEP_SECONDS", "0.4"))

# How “fresh” a recent insight must be to skip regeneration
RECENT_MAX_AGE_DAYS = int(os.getenv("FOCUS_PREWARM_RECENT_MAX_AGE_DAYS", "3"))

logging.basicConfig(
    level=logging.INFO,
    format="[prewarm_insights] %(message)s",
)
log = logging.getLogger(__name__)


# -------------------------------------------------------------------
# DB helpers
# -------------------------------------------------------------------

def get_conn():
    return psycopg2.connect(DATABASE_URL)


def get_latest_focus_snapshot(cur) -> Optional[Any]:
    """
    Return the latest as_of_date from instrument_focus_universe, or None.
    """
    cur.execute("SELECT MAX(as_of_date) FROM instrument_focus_universe")
    row = cur.fetchone()
    if not row or row[0] is None:
        return None
    return row[0]


def get_focus_instruments(cur, as_of_date, limit: int) -> List[Dict[str, Any]]:
    """
    Fetch the top focus instruments for a given as_of_date, ordered by global activity rank.
    """
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


def get_existing_insights(
    cur,
    instrument_ids: List[int],
) -> Dict[int, Dict[str, datetime]]:
    """
    Preload existing insights for a set of instrument_ids.

    Returns:
        {
          instrument_id: {
            "overview": created_at_utc,
            "recent": created_at_utc,
          },
          ...
        }
    """
    if not instrument_ids:
        return {}

    cur.execute(
        """
        SELECT instrument_id, insight_type, created_at
        FROM instrument_insights
        WHERE instrument_id = ANY(%s)
        """,
        (instrument_ids,),
    )

    by_inst: Dict[int, Dict[str, datetime]] = {}

    for inst_id, insight_type, created_at in cur.fetchall():
        if created_at is None:
            continue

        # Normalize to UTC-aware datetime
        if created_at.tzinfo is None:
            created_at_utc = created_at.replace(tzinfo=timezone.utc)
        else:
            created_at_utc = created_at.astimezone(timezone.utc)

        inst_dict = by_inst.setdefault(inst_id, {})
        # Keep the newest timestamp per (instrument, type)
        prev = inst_dict.get(insight_type)
        if prev is None or created_at_utc > prev:
            inst_dict[insight_type] = created_at_utc

    return by_inst


# -------------------------------------------------------------------
# API helper
# -------------------------------------------------------------------

def call_insight_api(instrument_id: int, kind: str) -> str:
    """
    Hit the fmhub-api insight endpoint.

    This endpoint already:
      - checks the Redis/DB cache
      - calls OpenAI if needed
      - persists the result

    We just call it and look at the 'source' field.
    """
    url = f"{API_BASE_URL}/instruments/{instrument_id}/insights/{kind}"
    params = {"horizon_days": HORIZON_DAYS}

    resp = requests.get(url, params=params, timeout=60)
    if resp.status_code == 404:
        log.warning(f"instrument_id={instrument_id} not found for kind={kind}")
        return "not_found"

    resp.raise_for_status()
    data = resp.json()

    # Expected shape:
    # { "source": "cache" | "llm", ... }
    return str(data.get("source", "unknown"))


# -------------------------------------------------------------------
# Main prewarm routine
# -------------------------------------------------------------------

def prewarm():
    """
    For the most recent focus snapshot, prewarm 'overview' and 'recent' insights
    for the top N focus instruments by global activity rank.

    Optimization:
      - Overview: generate once, then never again (always read from DB/Redis).
      - Recent: only regenerate if older than RECENT_MAX_AGE_DAYS.
    """
    log.info(
        f"Starting prewarm job (limit={FOCUS_LIMIT}, "
        f"horizon={HORIZON_DAYS}d, recent_max_age={RECENT_MAX_AGE_DAYS}d)"
    )

    conn = get_conn()
    cur = conn.cursor()

    try:
        as_of = get_latest_focus_snapshot(cur)
        if as_of is None:
            log.error("No instrument_focus_universe snapshots found; aborting.")
            return

        log.info(f"Using focus snapshot as_of_date={as_of}")

        focus_rows = get_focus_instruments(cur, as_of, FOCUS_LIMIT)
        if not focus_rows:
            log.error("No focus instruments found; aborting.")
            return

        log.info(f"Loaded {len(focus_rows)} focus instruments.")

        instrument_ids = [row["instrument_id"] for row in focus_rows]

        # Preload insights from DB and normalize timestamps to UTC-aware
        existing = get_existing_insights(cur, instrument_ids)

        now_utc = datetime.now(timezone.utc)
        recent_cutoff = now_utc - timedelta(days=RECENT_MAX_AGE_DAYS)

        total_calls = 0
        total_llm = 0
        total_cache = 0
        skipped_overview = 0
        skipped_recent_fresh = 0

        for idx, row in enumerate(focus_rows, start=1):
            inst_id = row["instrument_id"]
            ticker = row["ticker"]

            inst_insights = existing.get(inst_id, {})

            # ----------------------
            # 1) Overview – generate once, then never again
            # ----------------------
            if "overview" in inst_insights:
                skipped_overview += 1
                log.info(
                    f"[{idx}/{len(focus_rows)}] {ticker} ({inst_id}) "
                    f"kind=overview SKIP (already in DB)"
                )
            else:
                # Need an overview insight
                try:
                    source = call_insight_api(inst_id, "overview")
                    total_calls += 1
                    if source == "llm":
                        total_llm += 1
                    elif source == "cache":
                        total_cache += 1

                    log.info(
                        f"[{idx}/{len(focus_rows)}] {ticker} ({inst_id}) "
                        f"kind=overview source={source}"
                    )
                except Exception as e:
                    log.error(
                        f"Error prewarming overview for {ticker} ({inst_id}): {e}"
                    )
                else:
                    # only sleep if we actually called the API
                    time.sleep(SLEEP_SECONDS)

            # ----------------------
            # 2) Recent – only refresh if older than recent_cutoff
            # ----------------------
            recent_created_at = inst_insights.get("recent")

            if recent_created_at is not None:
                # recent_created_at is already UTC-aware from get_existing_insights
                if recent_created_at >= recent_cutoff:
                    skipped_recent_fresh += 1
                    log.info(
                        f"[{idx}/{len(focus_rows)}] {ticker} ({inst_id}) "
                        f"kind=recent SKIP (fresh: {recent_created_at.isoformat()})"
                    )
                    continue  # no call for recent

            # If we reach here: either no recent insight, or it's stale
            try:
                source = call_insight_api(inst_id, "recent")
                total_calls += 1
                if source == "llm":
                    total_llm += 1
                elif source == "cache":
                    total_cache += 1

                log.info(
                    f"[{idx}/{len(focus_rows)}] {ticker} ({inst_id}) "
                    f"kind=recent source={source}"
                )
            except Exception as e:
                log.error(
                    f"Error prewarming recent for {ticker} ({inst_id}): {e}"
                )
            else:
                time.sleep(SLEEP_SECONDS)

        log.info(
            "Done prewarming. "
            f"calls={total_calls}, from_cache={total_cache}, from_llm={total_llm}, "
            f"skipped_overview={skipped_overview}, "
            f"skipped_recent_fresh={skipped_recent_fresh}"
        )

    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    prewarm()