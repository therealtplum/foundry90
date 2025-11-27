// apps/web/app/api/version/route.ts
import { NextResponse } from "next/server";

export async function GET() {
  // In Vercel, these are populated automatically.
  // Locally, we fall back to "local-dev".
  const commit = process.env.VERCEL_GIT_COMMIT_SHA ?? "local-dev";
  const branch = process.env.VERCEL_GIT_COMMIT_REF ?? "local-dev";
  const deployedAt = process.env.VERCEL_GIT_COMMIT_TIMESTAMP ?? null;

  // Best-effort URL for where this app is being served.
  // In Docker on your machine, host is typically http://localhost:3001
  const url =
    process.env.NEXT_PUBLIC_SITE_URL ??
    (process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}`
      : "http://localhost:3001");

  return NextResponse.json({
    status: "ok",
    app: "fmhub",
    env: process.env.NODE_ENV,
    url,
    build: {
      commit,
      branch,
      deployed_at_utc: deployedAt,
    },
  });
}