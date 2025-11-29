import Link from 'next/link';
import { AuthButton } from '../auth/AuthButton';

export function TopNav() {
  return (
    <header className="f90-nav">
      <div className="f90-nav-inner">
        <Link href="/" className="f90-nav-brand">
          <div className="f90-logo-pill">90</div>
          <span className="f90-nav-title">Foundry90</span>
        </Link>
        <AuthButton />
      </div>
    </header>
  );
}
