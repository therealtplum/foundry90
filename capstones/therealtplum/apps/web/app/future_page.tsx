// apps/web/app/page.tsx

import Link from "next/link";

export default function HomePage() {
  return (
    <main className="f90-page">
      {/* Hero */}
      <section className="f90-hero">
        <div className="f90-hero-inner">
          <div className="f90-pill">CAPSTONES</div>

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
            <Link href="/instruments" className="f90-btn f90-btn-ghost">
              View fmhub / therealtplum
            </Link>
          </div>

          <div className="f90-hero-meta">
            <span>Rust · Python · Next.js · Postgres</span>
            <span className="f90-dot" />
            <span>90 days is all it takes</span>
          </div>
        </div>

        <div className="f90-hero-panel">
          <div className="f90-hero-logo-card">
            <div className="f90-logo-pill">90</div>
            <div className="f90-logo-caption">Foundry90 Studio</div>
          </div>

          <div className="f90-hero-metrics">
            <div className="f90-metric">
              <div className="f90-metric-label">Current capstones</div>
              <div className="f90-metric-value">01</div>
              <div className="f90-metric-note">fmhub / therealtplum</div>
            </div>

            <div className="f90-metric">
              <div className="f90-metric-label">Stack depth</div>
              <div className="f90-metric-value">Full</div>
              <div className="f90-metric-note">ETL → API → UI</div>
            </div>

            <div className="f90-metric">
              <div className="f90-metric-label">Engagements</div>
              <div className="f90-metric-value">Limited</div>
              <div className="f90-metric-note">One capstone at a time</div>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="f90-footer">
        <div className="f90-footer-left">
          <span className="f90-footer-mark">FOUNDRY90</span>
          <span className="f90-dot" />
        </div>
        <div className="f90-footer-right">
          <a href="https://github.com/therealtplum/foundry90/" className="f90-link">
            foundry90 on GitHub
          </a>
        </div>
      </footer>
    </main>
  );
}