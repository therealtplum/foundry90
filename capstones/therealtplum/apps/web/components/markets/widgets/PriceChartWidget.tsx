// Price Chart Widget - Price chart for selected instrument
"use client";

import { useState } from "react";
import { BaseWidget } from "./BaseWidget";

export function PriceChartWidget() {
  const [selectedTicker, setSelectedTicker] = useState<string>("");

  return (
    <BaseWidget
      title="Price Chart"
      className="markets-widget-chart"
      actions={
        <select
          className="markets-widget-select"
          value={selectedTicker}
          onChange={(e) => setSelectedTicker(e.target.value)}
        >
          <option value="">Select ticker...</option>
          <option value="AAPL">AAPL</option>
          <option value="TSLA">TSLA</option>
          <option value="MSFT">MSFT</option>
        </select>
      }
    >
      <div className="markets-chart">
        {!selectedTicker ? (
          <div className="markets-widget-empty">
            <span>Select a ticker to view chart</span>
          </div>
        ) : (
          <div className="markets-chart-placeholder">
          <div className="markets-chart-placeholder-content">
            <span className="markets-chart-placeholder-icon">—</span>
            <span className="markets-chart-placeholder-text">
              Chart for {selectedTicker} will be displayed here
            </span>
              <span className="markets-chart-placeholder-note">
                Integration with charting library (e.g., TradingView, Chart.js) coming soon
              </span>
            </div>
          </div>
        )}
      </div>
    </BaseWidget>
  );
}

