"use client";

import React, { useState } from "react";

type LanguageInfo = {
  name: string;
  color: string;
  officialUrl: string;
  wikipediaUrl: string;
  useCases: string;
  industries: string;
  capstoneUsage: string;
};

const LANGUAGE_DATA: Record<string, LanguageInfo> = {
  Rust: {
    name: "Rust",
    color: "#ffb347",
    officialUrl: "https://www.rust-lang.org/",
    wikipediaUrl: "https://en.wikipedia.org/wiki/Rust_(programming_language)",
    useCases: "Systems programming, web servers, APIs, embedded systems, blockchain, and performance-critical applications.",
    industries: "Finance, tech infrastructure, gaming, embedded devices, and security-critical software.",
    capstoneUsage: "Used for the main API server (apps/rust-api). Handles all HTTP endpoints, database queries, Redis caching, and OpenAI integration for LLM-generated insights. Provides type-safe, high-performance data access for the web and future mobile/desktop clients.",
  },
  Python: {
    name: "Python",
    color: "#4da6ff",
    officialUrl: "https://www.python.org/",
    wikipediaUrl: "https://en.wikipedia.org/wiki/Python_(programming_language)",
    useCases: "Data processing, ETL pipelines, data analysis, web scraping, automation, and rapid prototyping.",
    industries: "Finance, data science, web development, automation, AI/ML, and scientific computing.",
    capstoneUsage: "Powers the ETL pipeline (apps/python-etl). Fetches market data from Polygon API, processes and normalizes financial instruments, prices, news, and macroeconomic indicators. Handles data transformation, batch processing, and database population tasks.",
  },
  TypeScript: {
    name: "TypeScript",
    color: "var(--f90-accent)",
    officialUrl: "https://www.typescriptlang.org/",
    wikipediaUrl: "https://en.wikipedia.org/wiki/TypeScript",
    useCases: "Frontend web development, full-stack applications, large-scale JavaScript projects, and type-safe client-side code.",
    industries: "Web development, fintech, SaaS, e-commerce, and enterprise software.",
    capstoneUsage: "Used for the entire web application (apps/web). Built with Next.js for server-side rendering, React components for UI, and TypeScript for type safety. Handles dashboard views, instrument browsing, chart visualization, and user interactions.",
  },
  Swift: {
    name: "Swift",
    color: "#ff6b81",
    officialUrl: "https://www.swift.org/",
    wikipediaUrl: "https://en.wikipedia.org/wiki/Swift_(programming_language)",
    useCases: "iOS and macOS app development, server-side Swift applications, and native Apple platform software.",
    industries: "Mobile development, fintech apps, healthcare, education, and consumer software.",
    capstoneUsage: "Used for native macOS and future iOS applications (clients/FMHubControl). Provides native UI/UX using SwiftUI, connects to the Rust API for data, and offers offline capabilities. Designed to share the same backend API as the web app.",
  },
  CSS: {
    name: "CSS",
    color: "#e67e22",
    officialUrl: "https://www.w3.org/Style/CSS/",
    wikipediaUrl: "https://en.wikipedia.org/wiki/CSS",
    useCases: "Web styling, responsive design, animations, UI component styling, and visual presentation.",
    industries: "Web development, design agencies, marketing, e-commerce, and all web-based industries.",
    capstoneUsage: "All styling for the web application. Uses Foundry90's custom design system with CSS variables for theming, custom fonts (monospace for headers, sans-serif for body), and responsive layouts. Includes chart styling, component styles, and global theme definitions.",
  },
  Shell: {
    name: "Shell",
    color: "#f1c40f",
    officialUrl: "https://www.gnu.org/software/bash/",
    wikipediaUrl: "https://en.wikipedia.org/wiki/Unix_shell",
    useCases: "Automation scripts, deployment, CI/CD pipelines, system administration, and development tooling.",
    industries: "DevOps, system administration, cloud infrastructure, and software development tooling.",
    capstoneUsage: "Various automation scripts for Docker management, database operations, ETL orchestration, and development workflows. Handles container lifecycle, data loading, schema migrations, and deployment tasks.",
  },
  "Bourne Shell": {
    name: "Shell",
    color: "#f1c40f",
    officialUrl: "https://www.gnu.org/software/bash/",
    wikipediaUrl: "https://en.wikipedia.org/wiki/Unix_shell",
    useCases: "Automation scripts, deployment, CI/CD pipelines, system administration, and development tooling.",
    industries: "DevOps, system administration, cloud infrastructure, and software development tooling.",
    capstoneUsage: "Various automation scripts for Docker management, database operations, ETL orchestration, and development workflows. Handles container lifecycle, data loading, schema migrations, and deployment tasks.",
  },
};

