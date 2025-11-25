"use client";

import { useEffect, useState } from "react";
import {
  getFocusTickerStrip,
  type FocusTickerStripItem,
} from "@/lib/api";

const ROW_COUNT = 4;

export default function FocusTickerStrip() {
  const [tickers, setTickers] = useState<FocusTickerStripItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [hoveredId, setHoveredId] = useState<number | null>(null);
  const [isPaused, setIsPaused] = useState(false);

  useEffect(() => {
    let cancelled = false;

    (async () => {
      try {
        const data = await getFocusTickerStrip();
        if (!cancelled) setTickers(data);
      } catch (err) {
        console.error(err);
        if (!cancelled) {
          setError("Unable to load focus universe right now.");
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  if (error) {
    // Very subtle error background instead of blowing up the page.
    return (
      <div className="w-full h-full flex items-center justify-center bg-black/90 text-red-300/80 text-xs">
        {error}
      </div>
    );
  }

  if (!tickers.length) {
    // Soft loading shimmer for background.
    return (
      <div className="w-full h-full bg-[radial-gradient(circle_at_top,_rgba(34,197,94,0.25),_transparent_60%)] animate-pulse" />
    );
  }

  // Split into a few rows for a nice dense wall of motion
  const rows: FocusTickerStripItem[][] = Array.from(
    { length: ROW_COUNT },
    (_, rowIdx) => tickers.filter((_, i) => i % ROW_COUNT === rowIdx),
  );

  const hovered = tickers.find((t) => t.instrument_id === hoveredId) ?? null;

  return (
    <div
      className="w-full h-full bg-black/95 text-[10px] md:text-xs text-green-400/80 relative overflow-hidden"
      onMouseEnter={() => setIsPaused(true)}
      onMouseLeave={() => {
        setIsPaused(false);
        setHoveredId(null);
      }}
    >
      {/* ticker rows */}
      <div className="absolute inset-0 pointer-events-auto">
        {rows.map((row, idx) => {
          const direction =
            idx % 2 === 0 ? "animate-ticker-left" : "animate-ticker-right";
          const speedClass = idx % 2 === 0 ? "duration-[45s]" : "duration-[60s]";
          const pauseClass = isPaused ? "paused" : "";

          // Duplicate per row so the marquee loops cleanly
          const rowItems = [...row, ...row];

          return (
            <div
              key={idx}
              className={`whitespace-nowrap flex items-center gap-4 opacity-60 hover:opacity-95 transition-opacity
                          ${direction} ${speedClass} ${pauseClass}`}
              style={{
                // vertical placement
                top: `${(idx + 0.5) * (100 / ROW_COUNT)}%`,
                position: "absolute",
                transform: "translateY(-50%)",
              }}
            >
              {rowItems.map((item, i) => (
                <button
                  key={`${item.instrument_id}-${i}`}
                  type="button"
                  className={`inline-flex items-center gap-2 rounded-full border border-green-500/40 px-3 py-1.5
                              bg-black/60 hover:bg-black/90 hover:border-green-400/80
                              shadow-[0_0_6px_rgba(34,197,94,0.65)]
                              transition-colors transition-shadow`}
                  onMouseEnter={() => setHoveredId(item.instrument_id)}
                  onMouseLeave={() =>
                    setHoveredId((prev) =>
                      prev === item.instrument_id ? null : prev,
                    )
                  }
                >
                  <span className="font-semibold text-[#39ff14] tracking-wide">
                    {item.ticker}
                  </span>
                  <span className="text-green-300/80 max-w-[11rem] truncate hidden sm:inline">
                    {item.name}
                  </span>
                  {typeof item.last_close_price === "number" && (
                    <span className="text-green-400/80 tabular-nums">
                      ${item.last_close_price.toFixed(2)}
                    </span>
                  )}
                  <span className="uppercase text-[0.6rem] text-green-400/60">
                    {item.asset_class}
                  </span>
                </button>
              ))}
            </div>
          );
        })}
      </div>

      {/* Hover insight card */}
      {hovered && (
        <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
          <div className="max-w-md w-[90%] md:w-[440px] rounded-xl border border-green-400/60 bg-black/92 backdrop-blur-sm p-4 shadow-[0_0_18px_rgba(74,222,128,0.75)] text-left">
            <div className="flex items-baseline justify-between gap-3 mb-2">
              <div>
                <div className="text-[#39ff14] font-semibold tracking-wide text-sm md:text-base">
                  {hovered.ticker}
                </div>
                <div className="text-green-200/80 text-xs md:text-sm">
                  {hovered.name}
                </div>
              </div>
              <div className="text-right text-xs text-green-300/80">
                {typeof hovered.last_close_price === "number" && (
                  <div className="font-mono">
                    ${hovered.last_close_price.toFixed(2)}
                  </div>
                )}
                <div className="uppercase text-[0.6rem] text-green-400/60">
                  {hovered.asset_class}
                </div>
              </div>
            </div>

            {/* Overview */}
            {hovered.short_insight && (
              <div className="mb-2">
                <div className="text-[0.6rem] uppercase tracking-[0.16em] text-green-500/80 mb-1">
                  Overview
                </div>
                <p className="text-[0.78rem] leading-snug text-green-100/90 whitespace-pre-line line-clamp-4">
                  {hovered.short_insight}
                </p>
              </div>
            )}

            {/* Recent */}
            {hovered.recent_insight && (
              <div className="mt-2 border-t border-green-500/20 pt-2">
                <div className="text-[0.6rem] uppercase tracking-[0.16em] text-green-500/80 mb-1">
                  Recent Developments
                </div>
                <p className="text-[0.78rem] leading-snug text-green-100/90 whitespace-pre-line line-clamp-4">
                  {hovered.recent_insight}
                </p>
              </div>
            )}

            {!hovered.short_insight && !hovered.recent_insight && (
              <p className="text-[0.78rem] text-green-200/80">
                Analyst notes are still loading for this instrument. Try another
                ticker in the stream.
              </p>
            )}
          </div>
        </div>
      )}
    </div>
  );
}