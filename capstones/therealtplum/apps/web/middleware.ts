// apps/web/middleware.ts
// Next.js middleware for Auth0 authentication (v4)
// In v4, Auth0 routes are automatically mounted at /auth/* via middleware
import type { NextRequest } from "next/server";
import { auth0 } from "./lib/auth0";

export async function middleware(request: NextRequest) {
  // Auth0 v4 middleware handles all authentication routes automatically
  // Routes are mounted at:
  // - /auth/login
  // - /auth/logout
  // - /auth/callback
  // - /auth/profile
  // - /auth/access-token
  return await auth0.middleware(request);
}

export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico, sitemap.xml, robots.txt (metadata files)
     */
    "/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)",
  ],
};

