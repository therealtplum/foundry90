// apps/web/components/capstones/FocusTickerStrip.tsx
"use client";

import { useEffect, useState } from "react";
import sampleTickers from "@/data/sample_tickers.json";
import {
  getFocusTickerStrip,
  type FocusTickerStripItem,
} from "@/lib/api";
import { MarkdownCard } from "@/components/ui/MarkdownCard";

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

type ChangeDirection = "up" | "down" | "flat";

function computeChange(
  item: FocusTickerWithInsights,
): { direction: ChangeDirection; pctStr: string } | null {
  const last = item.last_close_price
    ? parseFloat(String(item.last_close_price))
    : NaN;
  const prior = (item as any).prior_day_last_close_price
    ? parseFloat(String((item as any).prior_day_last_close_price))
    : NaN;

  if (!isFinite(last) || !isFinite(prior) || prior === 0) {
    return null;
  }

  const delta = last - prior;
  const pct = (delta / prior) * 100;
  const direction: ChangeDirection =
    pct > 0.0001 ? "up" : pct < -0.0001 ? "down" : "flat";

  const pctStr = `${pct >= 0 ? "+" : ""}${pct.toFixed(2)}%`;

  return { direction, pctStr };
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

  // Fixed “board” look: up to 6 rows, but never more than we have items
  const MAX_ROWS = 6;
  const rowCount = Math.min(MAX_ROWS, items.length);

  // Round-robin partition: each ticker goes to exactly one row,
  // rows stay roughly the same size.
  const rowPartitions: FocusTickerWithInsights[][] = Array.from(
    { length: rowCount },
    () => [],
  );

  items.forEach((item, idx) => {
    const rowIndex = idx % rowCount;
    rowPartitions[rowIndex].push(item);
  });

  const selectedChange = selected ? computeChange(selected) : null;
  const pillClassName = `f90-ticker-insight ${
    selectedChange
      ? `f90-ticker-insight-${selectedChange.direction}`
      : "f90-ticker-insight-flat"
  }`;

  const selectedInsight =
    selected?.recent_insight ?? selected?.short_insight ?? null;

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
                  {rowItems.map((item, idx) => {
                    const change = computeChange(item);
                    const chipClassName =
                      "f90-ticker-chip " +
                      (change
                        ? `f90-ticker-chip-${change.direction}`
                        : "f90-ticker-chip-flat");

                    return (
                      <button
                        key={`${rowIndex}-${loop}-${idx}-${
                          item.instrument_id ?? item.ticker
                        }`}
                        type="button"
                        className={chipClassName}
                        onClick={() =>
                          setSelected((prev) =>
                            prev && prev.ticker === item.ticker ? null : item,
                          )
                        }
                      >
                        <span className="f90-ticker-symbol">{item.ticker}</span>

                        {change && (
                          <span
                            className={`f90-ticker-chip-change f90-ticker-chip-change-${change.direction}`}
                          >
                            <span className="f90-ticker-chip-change-arrow">
                              {change.direction === "up"
                                ? "▲"
                                : change.direction === "down"
                                ? "▼"
                                : "●"}
                            </span>
                            <span className="f90-ticker-chip-change-pct">
                              {change.pctStr}
                            </span>
                          </span>
                        )}

                        <span>{item.name}</span>
                        {item.last_close_price && (
                          <span className="f90-ticker-price">
                            ${formatPrice(item.last_close_price as any)}
                          </span>
                        )}
                      </button>
                    );
                  })}
                </span>
              ))}
            </div>
          );
        })}
      </div>

      {selected && (
        <div className={pillClassName}>
          <div className="f90-ticker-insight-header">
            {selectedChange && (
              <span
                className={`f90-ticker-insight-change f90-ticker-insight-change-${selectedChange.direction}`}
              >
                <span className="f90-ticker-insight-change-arrow">
                  {selectedChange.direction === "up"
                    ? "▲"
                    : selectedChange.direction === "down"
                    ? "▼"
                    : "●"}
                </span>
                <span className="f90-ticker-insight-change-pct">
                  {selectedChange.pctStr}
                </span>
              </span>
            )}
            <span className="f90-ticker-insight-symbol">{selected.ticker}</span>
            <span className="f90-ticker-insight-name">{selected.name}</span>
          </div>
          <div className="f90-ticker-insight-body">
            {selectedInsight ? (
              <MarkdownCard markdown={selectedInsight} />
            ) : (
              "No LLM insight cached yet for this instrument. Pipeline warming up."
            )}
          </div>
        </div>
      )}
    </>
  );
}