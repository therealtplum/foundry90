// Markets Hub Layout - Container for the markets hub page
"use client";

import { ReactNode } from "react";
import Link from "next/link";

interface MarketsHubLayoutProps {
  children: ReactNode;
}

export function MarketsHubLayout({ children }: MarketsHubLayoutProps) {
  return (
    <div className="markets-hub-root">
      {/* Header */}
      <header className="markets-hub-header">
        <div className="markets-hub-header-inner">
          <div className="markets-hub-header-left">
            <Link href="/" className="markets-hub-logo">
              <span className="markets-hub-logo-text">FMHub</span>
              <span className="markets-hub-logo-badge">Markets</span>
            </Link>
          </div>
          <nav className="markets-hub-nav">
            <Link href="/markets" className="markets-hub-nav-link markets-hub-nav-link-active">
              Dashboard
            </Link>
            <Link href="/instruments" className="markets-hub-nav-link">
              Instruments
            </Link>
            <Link href="/capstones" className="markets-hub-nav-link">
              Capstones
            </Link>
          </nav>
        </div>
      </header>

      {/* Main Content */}
      <main className="markets-hub-main">
        <div className="markets-hub-container">
          {children}
        </div>
      </main>
    </div>
  );
}