type LanguagePillsProps = {
  languages: string[];
};

export const LanguagePills: React.FC<LanguagePillsProps> = ({ languages }) => {
  const [expanded, setExpanded] = useState<string | null>(null);

  const toggleExpanded = (lang: string) => {
    setExpanded(expanded === lang ? null : lang);
  };

  return (
    <div
      style={{
        background: "var(--f90-bg-soft)",
        border: "1px solid var(--f90-border)",
        borderRadius: "var(--f90-radius-lg)",
        padding: "24px",
        marginTop: "24px",
      }}
    >
      <div style={{ marginBottom: "20px" }}>
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
          Languages
        </h2>
        <p
          style={{
            fontSize: "13px",
            color: "var(--f90-text-soft)",
            lineHeight: "1.5",
            margin: 0,
          }}
        >
          Click a language to learn more about its use in this capstone.
        </p>
      </div>

      <div
        style={{
          display: "flex",
          flexWrap: "wrap",
          gap: "12px",
          marginBottom: expanded ? "24px" : "0",
        }}
      >
        {languages.map((lang) => {
          // Map "Bourne Shell" to "Shell" for display, but keep original for lookup
          const displayLang = lang === "Bourne Shell" ? "Shell" : lang;
          const langData = LANGUAGE_DATA[lang] || LANGUAGE_DATA[displayLang];
          if (!langData) return null;

          const isExpanded = expanded === lang;
          const color = langData.color === "var(--f90-accent)" 
            ? "var(--f90-accent)" 
            : langData.color;

          return (
            <div key={lang} style={{ position: "relative" }}>
              <button
                onClick={() => toggleExpanded(lang)}
                style={{
                  display: "inline-flex",
                  alignItems: "center",
                  padding: "8px 16px",
                  borderRadius: "var(--f90-radius-sm)",
                  border: `1px solid ${color}`,
                  backgroundColor: isExpanded
                    ? `${color}20`
                    : "transparent",
                  color: isExpanded ? color : "var(--f90-text)",
                  fontFamily: "var(--f90-font-mono)",
                  fontSize: "12px",
                  fontWeight: 500,
                  letterSpacing: "0.05em",
                  textTransform: "uppercase",
                  cursor: "pointer",
                  transition: "all 0.2s ease",
                  boxShadow: isExpanded
                    ? `0 0 12px ${color}40`
                    : "none",
                }}
                onMouseEnter={(e) => {
                  if (!isExpanded) {
                    e.currentTarget.style.backgroundColor = `${color}15`;
                  }
                }}
                onMouseLeave={(e) => {
                  if (!isExpanded) {
                    e.currentTarget.style.backgroundColor = "transparent";
                  }
                }}
              >
                {langData.name}
                <span
                  style={{
                    marginLeft: "8px",
                    fontSize: "14px",
                    transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)",
                    transition: "transform 0.2s ease",
                    display: "inline-block",
                  }}
                >
                  ▼
                </span>
              </button>
            </div>
          );
        })}
      </div>

      {expanded && (() => {
        const langData = LANGUAGE_DATA[expanded] || LANGUAGE_DATA[expanded === "Bourne Shell" ? "Shell" : expanded];
        if (!langData) return null;
        
        const lang = langData;
        const color = lang.color === "var(--f90-accent)" 
          ? "var(--f90-accent)" 
          : lang.color;
        
        return (
          <div
            style={{
              borderTop: `1px solid var(--f90-border)`,
              paddingTop: "24px",
              animation: "fadeIn 0.2s ease",
            }}
          >
            <div style={{ marginBottom: "20px" }}>
              <h3
                style={{
                  fontSize: "16px",
                  fontWeight: 600,
                  color: color,
                  marginBottom: "12px",
                  fontFamily: "var(--f90-font-mono)",
                  letterSpacing: "0.05em",
                  textTransform: "uppercase",
                }}
              >
                {lang.name}
              </h3>
              <div
                style={{
                  display: "flex",
                  gap: "16px",
                  flexWrap: "wrap",
                  marginBottom: "16px",
                }}
              >
                <a
                  href={lang.officialUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{
                    color: color,
                    fontSize: "13px",
                    fontFamily: "var(--f90-font-mono)",
                    textDecoration: "none",
                    borderBottom: `1px solid ${color}60`,
                    transition: "border-color 0.2s ease",
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.borderBottomColor = color;
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.borderBottomColor = `${color}60`;
                  }}
                >
                  Official Website →
                </a>
                <a
                  href={lang.wikipediaUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{
                    color: color,
                    fontSize: "13px",
                    fontFamily: "var(--f90-font-mono)",
                    textDecoration: "none",
                    borderBottom: `1px solid ${color}60`,
                    transition: "border-color 0.2s ease",
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.borderBottomColor = color;
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.borderBottomColor = `${color}60`;
                  }}
                >
                  Wikipedia →
                </a>
              </div>
            </div>

            <div style={{ marginBottom: "16px" }}>
              <h4
                style={{
                  fontSize: "13px",
                  fontWeight: 600,
                  color: "var(--f90-text)",
                  marginBottom: "8px",
                  fontFamily: "var(--f90-font-mono)",
                  letterSpacing: "0.05em",
                  textTransform: "uppercase",
                }}
              >
                Primary Use Cases
              </h4>
              <p
                style={{
                  fontSize: "14px",
                  color: "var(--f90-text-soft)",
                  lineHeight: "1.6",
                  margin: 0,
                  fontFamily: "var(--f90-font-sans)",
                }}
              >
                {lang.useCases}
              </p>
            </div>

            <div style={{ marginBottom: "16px" }}>
              <h4
                style={{
                  fontSize: "13px",
                  fontWeight: 600,
                  color: "var(--f90-text)",
                  marginBottom: "8px",
                  fontFamily: "var(--f90-font-mono)",
                  letterSpacing: "0.05em",
                  textTransform: "uppercase",
                }}
              >
                Common Industries
              </h4>
              <p
                style={{
                  fontSize: "14px",
                  color: "var(--f90-text-soft)",
                  lineHeight: "1.6",
                  margin: 0,
                  fontFamily: "var(--f90-font-sans)",
                }}
              >
                {lang.industries}
              </p>
            </div>

            <div>
              <h4
                style={{
                  fontSize: "13px",
                  fontWeight: 600,
                  color: "var(--f90-text)",
                  marginBottom: "8px",
                  fontFamily: "var(--f90-font-mono)",
                  letterSpacing: "0.05em",
                  textTransform: "uppercase",
                }}
              >
                Usage in This Capstone
              </h4>
              <p
                style={{
                  fontSize: "14px",
                  color: "var(--f90-text-soft)",
                  lineHeight: "1.6",
                  margin: 0,
                  fontFamily: "var(--f90-font-sans)",
                }}
              >
                {lang.capstoneUsage}
              </p>
            </div>
          </div>
        );
      })()}

      <style jsx>{`
        @keyframes fadeIn {
          from {
            opacity: 0;
            transform: translateY(-8px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
      `}</style>
    </div>
  );
};

