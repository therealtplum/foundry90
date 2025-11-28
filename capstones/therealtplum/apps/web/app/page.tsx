// apps/web/app/page.tsx

import Link from "next/link";

export default function HomePage() {
  return (
    <main className="f90-page">
      {/* Hero */}
      <section className="f90-hero">
        <div className="f90-hero-inner">

          <h1 className="f90-hero-title">
            <span className="f90-type">Foundry90_</span>
          </h1>

          <p className="f90-hero-subtitle">
            A small studio for building deep, production-grade data systems:
            ETL, APIs, and dashboards that actually ship.
          </p>

          <div className="f90-hero-actions">
            <Link href="markets" className="f90-btn f90-btn-primary">
              Markets Hub
            </Link>
            <Link href="capstones" className="f90-btn f90-btn-ghost">
              Explore capstones
            </Link>
          </div>

          <div className="f90-hero-meta">
            <div className="f90-hero-stack">
              Rust · Python · Next.js · Postgres · SwiftUI · LLM · AWS
            </div>
            <span className="f90-hero-timeline">90 days is all it takes</span>
          </div>
        </div>

        <div className="f90-hero-panel">
          <div className="f90-hero-logo-card">
            <div className="f90-logo-pill">90</div>
            <div className="f90-logo-caption">Foundry90 Studio</div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="f90-footer">
        <div className="f90-footer-right">
          <a
            href="https://github.com/therealtplum/foundry90/"
            className="f90-footer-link"
          >
            foundry90 on GitHub
          </a>
        </div>
      </footer>
    </main>
  );
}