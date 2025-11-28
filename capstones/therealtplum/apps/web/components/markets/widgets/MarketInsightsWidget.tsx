// Market Insights Widget - Cross-asset class insights
"use client";

import { useState, useEffect } from "react";
import { BaseWidget } from "./BaseWidget";
import { FocusTickerStripItem, getFocusTickerStrip } from "../../../lib/api";

interface Insight {
  asset_class: string;
  ticker: string;
  name: string;
  insight: string;
  sentiment: "bullish" | "bearish" | "neutral";
}

export function MarketInsightsWidget() {
  const [insights, setInsights] = useState<Insight[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadInsights() {
      try {
        setLoading(true);
        // Get focus tickers and use their insights
        const data = await getFocusTickerStrip(5);
        const formattedInsights: Insight[] = data
          .filter((item) => item.recent_insight)
          .map((item) => ({
            asset_class: item.asset_class,
            ticker: item.ticker,
            name: item.name,
            insight: item.recent_insight || "No insight available",
            sentiment: item.day_over_day_change_percent && item.day_over_day_change_percent > 0
              ? "bullish"
              : item.day_over_day_change_percent && item.day_over_day_change_percent < 0
              ? "bearish"
              : "neutral",
          }));
        setInsights(formattedInsights);
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load insights");
      } finally {
        setLoading(false);
      }
    }
    loadInsights();
  }, []);

  const getSentimentClass = (sentiment: string) => {
    switch (sentiment) {
      case "bullish":
        return "markets-insight-bullish";
      case "bearish":
        return "markets-insight-bearish";
      default:
        return "markets-insight-neutral";
    }
  };

  return (
    <BaseWidget
      title="Market Insights"
      loading={loading}
      error={error}
      actions={
        <button className="markets-widget-action-btn" title="Refresh insights">
          ↻
        </button>
      }
    >
      <div className="markets-insights">
        {insights.length === 0 && !loading && (
          <div className="markets-widget-empty">No insights available</div>
        )}
        {insights.map((insight, idx) => (
          <div key={idx} className={`markets-insight-item ${getSentimentClass(insight.sentiment)}`}>
            <div className="markets-insight-header">
              <div className="markets-insight-ticker-group">
                <span className="markets-insight-ticker">{insight.ticker}</span>
                <span className="markets-insight-asset-class">{insight.asset_class}</span>
              </div>
              <span className={`markets-insight-sentiment markets-insight-sentiment-${insight.sentiment}`}>
                {insight.sentiment === "bullish" ? "▲" : insight.sentiment === "bearish" ? "▼" : "●"}
              </span>
            </div>
            <div className="markets-insight-name">{insight.name}</div>
            <div className="markets-insight-text">{insight.insight}</div>
          </div>
        ))}
      </div>
    </BaseWidget>
  );
}

