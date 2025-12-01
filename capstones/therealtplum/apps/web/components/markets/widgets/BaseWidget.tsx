// Base Widget Component - Common structure for all widgets
"use client";

import { ReactNode } from "react";

interface BaseWidgetProps {
  title: string;
  children: ReactNode;
  className?: string;
  actions?: ReactNode;
  loading?: boolean;
  error?: string | null;
}

export function BaseWidget({
  title,
  children,
  className = "",
  actions,
  loading = false,
  error = null,
}: BaseWidgetProps) {
  return (
    <div className={`markets-widget ${className}`}>
      <div className="markets-widget-header">
        <div className="markets-widget-title-group">
          <h3 className="markets-widget-title">{title}</h3>
        </div>
        {actions && <div className="markets-widget-actions">{actions}</div>}
      </div>
      <div className="markets-widget-content">
        {loading && (
          <div className="markets-widget-loading">
            <div className="markets-widget-spinner"></div>
            <span>Loading...</span>
          </div>
        )}
        {error && (
          <div className="markets-widget-error">
            <span>⚠️</span>
            <span>{error}</span>
          </div>
        )}
        {!loading && !error && children}
      </div>
    </div>
  );
}

