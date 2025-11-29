// apps/web/components/auth/AuthButton.tsx
'use client';

import { useUser } from '@auth0/nextjs-auth0/client';
import Link from 'next/link';

export function AuthButton() {
  const { user, isLoading } = useUser();

  if (isLoading) {
    return (
      <div className="f90-auth-loading">
        Loading...
      </div>
    );
  }

  if (user) {
    return (
      <div className="f90-auth-user">
        <div className="f90-auth-user-info">
          {user.picture && (
            <img
              src={user.picture}
              alt={user.name || 'User'}
              className="f90-auth-avatar"
            />
          )}
          <span className="f90-auth-name">
            {user.name || user.email}
          </span>
        </div>
        <Link href="/auth/logout" className="f90-btn f90-btn-ghost">
          Logout
        </Link>
      </div>
    );
  }

  return (
    <Link href="/auth/login" className="f90-btn f90-btn-primary">
      Login
    </Link>
  );
}

