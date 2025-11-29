// apps/web/app/profile/page.tsx
import { UserProfile } from '../../components/auth/UserProfile';
import { ProtectedRoute } from '../../components/auth/ProtectedRoute';

export default function ProfilePage() {
  return (
    <ProtectedRoute>
      <div className="min-h-screen bg-slate-950">
        <div className="max-w-4xl mx-auto py-8 px-4">
          <h1 className="text-2xl font-bold text-slate-50 mb-6">User Profile</h1>
          <div className="bg-slate-900 rounded-lg border border-slate-800">
            <UserProfile />
          </div>
        </div>
      </div>
    </ProtectedRoute>
  );
}

