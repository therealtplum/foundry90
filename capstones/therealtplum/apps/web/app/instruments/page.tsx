// Instruments - Coming Soon (hidden until ready for production)
import Link from "next/link";

export default function InstrumentsPage() {
  return (
    <main className="f90-page">
      <section className="f90-hero" style={{ minHeight: "60vh", display: "flex", alignItems: "center", justifyContent: "center" }}>
        <div className="f90-hero-inner" style={{ textAlign: "center" }}>
          <h1 className="f90-hero-title" style={{ marginBottom: "1rem" }}>
            <span className="f90-type">Instruments</span>
          </h1>
          <p className="f90-hero-subtitle" style={{ marginBottom: "2rem" }}>
            Coming soon. This feature is under development.
          </p>
          <div className="f90-hero-actions">
            <Link href="/" className="f90-btn f90-btn-primary">
              Back to Home
            </Link>
            <Link href="/capstones" className="f90-btn f90-btn-ghost">
              Explore capstones
            </Link>
          </div>
        </div>
      </section>
    </main>
  );
}
