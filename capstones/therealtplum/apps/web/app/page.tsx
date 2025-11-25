// apps/web/app/page.tsx
import Link from "next/link";
import FocusTickerStrip from "@/components/capstones/FocusTickerStrip";

export default function HomePage() {
  return (
    <main className="f90-page">
      {/* Hero */}
      <section className="f90-hero">
        <div className="f90-hero-inner">
          <h1 className="f90-hero-title">
            Foundry90
            <span className="f90-hero-title-accent">_</span>
          </h1>

          <p className="f90-hero-subtitle">
            A small studio for building deep, production-grade data systems:
            ETL, APIs, and dashboards that actually ship.
          </p>

          <div className="f90-hero-actions">
            <Link href="#capstones" className="f90-btn f90-btn-primary">
              Explore capstones
            </Link>
            <span className="f90-hero-secondary-note">Capstones in alpha</span>
          </div>

          <div className="f90-hero-meta">
            <span>Rust · Python · Next.js · Postgres · Swift</span>
            <span className="f90-dot" />
          </div>
        </div>

        <div className="f90-hero-panel">
          <div className="f90-hero-logo-card">
            <div className="f90-logo-pill">90</div>
            <div className="f90-logo-caption">Foundry90 Studio</div>
          </div>
        </div>
      </section>

      {/* Capstones – COMING SOON landing */}
      <section id="capstones" className="f90-capstones-section">
        <header className="f90-capstones-header">
          <h2 className="f90-capstones-title">Capstones</h2>
          <p className="f90-capstones-subtitle">
            A focused universe of high-signal tickers, with LLM analyst
            overlays.
          </p>
        </header>

        <FocusTickerStrip />
      </section>

      {/* Footer */}
      <footer className="f90-footer">
        <div className="f90-footer-right">
          <a
            href="https://github.com/therealtplum/foundry90/"
            className="f90-link"
          >
            foundry90 on GitHub
          </a>
        </div>
      </footer>
    </main>
  );
}