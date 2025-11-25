// apps/web/components/capstones/TickerBoard.tsx

"use client";

import { useEffect, useState } from "react";
import {
  getFocusTickerStrip,
  type FocusTickerStripItem,
} from "@/lib/api";

type Status = "idle" | "loading" | "loaded" | "error";

// How many horizontal rows we want on screen
const ROW_COUNT = 6;

// We only need enough to fill the screen; no need to grab everything
const MAX_TICKERS = 80;

function formatPrice(value: string | null): string {
  if (!value) return "--";
  const num = Number(value);
  if (!Number.isFinite(num)) return value;
  return `$${num.toFixed(2)}`;
}

// Trim ultra-long issuer names down to “ticker board” length
function cleanName(raw: string): string {
  const firstComma = raw.indexOf(",");
  const base = firstComma > 0 ? raw.slice(0, firstComma) : raw;
  return base.length > 26 ? base.slice(0, 23) + "…" : base;
}

function distributeIntoRows(
  items: FocusTickerStripItem[],
  maxRows: number,
): FocusTickerStripItem[][] {
  if (items.length === 0) return [];
  const rowCount = Math.min(maxRows, items.length);
  const rows: FocusTickerStripItem[][] = Array.from(
    { length: rowCount },
    () => [],
  );

  items.forEach((item, idx) => {
    rows[idx % rowCount].push(item);
  });

  return rows;
}

export default function TickerBoard() {
  const [items, setItems] = useState<FocusTickerStripItem[]>([]);
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<string | null>(null);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setStatus("loading");
        const data = await getFocusTickerStrip(MAX_TICKERS);
        if (!cancelled) {
          setItems(data);
          setStatus("loaded");
        }
      } catch (err: any) {
        console.error("TickerBoard error:", err);
        if (!cancelled) {
          setError("Failed to load focus tickers.");
          setStatus("error");
        }
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, []);

  if (status === "error") {
    return (
      <main className="fmhub-board-status">
        {error}
      </main>
    );
  }

  if (items.length === 0) {
    return (
      <main className="fmhub-board-status">
        Loading focus universe…
      </main>
    );
  }

  const rows = distributeIntoRows(items, ROW_COUNT);

  return (
    <main className="fmhub-board-root">
      <div
        className={
          "f90-ticker-strip" + (paused ? " f90-ticker-strip-paused" : "")
        }
        onMouseEnter={() => setPaused(true)}
        onMouseLeave={() => setPaused(false)}
      >
        {rows.map((row, rowIndex) => {
          // Duplicate each row so the animation can wrap seamlessly
          const marqueeItems = [...row, ...row];
          const directionClass =
            rowIndex % 2 === 0
              ? "f90-ticker-row-left"
              : "f90-ticker-row-right";

          return (
            <div
              key={rowIndex}
              className={`f90-ticker-row ${directionClass}`}
            >
              {marqueeItems.map((item, idx) => (
                <span
                  key={`${item.instrument_id}-${idx}`}
                  className="f90-ticker-chip"
                >
                  <span className="f90-ticker-symbol">
                    {item.ticker}
                  </span>
                  <span>
                    {cleanName(item.name)}
                  </span>
                  <span className="f90-ticker-price">
                    {formatPrice(item.last_close_price)}
                  </span>
                </span>
              ))}
            </div>
          );
        })}
      </div>
    </main>
  );
}