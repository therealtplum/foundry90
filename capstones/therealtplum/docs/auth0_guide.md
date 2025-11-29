# Auth0 Integration Guide

Complete guide for Auth0 authentication across web, desktop, and mobile applications.

## ⚠️ Security Notice

**IMPORTANT:** This documentation file previously contained actual Auth0 secrets that were accidentally committed to git. If you see this file in git history with real secrets:

1. **IMMEDIATELY rotate all Auth0 secrets:**
   - Generate a new `AUTH0_SECRET` (use `openssl rand -hex 32`)
   - Regenerate `AUTH0_CLIENT_SECRET` in Auth0 Dashboard → Applications → foundry90-web → Settings → "Regenerate Client Secret"
   - Update all environment variables with the new values

2. **Never commit secrets to git** - always use placeholder values in documentation

3. **Consider using git-secrets or similar tools** to prevent committing secrets in the future

## Overview

This project uses Auth0 for authentication across:
- **Web** (Next.js 14 App Router)
- **Desktop** (SwiftUI macOS app - future)
- **Mobile** (SwiftUI iOS app - future)
- **Backend API** (Rust/Axum with JWT validation)

## Architecture

### Authentication Flow

- **Web**: Uses Auth0 Next.js SDK v4 with middleware-based routing
- **Native Apps**: Will use Auth0 Swift SDK with PKCE (OAuth 2.0)
- **Backend**: Validates JWT tokens from Auth0 using JWKS

### Security

- PKCE for all OAuth flows
- Secure token storage (httpOnly cookies for web, Keychain for native)
- JWT validation with RS256
- HTTPS only in production

## Current Setup

### Auth0 Applications

1. **foundry90-web** (Regular Web Application)
   - Client ID: `your-client-id-here` (get from Auth0 Dashboard)
   - Used for Next.js web app

2. **foundry90-native** (Native Application)
   - Client ID: `your-native-client-id-here` (get from Auth0 Dashboard)
   - Reserved for macOS/iOS apps

3. **foundry90 API** (Custom API)
   - Identifier: `https://api.foundry90.com`
   - Used for JWT validation in Rust API

## Environment Variables

### Web App (`apps/web/.env.local`)

```bash
# ⚠️ IMPORTANT: Replace these with your actual values from Auth0 Dashboard
# Never commit real secrets to git!

AUTH0_SECRET='generate-using-openssl-rand-hex-32'
AUTH0_BASE_URL='http://localhost:3001'
AUTH0_ISSUER_BASE_URL='https://your-tenant.auth0.com'
AUTH0_CLIENT_ID='your-client-id-from-auth0-dashboard'
AUTH0_CLIENT_SECRET='your-client-secret-from-auth0-dashboard'
AUTH0_AUDIENCE='https://api.foundry90.com'
AUTH0_DOMAIN='your-tenant.auth0.com'
APP_BASE_URL='http://localhost:3000'
```

### Rust API (`apps/rust-api/.env`)

```bash
# ⚠️ IMPORTANT: Replace with your actual values from Auth0 Dashboard
AUTH0_DOMAIN='your-tenant.auth0.com'
AUTH0_AUDIENCE='https://api.foundry90.com'
```

## Auth0 Dashboard Configuration

### foundry90-web Application Settings

**Allowed Callback URLs:**
```
http://localhost:3000/auth/callback
https://www.foundry90.com/auth/callback
```

**Allowed Logout URLs:**
```
http://localhost:3000
https://www.foundry90.com
```

**Allowed Web Origins:**
```
http://localhost:3000
https://www.foundry90.com
```

## Implementation Details

### Web Application

- **Middleware**: `apps/web/middleware.ts` - Handles all `/auth/*` routes
- **Auth Client**: `apps/web/lib/auth0.ts` - Auth0Client instance
- **Components**: 
  - `components/auth/AuthButton.tsx` - Login/logout button
  - `components/auth/UserProfile.tsx` - User profile display
  - `components/auth/ProtectedRoute.tsx` - Route protection wrapper

### Backend API

- **JWT Validation**: `apps/rust-api/src/auth.rs`
- **Middleware**: Optional authentication middleware available
- **Routes**: Currently public; add `.layer(middleware::from_fn(auth::validate_jwt))` to protect

## Usage

### Protecting Routes

```tsx
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';

export default function MyPage() {
  return (
    <ProtectedRoute>
      <div>Protected content</div>
    </ProtectedRoute>
  );
}
```

### Getting User Session (Server Component)

```tsx
import { auth0 } from '@/lib/auth0';

export default async function MyPage() {
  const session = await auth0.getSession();
  const user = session?.user;
  
  // Use user data
}
```

### Getting User Session (Client Component)

```tsx
'use client';
import { useUser } from '@auth0/nextjs-auth0/client';

export default function MyComponent() {
  const { user, isLoading } = useUser();
  
  if (isLoading) return <div>Loading...</div>;
  if (!user) return <div>Not logged in</div>;
  
  return <div>Hello {user.name}!</div>;
}
```

### Making Authenticated API Calls

```tsx
import { auth0 } from '@/lib/auth0';

export default async function MyPage() {
  const { token } = await auth0.getAccessToken();
  
  const response = await fetch('http://localhost:3000/api/endpoint', {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
}
```

## Development Keys Alert

**⚠️ About the "Development Keys" Alert:**

The alert you see in Auth0 about "development keys" refers to social connection keys (like Google OAuth). This is **normal for development** and **not a security concern** for local development.

**What it means:**
- Auth0 provides test/development keys for social logins
- These work fine for development and testing
- You'll need to replace them with production keys before going live

**When to fix:**
- Only when deploying to production
- You'll configure your own OAuth apps (Google, GitHub, etc.) and add those credentials

**For now:** You can safely ignore this alert during development.

## Production Checklist

Before deploying to production:

- [ ] Replace development social connection keys with production keys
- [ ] Update all callback URLs to production domains
- [ ] Use HTTPS everywhere
- [ ] Rotate `AUTH0_SECRET` (generate new one)
- [ ] Review and tighten CORS settings
- [ ] Enable MFA if needed
- [ ] Set up proper session timeouts
- [ ] Configure rate limiting
- [ ] Set up monitoring/alerts

## Troubleshooting

### "Callback URL mismatch"
- Verify callback URLs in Auth0 exactly match your app URLs
- Check for trailing slashes or typos

### "Invalid token" errors
- Verify `AUTH0_DOMAIN` and `AUTH0_AUDIENCE` match Auth0 settings
- Check that the API is enabled in Auth0 Dashboard

### Routes not working
- Ensure `middleware.ts` is in the root (or `src/` if using src directory)
- Verify middleware is calling `auth0.middleware(request)`

## Next Steps

- [ ] Implement native app authentication (SwiftUI)
- [ ] Add user profile sync to Postgres (if needed)
- [ ] Implement role-based access control (RBAC)
- [ ] Add refresh token handling
- [ ] Cache JWKS in Rust API (currently fetches on each request)

## Resources

- [Auth0 Next.js SDK Docs](https://auth0.com/docs/quickstart/webapp/nextjs)
- [Auth0 Swift SDK Docs](https://auth0.com/docs/quickstart/native/ios-swift)
- [JWT.io](https://jwt.io/) - Debug JWT tokens
- [Auth0 Dashboard](https://manage.auth0.com/)


