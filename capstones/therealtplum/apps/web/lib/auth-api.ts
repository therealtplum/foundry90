// apps/web/lib/auth-api.ts
// Authenticated API client that includes Auth0 access tokens

import { auth0 } from './auth0';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3000';

/**
 * Make an authenticated API request to the Rust backend
 * Automatically includes the Auth0 access token in the Authorization header
 */
export async function authenticatedFetch<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  // Get the access token from Auth0 session
  const { token: accessToken } = await auth0.getAccessToken() || {};

  const headers: HeadersInit = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    ...options.headers,
  };

  // Add Authorization header if we have an access token
  if (accessToken) {
    headers['Authorization'] = `Bearer ${accessToken}`;
  }

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers,
    cache: 'no-store',
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(
      `API request failed: ${response.status} ${response.statusText} - ${text}`
    );
  }

  return response.json() as Promise<T>;
}

/**
 * Client-side authenticated fetch (for use in client components)
 * Note: This requires the user to be authenticated
 */
export async function clientAuthenticatedFetch<T>(
  path: string,
  accessToken: string | null | undefined,
  options: RequestInit = {}
): Promise<T> {
  const headers: HeadersInit = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    ...options.headers,
  };

  if (accessToken) {
    headers['Authorization'] = `Bearer ${accessToken}`;
  }

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers,
    cache: 'no-store',
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(
      `API request failed: ${response.status} ${response.statusText} - ${text}`
    );
  }

  return response.json() as Promise<T>;
}

