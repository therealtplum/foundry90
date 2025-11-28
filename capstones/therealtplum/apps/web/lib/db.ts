// apps/web/lib/db.ts
import { Pool } from "pg";

let pool: Pool | null = null;

function getPool(): Pool {
  if (!pool) {
    // Default to local development connection (port 5433 for host)
    // In Docker, DATABASE_URL will be set to db:5432
    // In Vercel/production, DATABASE_URL must be set as an environment variable
    const databaseUrl =
      process.env.DATABASE_URL ||
      (process.env.NODE_ENV === "production" 
        ? null 
        : "postgres://app:app@localhost:5433/fmhub");

    if (!databaseUrl) {
      const error = new Error(
        "DATABASE_URL environment variable is not set. " +
        "Please configure it in your deployment environment (e.g., Vercel)."
      );
      console.error(error.message);
      throw error;
    }

    pool = new Pool({
      connectionString: databaseUrl,
      // Connection pool settings
      max: 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000, // Increased from 2000ms to 5000ms
    });

    // Handle pool errors
    pool.on("error", (err) => {
      console.error("Unexpected database pool error:", err);
    });
  }

  return pool;
}

export async function query<T = any>(
  text: string,
  params?: any[]
): Promise<T[]> {
  try {
    const client = getPool();
    const result = await client.query(text, params);
    return result.rows as T[];
  } catch (error: any) {
    console.error("Database query error:", error);
    console.error("Query:", text);
    console.error("Params:", params);
    throw error;
  }
}

export async function queryOne<T = any>(
  text: string,
  params?: any[]
): Promise<T | null> {
  try {
    const rows = await query<T>(text, params);
    return rows[0] || null;
  } catch (error: any) {
    console.error("Database queryOne error:", error);
    throw error;
  }
}

