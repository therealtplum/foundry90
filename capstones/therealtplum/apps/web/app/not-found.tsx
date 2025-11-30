// apps/web/app/not-found.tsx

import Link from "next/link";

export default function NotFound() {
  return (
    <main className="f90-page">
      <div className="f90-404-container">
        <div className="f90-404-content">
          <h1 className="f90-404-title">
            <span className="f90-404-code">404</span>
            <span className="f90-404-label">NOT_FOUND</span>
          </h1>
          
          <p className="f90-404-message">
            The page you&apos;re looking for doesn&apos;t exist or has been moved.
          </p>

          <div className="f90-404-actions">
            <Link href="/" className="f90-btn f90-btn-primary">
              Return to Foundry90.com
            </Link>
            <Link href="/capstones" className="f90-btn f90-btn-ghost">
              Explore capstones
            </Link>
          </div>
        </div>
      </div>
    </main>
  );
}

