// apps/web/components/capstones/FocusTickerStrip.tsx
"use client";

import { useEffect, useState } from "react";
import sampleTickers from "@/data/sample_tickers.json";
import {
  getFocusTickerStrip,
  type FocusTickerStripItem,
} from "@/lib/api";

/**
 * Static fallback focus universe.
 * NOTE: last_close_price is a STRING here to match FocusTickerStripItem.
 */
const STATIC_TICKERS: FocusTickerStripItem[] =
  sampleTickers as FocusTickerStripItem[];

// Extend with optional insight fields (in case API/sample JSON omit them)
type FocusTickerWithInsights = FocusTickerStripItem & {
  short_insight?: string | null;
  recent_insight?: string | null;
};

function formatPrice(value: string | number): string {
  const num =
    typeof value === "number" ? value : parseFloat(String(value).replace(/[^0-9.-]/g, ""));
  if (!isFinite(num)) return "";
  return num.toFixed(2);
}

export default function FocusTickerStrip() {
  const [items, setItems] = useState<FocusTickerWithInsights[]>(
    STATIC_TICKERS as FocusTickerWithInsights[],
  );
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
          setItems(data as FocusTickerWithInsights[]);
        }
      } catch (err) {
        console.error("Failed to load focus ticker strip:", err);
        setHasTriedApi(true);
        if (!cancelled) {
          setItems(STATIC_TICKERS as FocusTickerWithInsights[]);
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

  const rows = 6;
  const rowIndexes = Array.from({ length: rows }, (_, i) => i);

  return (
    <div
      className={stripClassName}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      {rowIndexes.map((rowIndex) => {
        const directionClass =
          rowIndex % 2 === 0 ? "f90-ticker-row-left" : "f90-ticker-row-right";

        return (
          <div
            key={rowIndex}
            className={`f90-ticker-row ${directionClass}`}
          >
            {/* duplicate list twice for continuous scroll */}
            {[0, 1].map((loop) => (
              <span key={loop}>
                {items.map((item) => (
                  <button
                    key={`${rowIndex}-${loop}-${item.instrument_id ?? item.ticker}`}
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

      {/* LLM insight pill in bottom-right */}
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
    </div>
  );
}