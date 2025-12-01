// News Widget - Relevant market news articles
"use client";

import { useState, useEffect } from "react";
import { BaseWidget } from "./BaseWidget";

interface NewsItem {
  id: string;
  title: string;
  source: string;
  published_at: string;
  url?: string;
  summary?: string;
}

export function NewsWidget() {
  const [news, setNews] = useState<NewsItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadNews() {
      try {
        setLoading(true);
        // TODO: Replace with actual news API endpoint
        // For now, use placeholder data
        const placeholderNews: NewsItem[] = [
          {
            id: "1",
            title: "Market opens higher on strong earnings reports",
            source: "Financial Times",
            published_at: new Date(Date.now() - 3600000).toISOString(),
            summary: "Major indices rise as tech companies report better-than-expected Q4 results.",
          },
          {
            id: "2",
            title: "Fed signals potential rate cuts in Q2",
            source: "Bloomberg",
            published_at: new Date(Date.now() - 7200000).toISOString(),
            summary: "Federal Reserve hints at easing monetary policy amid cooling inflation.",
          },
          {
            id: "3",
            title: "Oil prices surge on supply concerns",
            source: "Reuters",
            published_at: new Date(Date.now() - 10800000).toISOString(),
            summary: "Crude oil futures jump 3% following geopolitical tensions.",
          },
        ];
        setNews(placeholderNews);
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load news");
      } finally {
        setLoading(false);
      }
    }
    loadNews();
  }, []);

  const formatTime = (isoString: string) => {
    const date = new Date(isoString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);

    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    return date.toLocaleDateString();
  };

  return (
    <BaseWidget
      title="Market News"
      loading={loading}
      error={error}
      actions={
        <button className="markets-widget-action-btn" title="Refresh news">
          ↻
        </button>
      }
    >
      <div className="markets-news">
        {news.length === 0 && !loading && (
          <div className="markets-widget-empty">No news available</div>
        )}
        {news.map((item) => (
          <a
            key={item.id}
            href={item.url || "#"}
            target={item.url ? "_blank" : undefined}
            rel={item.url ? "noopener noreferrer" : undefined}
            className="markets-news-item"
          >
            <div className="markets-news-item-header">
              <span className="markets-news-source">{item.source}</span>
              <span className="markets-news-time">{formatTime(item.published_at)}</span>
            </div>
            <h4 className="markets-news-title">{item.title}</h4>
            {item.summary && (
              <p className="markets-news-summary">{item.summary}</p>
            )}
          </a>
        ))}
      </div>
    </BaseWidget>
  );
}

