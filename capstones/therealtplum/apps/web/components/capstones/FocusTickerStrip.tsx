// apps/web/components/capstones/FocusTickerStrip.tsx
"use client";

import { useEffect, useState } from "react";
import sampleTickers from "@/data/sample_tickers.json";
import {
  getFocusTickerStrip,
  type FocusTickerStripItem,
} from "@/lib/api";

/**
 * Raw items can have either:
 * - short_insight / recent_insight
 * - or short / recent
 * (we'll normalize both into short_insight / recent_insight)
 */
type RawTicker = FocusTickerStripItem & {
  short?: string | null;
  recent?: string | null;
  short_insight?: string | null;
  recent_insight?: string | null;
};

type FocusTickerWithInsights = FocusTickerStripItem & {
  short_insight?: string | null;
  recent_insight?: string | null;
};

function normalizeTicker(raw: RawTicker): FocusTickerWithInsights {
  return {
    ...raw,
    short_insight: raw.short_insight ?? raw.short ?? null,
    recent_insight: raw.recent_insight ?? raw.recent ?? null,
  };
}

/**
 * Static fallback focus universe, normalized so insights always live on:
 *   short_insight / recent_insight
 */
const STATIC_TICKERS: FocusTickerWithInsights[] = (sampleTickers as RawTicker[]).map(
  normalizeTicker,
);

function formatPrice(value: string | number): string {
  const num =
    typeof value === "number" ? value : parseFloat(String(value).replace(/[^0-9.-]/g, ""));
  if (!isFinite(num)) return "";
  return num.toFixed(2);
}

export default function FocusTickerStrip() {
  const [items, setItems] = useState<FocusTickerWithInsights[]>(STATIC_TICKERS);
  const [isHovered, setIsHovered] = useState(false);
  const [selected, setSelected] = useState<FocusTickerWithInsights | null>(null);
  const [hasTriedApi, setHasTriedApi] = useState(false);

  // Load from API, fall back to static JSON
  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const data = await getFocusTickerStrip();
        setHasTriedApi(true);
        if (!cancelled && Array.isArray(data) && data.length > 0) {
          const normalized = (data as RawTicker[]).map(normalizeTicker);
          setItems(normalized);
        }
      } catch (err) {
        console.error("Failed to load focus ticker strip:", err);
        setHasTriedApi(true);
        if (!cancelled) {
          setItems(STATIC_TICKERS);
        }
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, []);

  if (!items || items.length === 0) {
    return (
      <div className="fmhub-board-status">
        {hasTriedApi
          ? "No instruments available in the focus universe."
          : "Booting FMHub board …"}
      </div>
    );
  }

  const stripClassName = `f90-ticker-strip${
    isHovered ? " f90-ticker-strip-paused" : ""
  }`;

  // Don’t create more rows than we have items
  const rowCount = Math.min(6, items.length);

  // Partition items so each ticker belongs to exactly one row
  const baseCount = Math.floor(items.length / rowCount);
  const remainder = items.length % rowCount;

  const rowPartitions: FocusTickerWithInsights[][] = [];
  let cursor = 0;

  for (let r = 0; r < rowCount; r++) {
    const extra = r < remainder ? 1 : 0; // first few rows get one extra
    const count = baseCount + extra;
    if (count <= 0) {
      rowPartitions.push([]);
      continue;
    }
    const rowItems = items.slice(cursor, cursor + count);
    cursor += count;
    rowPartitions.push(rowItems);
  }

  return (
    <>
      <div
        className={stripClassName}
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
      >
        {rowPartitions.map((rowItems, rowIndex) => {
          const directionClass =
            rowIndex % 2 === 0 ? "f90-ticker-row-left" : "f90-ticker-row-right";

          return (
            <div
              key={rowIndex}
              className={`f90-ticker-row ${directionClass}`}
            >
              {/* duplicate this row’s sequence twice for continuous scroll */}
              {[0, 1].map((loop) => (
                <span key={loop}>
                  {rowItems.map((item, idx) => (
                    <button
                      key={`${rowIndex}-${loop}-${idx}-${item.instrument_id ?? item.ticker}`}
                      type="button"
                      className="f90-ticker-chip"
                      onClick={() =>
                        setSelected((prev) =>
                          prev && prev.ticker === item.ticker ? null : item,
                        )
                      }
                    >
                      <span className="f90-ticker-symbol">{item.ticker}</span>
                      <span>{item.name}</span>
                      {item.last_close_price && (
                        <span className="f90-ticker-price">
                          ${formatPrice(item.last_close_price as any)}
                        </span>
                      )}
                    </button>
                  ))}
                </span>
              ))}
            </div>
          );
        })}
      </div>

      {selected && (
        <div className="f90-ticker-insight">
          <div className="f90-ticker-insight-header">
            <span className="f90-ticker-insight-symbol">{selected.ticker}</span>
            <span className="f90-ticker-insight-name">{selected.name}</span>
          </div>
          <div className="f90-ticker-insight-body">
            {selected.recent_insight ||
              selected.short_insight ||
              "No LLM insight cached yet for this instrument. Pipeline warming up."}
          </div>
        </div>
      )}
    </>
  );
}