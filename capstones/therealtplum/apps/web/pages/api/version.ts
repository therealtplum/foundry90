// apps/web/pages/api/version.ts
import type { NextApiRequest, NextApiResponse } from "next";

type VersionResponse = {
  status: string;
  app: string;
  env: string | undefined;
  url: string;
  build: {
    commit: string;
    branch: string;
    deployed_at_utc: string | null;
  };
};

export default function handler(
  _req: NextApiRequest,
  res: NextApiResponse<VersionResponse>
) {
  const commit = process.env.VERCEL_GIT_COMMIT_SHA ?? "local-dev";
  const branch = process.env.VERCEL_GIT_COMMIT_REF ?? "local-dev";
  const deployedAt = process.env.VERCEL_GIT_COMMIT_TIMESTAMP ?? null;

  const url =
    process.env.NEXT_PUBLIC_SITE_URL ??
    (process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}`
      : "http://localhost:3001"); // host → web container mapping

  res.status(200).json({
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