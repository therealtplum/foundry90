// apps/web/components/capstones/FocusTickerStrip.tsx
"use client";

import sampleTickers from "@/data/sample_tickers.json";
import { useEffect, useState } from "react";
import {
  getFocusTickerStrip,
  type FocusTickerStripItem,
} from "@/lib/api";

/**
 * Static fallback focus universe.
 * NOTE: last_close_price is a STRING here to match FocusTickerStripItem.
 */
const STATIC_TICKERS: FocusTickerStripItem[] = sampleTickers;

/** Try live focus universe; fall back to null on any error. */
async function loadLive(limit = 96): Promise<FocusTickerStripItem[] | null> {
  try {
    const data = await getFocusTickerStrip(limit);
    if (!data || data.length === 0) return null;
    return data;
  } catch (err) {
    console.warn(
      "FocusTickerStrip: live load failed, using static fallback.",
      err,
    );
    return null;
  }
}

function formatPrice(value: string | null): string {
  if (!value) return "";
  const num = Number(value);
  if (!Number.isFinite(num)) return value;
  return num.toFixed(2);
}

export default function FocusTickerStrip() {
  // Start with static data so there is *always* something on screen.
  const [items, setItems] = useState<FocusTickerStripItem[]>(STATIC_TICKERS);

  useEffect(() => {
    let cancelled = false;

    (async () => {
      const live = await loadLive(128);
      if (!cancelled && live) {
        setItems(live);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  // We only need enough to fill the screen nicely.
  const MAX_ITEMS = 64;
  const baseItems = items.slice(0, MAX_ITEMS);

  // Duplicate so each row can scroll seamlessly.
  const loopItems = [...baseItems, ...baseItems];

  const ROWS = 4;
  const perRow = Math.ceil(loopItems.length / ROWS);
  const rowChunks = Array.from({ length: ROWS }, (_, rowIndex) =>
    loopItems.slice(rowIndex * perRow, (rowIndex + 1) * perRow),
  );

  return (
    <div className="f90-capstones-coming">
      {/* scrolling ticker background */}
      <div className="f90-ticker-strip">
        {rowChunks.map((row, rowIndex) => (
          <div
            key={rowIndex}
            className={`f90-ticker-row ${
              rowIndex % 2 === 0
                ? "f90-ticker-row-left"
                : "f90-ticker-row-right"
            }`}
            // Slightly different speeds to keep it organic
            style={{
              animationDuration: rowIndex % 2 === 0 ? "42s" : "54s",
            }}
          >
            {row.map((item, i) => (
              <span key={`${item.instrument_id}-${i}`} className="f90-ticker-chip">
                <span className="f90-ticker-symbol">{item.ticker}</span>
                <span>{item.name}</span>
                {item.last_close_price && (
                  <span className="f90-ticker-price">
                    ${formatPrice(item.last_close_price)}
                  </span>
                )}
              </span>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}