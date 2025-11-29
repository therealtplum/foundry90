// Market Overview Widget - Key market metrics and indices
"use client";

import { useState, useEffect } from "react";
import { BaseWidget } from "./BaseWidget";
import { FocusTickerStripItem, getFocusTickerStrip } from "../../../lib/api";

interface MarketMetric {
  name: string;
  value: number;
  change: number;
  changePercent: number;
}

export function MarketOverviewWidget() {
  const [metrics, setMetrics] = useState<MarketMetric[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadMetrics() {
      try {
        setLoading(true);
        // Get focus tickers and aggregate by asset class
        const data = await getFocusTickerStrip(50);
        
        // Group by asset class and calculate averages
        const assetClassMap = new Map<string, { total: number; count: number; changes: number[] }>();
        
        data.forEach((item) => {
          if (item.last_close_price && item.day_over_day_change_percent !== null && item.day_over_day_change_percent !== undefined) {
            const price = parseFloat(item.last_close_price);
            const change = item.day_over_day_change_percent;
            
            if (!assetClassMap.has(item.asset_class)) {
              assetClassMap.set(item.asset_class, { total: 0, count: 0, changes: [] });
            }
            const entry = assetClassMap.get(item.asset_class)!;
            entry.total += price;
            entry.count += 1;
            entry.changes.push(change);
          }
        });

        const metricsList: MarketMetric[] = Array.from(assetClassMap.entries())
          .map(([assetClass, data]) => {
            const avgPrice = data.total / data.count;
            const avgChange = data.changes.reduce((a, b) => a + b, 0) / data.changes.length;
            return {
              name: assetClass,
              value: avgPrice,
              change: avgChange,
              changePercent: avgChange,
            };
          })
          .slice(0, 6); // Top 6 asset classes

        setMetrics(metricsList);
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load market overview");
      } finally {
        setLoading(false);
      }
    }
    loadMetrics();
  }, []);

  const formatValue = (value: number) => {
    if (value >= 1000) {
      return `$${(value / 1000).toFixed(2)}K`;
    }
    return `$${value.toFixed(2)}`;
  };

  const formatChange = (change: number) => {
    const sign = change >= 0 ? "+" : "";
    return `${sign}${change.toFixed(2)}%`;
  };

  const getChangeClass = (change: number) => {
    if (change > 0) return "markets-metric-change-up";
    if (change < 0) return "markets-metric-change-down";
    return "markets-metric-change-flat";
  };

  return (
    <BaseWidget
      title="Market Overview"
      loading={loading}
      error={error}
      className="markets-widget-overview"
    >
      <div className="markets-overview">
        {metrics.length === 0 && !loading && (
          <div className="markets-widget-empty">No market data available</div>
        )}
        <div className="markets-overview-grid">
          {metrics.map((metric, idx) => (
            <div key={idx} className="markets-overview-metric">
              <div className="markets-overview-metric-header">
                <span className="markets-overview-metric-name">{metric.name}</span>
                <span className={`markets-overview-metric-change ${getChangeClass(metric.changePercent)}`}>
                  {formatChange(metric.changePercent)}
                </span>
              </div>
              <div className="markets-overview-metric-value">{formatValue(metric.value)}</div>
            </div>
          ))}
        </div>
      </div>
    </BaseWidget>
  );
}

