// Positions Widget - Current positions across accounts
"use client";

import { useState, useEffect } from "react";
import { BaseWidget } from "./BaseWidget";

interface Position {
  ticker: string;
  name: string;
  quantity: number;
  average_price: number;
  current_price: number;
  unrealized_pnl: number;
  pnl_percent: number;
  broker: string;
}

export function PositionsWidget() {
  const [positions, setPositions] = useState<Position[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadPositions() {
      try {
        setLoading(true);
        // TODO: Replace with actual positions API endpoint
        // For now, fetch Kalshi positions
        const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:3000";
        const userId = "default"; // TODO: Get from auth context
        
        try {
          const res = await fetch(`${baseUrl}/kalshi/users/${userId}/account`);
          if (res.ok) {
            const data = await res.json();
            const positionsList: Position[] = (data.positions || []).map((pos: any) => ({
              ticker: pos.ticker,
              name: pos.ticker, // TODO: Get name from instruments table
              quantity: pos.position,
              average_price: parseFloat(pos.average_price.toString()),
              current_price: parseFloat(pos.current_price.toString()),
              unrealized_pnl: parseFloat(pos.unrealized_pnl.toString()),
              pnl_percent: pos.average_price > 0
                ? ((parseFloat(pos.current_price.toString()) - parseFloat(pos.average_price.toString())) / parseFloat(pos.average_price.toString())) * 100
                : 0,
              broker: "Kalshi",
            }));
            setPositions(positionsList);
          } else {
            setPositions([]);
          }
        } catch (err) {
          setPositions([]);
        }
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load positions");
      } finally {
        setLoading(false);
      }
    }
    loadPositions();
  }, []);

  const formatPrice = (price: number) => {
    return `$${price.toFixed(2)}`;
  };

  const formatPnl = (pnl: number) => {
    const sign = pnl >= 0 ? "+" : "";
    return `${sign}${pnl.toFixed(2)}`;
  };

  const getPnlClass = (pnl: number) => {
    if (pnl > 0) return "markets-position-pnl-up";
    if (pnl < 0) return "markets-position-pnl-down";
    return "markets-position-pnl-flat";
  };

  const totalPnl = positions.reduce((sum, pos) => sum + pos.unrealized_pnl, 0);

  return (
    <BaseWidget
      title="Positions"
      loading={loading}
      error={error}
      actions={
        <button className="markets-widget-action-btn" title="Refresh positions">
          ↻
        </button>
      }
    >
      <div className="markets-positions">
        {positions.length > 0 && (
          <div className="markets-positions-summary">
            <span className="markets-positions-summary-label">Total P&L</span>
            <span className={`markets-positions-summary-value ${getPnlClass(totalPnl)}`}>
              {formatPnl(totalPnl)}
            </span>
          </div>
        )}
        {positions.length === 0 && !loading && (
          <div className="markets-widget-empty">
            <span>No open positions</span>
          </div>
        )}
        <div className="markets-positions-list">
          {positions.map((position, idx) => (
            <div key={idx} className="markets-position-item">
              <div className="markets-position-header">
                <div className="markets-position-ticker-group">
                  <span className="markets-position-ticker">{position.ticker}</span>
                  <span className="markets-position-broker">{position.broker}</span>
                </div>
                <span className={`markets-position-pnl ${getPnlClass(position.unrealized_pnl)}`}>
                  {formatPnl(position.unrealized_pnl)}
                </span>
              </div>
              <div className="markets-position-name">{position.name}</div>
              <div className="markets-position-details">
                <div className="markets-position-detail">
                  <span className="markets-position-detail-label">Qty</span>
                  <span className="markets-position-detail-value">{position.quantity}</span>
                </div>
                <div className="markets-position-detail">
                  <span className="markets-position-detail-label">Avg</span>
                  <span className="markets-position-detail-value">{formatPrice(position.average_price)}</span>
                </div>
                <div className="markets-position-detail">
                  <span className="markets-position-detail-label">Current</span>
                  <span className="markets-position-detail-value">{formatPrice(position.current_price)}</span>
                </div>
                <div className="markets-position-detail">
                  <span className="markets-position-detail-label">P&L %</span>
                  <span className={`markets-position-detail-value ${getPnlClass(position.pnl_percent)}`}>
                    {formatPnl(position.pnl_percent)}%
                  </span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </BaseWidget>
  );
}

