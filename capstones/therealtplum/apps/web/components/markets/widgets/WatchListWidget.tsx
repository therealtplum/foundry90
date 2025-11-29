// Watch List Widget - User's custom watch list
"use client";

import { useState, useEffect } from "react";
import { BaseWidget } from "./BaseWidget";
import { FocusTickerStripItem, getFocusTickerStrip } from "../../../lib/api";

export function WatchListWidget() {
  const [watchList, setWatchList] = useState<FocusTickerStripItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadWatchList() {
      try {
        setLoading(true);
        // For now, use focus ticker strip as watch list
        // TODO: Replace with actual user watch list API
        const data = await getFocusTickerStrip(10);
        setWatchList(data);
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load watch list");
      } finally {
        setLoading(false);
      }
    }
    loadWatchList();
  }, []);

  const formatPrice = (price: string | null) => {
    if (!price) return "—";
    return parseFloat(price).toFixed(2);
  };

  const formatChange = (change: number | null | undefined) => {
    if (change === null || change === undefined) return null;
    const sign = change >= 0 ? "+" : "";
    return `${sign}${change.toFixed(2)}%`;
  };

  const getChangeClass = (change: number | null | undefined) => {
    if (change === null || change === undefined) return "";
    if (change > 0) return "markets-widget-change-up";
    if (change < 0) return "markets-widget-change-down";
    return "markets-widget-change-flat";
  };

  return (
    <BaseWidget
      title="Watch List"
      loading={loading}
      error={error}
      actions={
        <button className="markets-widget-action-btn" title="Add to watch list">
          +
        </button>
      }
    >
      <div className="markets-watchlist">
        {watchList.length === 0 && !loading && (
          <div className="markets-widget-empty">
            <span>No items in watch list</span>
            <button className="markets-widget-empty-btn">Add Ticker</button>
          </div>
        )}
        {watchList.map((item) => (
          <div key={item.instrument_id} className="markets-watchlist-item">
            <div className="markets-watchlist-item-main">
              <div className="markets-watchlist-item-header">
                <span className="markets-watchlist-ticker">{item.ticker}</span>
                <span className="markets-watchlist-asset-class">{item.asset_class}</span>
              </div>
              <div className="markets-watchlist-item-name">{item.name}</div>
            </div>
            <div className="markets-watchlist-item-price">
              <div className="markets-watchlist-price-value">
                ${formatPrice(item.last_close_price)}
              </div>
              {item.day_over_day_change_percent !== null && (
                <div className={`markets-watchlist-price-change ${getChangeClass(item.day_over_day_change_percent)}`}>
                  {formatChange(item.day_over_day_change_percent)}
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
    </BaseWidget>
  );
}

