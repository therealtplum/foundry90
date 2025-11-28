// apps/web/app/api/notify/route.ts
import { NextRequest, NextResponse } from "next/server";
import { query, queryOne } from "@/lib/db";

// Rate limiting: max 3 submissions per IP per hour
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour
const RATE_LIMIT_MAX_SUBMISSIONS = 3;

// Simple email validation regex
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Check if email is valid format
function isValidEmail(email: string): boolean {
  if (!email || email.length > 254) {
    return false;
  }
  return EMAIL_REGEX.test(email.trim());
}

// Check for suspicious patterns (basic spam detection)
function isSuspiciousEmail(email: string): boolean {
  const normalized = email.toLowerCase().trim();
  
  // Reject common spam patterns
  const suspiciousPatterns = [
    /^test\d*@/,           // test@, test1@, etc.
    /^admin@/,             // admin@
    /^noreply@/,           // noreply@
    /^no-reply@/,          // no-reply@
    /@test\./,             // @test.
    /@example\./,          // @example.
    /@localhost/,          // @localhost
    /\.\./,                // double dots
    /^\./,                 // starts with dot
    /@\./,                 // @ followed by dot
    /\s/,                  // contains whitespace
  ];

  return suspiciousPatterns.some(pattern => pattern.test(normalized));
}

// Get client IP address
function getClientIp(request: NextRequest): string | null {
  const forwarded = request.headers.get("x-forwarded-for");
  if (forwarded) {
    return forwarded.split(",")[0].trim();
  }
  const realIp = request.headers.get("x-real-ip");
  if (realIp) {
    return realIp;
  }
  return null;
}

// Check rate limit for IP address
async function checkRateLimit(ipAddress: string | null): Promise<{
  allowed: boolean;
  remaining: number;
}> {
  if (!ipAddress) {
    // If we can't get IP, be more restrictive
    return { allowed: false, remaining: 0 };
  }

  const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_MS);

  try {
    const recentCount = await queryOne<{ count: string }>(
      `
      SELECT COUNT(*)::int as count
      FROM email_notifications
      WHERE ip_address = $1::inet
        AND created_at >= $2
      `,
      [ipAddress, windowStart]
    );

    const count = recentCount ? parseInt(recentCount.count, 10) : 0;
    const remaining = Math.max(0, RATE_LIMIT_MAX_SUBMISSIONS - count);
    const allowed = count < RATE_LIMIT_MAX_SUBMISSIONS;

    return { allowed, remaining };
  } catch (error) {
    console.error("Rate limit check failed:", error);
    // On error, allow but log
    return { allowed: true, remaining: RATE_LIMIT_MAX_SUBMISSIONS };
  }
}

// Check if email already exists
async function emailExists(email: string): Promise<boolean> {
  try {
    const existing = await queryOne<{ id: number }>(
      `
      SELECT id
      FROM email_notifications
      WHERE LOWER(email) = LOWER($1)
      LIMIT 1
      `,
      [email.trim()]
    );
    return existing !== null;
  } catch (error) {
    console.error("Email existence check failed:", error);
    return false;
  }
}

// Insert email notification
async function insertEmail(
  email: string,
  ipAddress: string | null,
  userAgent: string | null
): Promise<{ id: number }> {
  const normalizedEmail = email.trim().toLowerCase();

  const result = await queryOne<{ id: number }>(
    `
    INSERT INTO email_notifications (email, ip_address, user_agent, status)
    VALUES ($1, $2::inet, $3, 'pending')
    ON CONFLICT (LOWER(email)) DO NOTHING
    RETURNING id
    `,
    [normalizedEmail, ipAddress, userAgent]
  );

  if (!result) {
    throw new Error("Failed to insert email (likely duplicate)");
  }

  return result;
}

export async function POST(request: NextRequest) {
  // Debug: Log environment info
  console.log("NODE_ENV:", process.env.NODE_ENV);
  console.log("DATABASE_URL exists:", !!process.env.DATABASE_URL);
  console.log("All DATABASE/POSTGRES env vars:", Object.keys(process.env).filter(k => 
    k.includes("DATABASE") || k.includes("POSTGRES") || k.includes("SUPABASE")
  ));

  // Check if DATABASE_URL is configured
  if (!process.env.DATABASE_URL) {
    console.error("DATABASE_URL is not configured");
    // In development, allow fallback; in production, fail
    if (process.env.NODE_ENV === "production") {
      return NextResponse.json(
        { 
          error: "Server configuration error. Please contact support.",
          details: "Database connection not configured. DATABASE_URL environment variable is missing."
        },
        { status: 500 }
      );
    }
  }

  // Log DATABASE_URL status (without exposing the full connection string)
  if (process.env.DATABASE_URL) {
    const dbUrl = process.env.DATABASE_URL;
    const maskedUrl = dbUrl.replace(/:[^:@]+@/, ":****@"); // Mask password
    console.log("DATABASE_URL is set:", maskedUrl.substring(0, 80) + "...");
  }

  try {
    const body = await request.json();
    const { email } = body;

    // Validate email is provided
    if (!email || typeof email !== "string") {
      return NextResponse.json(
        { error: "Email is required" },
        { status: 400 }
      );
    }

    const trimmedEmail = email.trim();

    // Validate email format
    if (!isValidEmail(trimmedEmail)) {
      return NextResponse.json(
        { error: "Invalid email format" },
        { status: 400 }
      );
    }

    // Check for suspicious patterns
    if (isSuspiciousEmail(trimmedEmail)) {
      return NextResponse.json(
        { error: "Invalid email address" },
        { status: 400 }
      );
    }

    // Get client info
    const ipAddress = getClientIp(request);
    const userAgent = request.headers.get("user-agent");

    // Check rate limit
    const rateLimit = await checkRateLimit(ipAddress);
    if (!rateLimit.allowed) {
      return NextResponse.json(
        {
          error: "Too many requests. Please try again later.",
          retryAfter: RATE_LIMIT_WINDOW_MS / 1000,
        },
        { status: 429 }
      );
    }

    // Check if email already exists
    if (await emailExists(trimmedEmail)) {
      // Return success even if duplicate to avoid email enumeration
      return NextResponse.json({
        success: true,
        message: "You're already on the list!",
      });
    }

    // Insert email
    try {
      await insertEmail(trimmedEmail, ipAddress, userAgent);
      return NextResponse.json({
        success: true,
        message: "Thanks! We'll notify you when the project launches.",
      });
    } catch (error: any) {
      // Check if it's a duplicate conflict
      if (error.message?.includes("duplicate") || error.message?.includes("Failed to insert")) {
        return NextResponse.json({
          success: true,
          message: "You're already on the list!",
        });
      }
      throw error;
    }
  } catch (error: any) {
    console.error("Email notification submission error:", error);
    console.error("Error stack:", error?.stack);
    console.error("Error message:", error?.message);
    return NextResponse.json(
      { 
        error: "An error occurred. Please try again later.",
        // Include error details in development
        ...(process.env.NODE_ENV === "development" && { 
          details: error?.message,
          stack: error?.stack 
        })
      },
      { status: 500 }
    );
  }
}
