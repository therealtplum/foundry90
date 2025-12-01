// apps/web/app/api/notify/route.ts
import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

// Rate limiting: max 3 submissions per IP per hour
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour
const RATE_LIMIT_MAX_SUBMISSIONS = 3;

// Simple email validation regex
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Get Supabase client
function getSupabaseClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;
  
  if (!supabaseUrl) {
    throw new Error("NEXT_PUBLIC_SUPABASE_URL environment variable is not set");
  }
  
  if (!supabaseKey) {
    throw new Error("Supabase key not configured. Set SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY");
  }

  return createClient(supabaseUrl, supabaseKey);
}

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

// Check rate limit for IP address using Supabase
async function checkRateLimit(ipAddress: string | null): Promise<{
  allowed: boolean;
  remaining: number;
}> {
  if (!ipAddress) {
    return { allowed: false, remaining: 0 };
  }

  const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_MS);

  try {
    const supabase = getSupabaseClient();
    const { count, error } = await supabase
      .from("email_notifications")
      .select("id", { count: "exact", head: true })
      .eq("ip_address", ipAddress)
      .gte("created_at", windowStart.toISOString());

    if (error) {
      console.error("Rate limit check failed:", error);
      return { allowed: true, remaining: RATE_LIMIT_MAX_SUBMISSIONS };
    }

    const countNum = count || 0;
    const remaining = Math.max(0, RATE_LIMIT_MAX_SUBMISSIONS - countNum);
    const allowed = countNum < RATE_LIMIT_MAX_SUBMISSIONS;
    return { allowed, remaining };
  } catch (error) {
    console.error("Rate limit check failed:", error);
    return { allowed: true, remaining: RATE_LIMIT_MAX_SUBMISSIONS };
  }
}

// Check if email already exists using Supabase
async function emailExists(email: string): Promise<boolean> {
  try {
    const supabase = getSupabaseClient();
    const normalizedEmail = email.trim().toLowerCase();
    
    const { data, error } = await supabase
      .from("email_notifications")
      .select("id")
      .ilike("email", normalizedEmail)
      .limit(1)
      .single();

    if (error && error.code !== "PGRST116") { // PGRST116 = no rows returned
      console.error("Email existence check failed:", error);
      return false;
    }

    return !!data;
  } catch (error) {
    console.error("Email existence check failed:", error);
    return false;
  }
}

// Insert email notification using Supabase
async function insertEmail(
  email: string,
  ipAddress: string | null,
  userAgent: string | null
): Promise<{ id: number }> {
  const normalizedEmail = email.trim().toLowerCase();
  const supabase = getSupabaseClient();

  const { data, error } = await supabase
    .from("email_notifications")
    .insert({
      email: normalizedEmail,
      ip_address: ipAddress,
      user_agent: userAgent,
      status: "pending",
    })
    .select("id")
    .single();

  if (error) {
    // Check if it's a duplicate (unique constraint violation)
    if (error.code === "23505" || error.message?.includes("duplicate")) {
      throw new Error("Failed to insert email (likely duplicate)");
    }
    throw error;
  }

  if (!data) {
    throw new Error("Failed to insert email");
  }

  return data;
}

export async function POST(request: NextRequest) {
  // Debug: Log environment info
  console.log("NODE_ENV:", process.env.NODE_ENV);
  console.log("NEXT_PUBLIC_SUPABASE_URL:", process.env.NEXT_PUBLIC_SUPABASE_URL ? "set" : "not set");
  console.log("SUPABASE_SERVICE_ROLE_KEY:", process.env.SUPABASE_SERVICE_ROLE_KEY ? "set" : "not set");
  console.log("SUPABASE_ANON_KEY:", process.env.SUPABASE_ANON_KEY ? "set" : "not set");

  // Check if Supabase is configured
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;
  
  if (!supabaseUrl) {
    return NextResponse.json(
      { error: "Supabase URL not configured. Set NEXT_PUBLIC_SUPABASE_URL environment variable." },
      { status: 500 }
    );
  }

  if (!supabaseKey && process.env.NODE_ENV === "production") {
    console.error("Supabase key not configured");
    return NextResponse.json(
      { 
        error: "Server configuration error. Please contact support.",
        details: "Supabase not configured. Set SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY"
      },
      { status: 500 }
    );
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
