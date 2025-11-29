// apps/web/components/auth/UserProfile.tsx
'use client';

import { useUser } from '@auth0/nextjs-auth0/client';

export function UserProfile() {
  const { user, isLoading, error } = useUser();

  if (isLoading) {
    return (
      <div className="p-4 text-sm text-slate-400">
        Loading user profile...
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-4 text-sm text-red-400">
        Error loading profile: {error.message}
      </div>
    );
  }

  if (!user) {
    return (
      <div className="p-4 text-sm text-slate-400">
        Not authenticated. Please log in.
      </div>
    );
  }

  return (
    <div className="p-6 space-y-4">
      <div className="flex items-center gap-4">
        {user.picture && (
          <img
            src={user.picture}
            alt={user.name || 'User'}
            className="h-16 w-16 rounded-full border-2 border-slate-700"
          />
        )}
        <div>
          <h2 className="text-lg font-semibold text-slate-50">
            {user.name || 'User'}
          </h2>
          {user.email && (
            <p className="text-sm text-slate-400">{user.email}</p>
          )}
        </div>
      </div>

      <div className="space-y-2 pt-4 border-t border-slate-800">
        <h3 className="text-sm font-semibold text-slate-300 uppercase tracking-wide">
          Profile Information
        </h3>
        <dl className="space-y-2 text-sm">
          {user.sub && (
            <div>
              <dt className="text-slate-400">User ID</dt>
              <dd className="text-slate-200 font-mono text-xs">{user.sub}</dd>
            </div>
          )}
          {user.email_verified !== undefined && (
            <div>
              <dt className="text-slate-400">Email Verified</dt>
              <dd className="text-slate-200">
                {user.email_verified ? 'Yes' : 'No'}
              </dd>
            </div>
          )}
          {user.nickname && (
            <div>
              <dt className="text-slate-400">Nickname</dt>
              <dd className="text-slate-200">{user.nickname}</dd>
            </div>
          )}
        </dl>
      </div>

      {user && Object.keys(user).length > 0 && (
        <details className="pt-4 border-t border-slate-800">
          <summary className="text-sm font-semibold text-slate-300 uppercase tracking-wide cursor-pointer">
            Raw User Data
          </summary>
          <pre className="mt-2 p-4 bg-slate-900 rounded-md text-xs text-slate-300 overflow-auto">
            {JSON.stringify(user, null, 2)}
          </pre>
        </details>
      )}
    </div>
  );
}

