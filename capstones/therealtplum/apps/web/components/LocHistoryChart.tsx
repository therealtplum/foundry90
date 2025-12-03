"use client";

import React, { useMemo } from "react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
  Legend,
} from "recharts";

type LocSnapshot = {
  date: string; // ISO string
  sha: string;
  total_code: number;
  by_language: Record<string, number>;
};

type LocHistoryChartProps = {
  snapshots: LocSnapshot[];
};

function formatDateLabel(iso: string) {
  const d = new Date(iso);
  return d.toISOString().slice(0, 10); // YYYY-MM-DD
}

function formatK(n: number) {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + "M";
  if (n >= 1_000) return (n / 1_000).toFixed(1) + "k";
  return n.toString();
}

// Hard-coded focus languages from your cloc output
const FOCUS_LANGUAGES: string[] = [
  "Swift",
  "Rust",
  "Python",
  //"JSON",
  //"Markdown",
  "TypeScript",
  "CSS",
  "Bourne Shell",
];

const LANGUAGE_COLORS: Record<string, string> = {
  Swift: "#ff6b81",
  Rust: "#ffb347",
  Python: "#4da6ff",
  JSON: "#8e44ad",
  Markdown: "#2ecc71",
  TypeScript: "var(--f90-accent)",
  CSS: "#e67e22",
  "Bourne Shell": "#f1c40f",
  Other: "#8884d8",
};

export const LocHistoryChart: React.FC<LocHistoryChartProps> = ({ snapshots }) => {
  const { data } = useMemo(() => {
    if (!snapshots.length) {
      return { data: [] as any[] };
    }

    const data = snapshots.map((s) => {
      const date = formatDateLabel(s.date);

      const row: Record<string, any> = { date };
      let focusSum = 0;

      for (const lang of FOCUS_LANGUAGES) {
        const val = s.by_language?.[lang] ?? 0;
        row[lang] = val;
        focusSum += val;
      }

      const other = Math.max(0, s.total_code - focusSum);
      row["Other"] = other;

      return row;
    });

    return { data };
  }, [snapshots]);

  const stats = useMemo(() => {
    if (!snapshots.length) return null;

    const first = snapshots[0];
    const last = snapshots[snapshots.length - 1];

    const delta = last.total_code - first.total_code;

    // Calculate weeks between first and last snapshot
    const firstDate = new Date(first.date);
    const lastDate = new Date(last.date);
    const daysDiff = (lastDate.getTime() - firstDate.getTime()) / (1000 * 60 * 60 * 24);
    const weeksDiff = daysDiff / 7;
    const locPerWeek = weeksDiff > 0 ? delta / weeksDiff : 0;

    // Find favorite language (most used across all snapshots)
    const languageTotals: Record<string, number> = {};
    snapshots.forEach((snapshot) => {
      Object.entries(snapshot.by_language || {}).forEach(([lang, count]) => {
        languageTotals[lang] = (languageTotals[lang] || 0) + count;
      });
    });

    const favoriteLanguage = Object.entries(languageTotals).reduce(
      (max, [lang, count]) => (count > max.count ? { lang, count } : max),
      { lang: "Unknown", count: 0 }
    );

    return {
      firstDate: formatDateLabel(first.date),
      lastDate: formatDateLabel(last.date),
      firstLoc: first.total_code,
      lastLoc: last.total_code,
      locPerWeek,
      favoriteLanguage: favoriteLanguage.lang,
      favoriteLanguageCount: favoriteLanguage.count,
      delta,
    };
  }, [snapshots]);

  return (
    <div
      style={{
        background: "var(--f90-bg-soft)",
        border: "1px solid var(--f90-border)",
        borderRadius: "var(--f90-radius-lg)",
        padding: "24px",
      }}
    >
      <div style={{ marginBottom: "24px" }}>
        <div style={{ marginBottom: "16px" }}>
          <h2
            style={{
              fontSize: "20px",
              fontWeight: 600,
              color: "var(--f90-text)",
              marginBottom: "8px",
              fontFamily: "var(--f90-font-mono)",
              letterSpacing: "0.08em",
              textTransform: "uppercase",
            }}
          >
            LOC over time
          </h2>
          <p
            style={{
              fontSize: "13px",
              color: "var(--f90-text-soft)",
              lineHeight: "1.5",
              margin: 0,
            }}
          >
            Total lines of code in the repo, stacked by language.
          </p>
        </div>
        {stats && (
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(140px, 1fr))",
              gap: "16px",
            }}
          >
            <div className="f90-metric">
              <div className="f90-metric-label">Current LOC</div>
              <div
                className="f90-metric-value"
                style={{ color: "var(--f90-accent)" }}
              >
                {formatK(stats.lastLoc)}
              </div>
            </div>
            <div className="f90-metric">
              <div className="f90-metric-label">Favorite Language</div>
              <div
                className="f90-metric-value"
                style={{
                  color: "var(--f90-accent)",
                  fontSize: "18px",
                }}
              >
                {stats.favoriteLanguage}
              </div>
              <div className="f90-metric-note">
                {formatK(stats.favoriteLanguageCount)} total
              </div>
            </div>
            <div className="f90-metric">
              <div className="f90-metric-label">LOC/week avg</div>
              <div className="f90-metric-value">
                {stats.locPerWeek >= 0 ? "+" : ""}
                {formatK(Math.round(stats.locPerWeek))}
              </div>
            </div>
            <div className="f90-metric">
              <div className="f90-metric-label">Range</div>
              <div
                style={{
                  fontSize: "12px",
                  color: "var(--f90-text)",
                  fontFamily: "var(--f90-font-mono)",
                }}
              >
                {stats.firstDate} → {stats.lastDate}
              </div>
            </div>
          </div>
        )}
      </div>

      <div style={{ width: "100%", minWidth: 0, height: 320 }}>
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={data}>
            <CartesianGrid
              strokeDasharray="3 3"
              stroke="var(--f90-border)"
              opacity={0.2}
            />
            <XAxis
              dataKey="date"
              tick={{
                fontSize: 11,
                fill: "var(--f90-text-soft)",
                fontFamily: "var(--f90-font-mono)",
              }}
              stroke="var(--f90-border)"
            />
            <YAxis
              tickFormatter={formatK}
              tick={{
                fontSize: 11,
                fill: "var(--f90-text-soft)",
                fontFamily: "var(--f90-font-mono)",
              }}
              width={60}
              stroke="var(--f90-border)"
            />
            <Tooltip
              contentStyle={{
                backgroundColor: "var(--f90-bg-soft)",
                border: "1px solid var(--f90-border)",
                borderRadius: "var(--f90-radius-md)",
                color: "var(--f90-text)",
                fontFamily: "var(--f90-font-sans)",
              }}
              formatter={(value: any, name: string) => [
                (value as number).toLocaleString(),
                name,
              ]}
              labelFormatter={(label) => `Date: ${label}`}
            />
            <Legend
              wrapperStyle={{
                color: "var(--f90-text)",
                fontFamily: "var(--f90-font-sans)",
                fontSize: "12px",
              }}
            />

            {FOCUS_LANGUAGES.map((lang) => (
              <Bar
                key={lang}
                dataKey={lang}
                stackId="loc"
                name={lang}
                fill={LANGUAGE_COLORS[lang] ?? "#999"}
              />
            ))}

            <Bar
              dataKey="Other"
              stackId="loc"
              name="Other"
              fill={LANGUAGE_COLORS["Other"]}
            />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
};