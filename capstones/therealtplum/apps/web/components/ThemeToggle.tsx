// apps/web/components/ThemeToggle.tsx
"use client";

import { useEffect, useState } from "react";

const THEME_KEY = "f90-theme";

type Theme = "hacker" | "kawaii";

export default function ThemeToggle() {
  const [theme, setTheme] = useState<Theme>("hacker");

  // On mount: read saved theme and apply to body
  useEffect(() => {
    if (typeof window === "undefined") return;

    const stored = window.localStorage.getItem(THEME_KEY) as Theme | null;
    const initial: Theme = stored === "kawaii" ? "kawaii" : "hacker";

    setTheme(initial);
    if (initial === "kawaii") {
      document.body.classList.add("f90-theme-kawaii");
    } else {
      document.body.classList.remove("f90-theme-kawaii");
    }
  }, []);

  // Whenever theme changes, sync body class + localStorage
  useEffect(() => {
    if (typeof window === "undefined") return;

    if (theme === "kawaii") {
      document.body.classList.add("f90-theme-kawaii");
      window.localStorage.setItem(THEME_KEY, "kawaii");
    } else {
      document.body.classList.remove("f90-theme-kawaii");
      window.localStorage.setItem(THEME_KEY, "hacker");
    }
  }, [theme]);

  // Show the *next* theme as the label
  const nextTheme: Theme = theme === "hacker" ? "kawaii" : "hacker";
  const label = nextTheme === "hacker" ? "Hacker" : "Kawaii";

  return (
    <div className="f90-theme-toggle-shell">
      <button
        type="button"
        onClick={() =>
          setTheme((prev) => (prev === "hacker" ? "kawaii" : "hacker"))
        }
        className="f90-theme-toggle-btn"
        aria-label={`Switch to ${label} theme`}
      >
        {label}
      </button>
    </div>
  );
}