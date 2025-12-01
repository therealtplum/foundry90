# Security Review - Sensitive Data Audit

**Date:** 2025-01-27  
**Branch:** main  
**Status:** ✅ Issues Fixed

## Summary

This document summarizes the security review of the codebase for sensitive data, hardcoded paths, and information that should be abstracted or added to `.gitignore`.

## Issues Found and Fixed

### 1. ✅ Hardcoded User Paths in Rust API

**File:** `apps/rust-api/src/kalshi.rs`

**Issue:** Hardcoded absolute paths to user's home directory:
- `/Users/thomasplummer/Documents/python/projects/foundry90/capstones/therealtplum/docker-compose.yml`
- `/Users/thomasplummer/Documents/python/projects/foundry90/capstones/therealtplum` (as working directory)

**Fix:** 
- Replaced with dynamic path detection using `PROJECT_ROOT` environment variable or automatic discovery by searching for `docker-compose.yml`
- Code now works on any system without hardcoded paths

**Impact:** Low - Only affects local development, but exposes user's directory structure

---

### 2. ✅ Hardcoded Supabase URL

**File:** `apps/web/app/api/notify/route.ts`

**Issue:** Hardcoded Supabase URL as fallback:
- `https://rbkfyiwxouzwxayxqirz.supabase.co`

**Fix:**
- Removed hardcoded fallback URL
- Now requires `NEXT_PUBLIC_SUPABASE_URL` environment variable to be set
- Added proper error handling when URL is not configured

**Impact:** Medium - Exposes Supabase project URL (though not necessarily sensitive, should be configurable)

---

### 3. ✅ Hardcoded User Path in Documentation

**File:** `docs/kalshi_integration_status.md`

**Issue:** Hardcoded reference to user's home directory:
- `/Users/thomasplummer/Documents/python/rust/pythia`

**Fix:**
- Removed specific path, replaced with generic reference
- Changed to: "External reference (path not included for security)"

**Impact:** Low - Documentation only, but exposes user's directory structure

---

### 4. ✅ Missing .env.kalshi_key in .gitignore

**File:** `.gitignore`

**Issue:** `.env.kalshi_key` file (used for Kalshi private key storage) was not explicitly listed in `.gitignore`

**Fix:**
- Added `.env.kalshi_key` to `.gitignore` under "Kalshi private keys" section

**Impact:** High - Could lead to accidental commit of private keys

---

## Items Reviewed (No Action Needed)

### Database Connection Strings

**Files:** Multiple (e.g., `apps/web/lib/db.ts`, `apps/rust-api/src/main.rs`, `apps/hadron/src/main.rs`)

**Status:** ✅ Acceptable

**Reason:** Default connection strings like `postgres://app:app@localhost:5433/fmhub` are:
- Only used for local development
- Overridden by `DATABASE_URL` environment variable in production
- Not sensitive (local dev credentials)
- Documented as development defaults

**Recommendation:** Keep as-is. These are standard local development defaults.

---

### Localhost URLs

**Files:** Multiple (e.g., `docker-compose.yml`, `apps/web/lib/api.ts`)

**Status:** ✅ Acceptable

**Reason:** Hardcoded `localhost` URLs are:
- Standard development defaults
- Overridden by environment variables in production
- Not sensitive information

**Recommendation:** Keep as-is. These are standard local development defaults.

---

### Sample Data Files

**Files:** 
- `apps/web/data/sample_tickers.json`
- `apps/python-etl/ncaa_ku_moneylines.json`

**Status:** ✅ Acceptable

**Reason:** 
- `sample_tickers.json` contains public market data (tickers, prices, insights) - not sensitive
- `ncaa_ku_moneylines.json` is empty and already in `.gitignore` (test output file)

**Recommendation:** Keep as-is. These files contain public data only.

---

## Current .gitignore Coverage

The `.gitignore` file properly covers:

✅ **Environment files:**
- `.env`, `.env.local`, `.env.*.local`
- `.env.kalshi_key` (now added)

✅ **Private keys:**
- `.kalshi_keys/` directory
- `*.pem` files (with exception for node_modules)

✅ **Generated/temporary files:**
- `ops/issues_analysis.json`
- `ops/pm_actions.json`
- `*.analysis.json`
- `ncaa_ku_moneylines.json`

✅ **Build artifacts:**
- `node_modules/`, `.next/`, `out/`
- `target/` (Rust)
- `__pycache__/`, `.venv/`, `venv/`

✅ **OS/Editor files:**
- `.DS_Store`, `.vscode/`, `.idea/`

---

## Recommendations

### 1. Environment Variables

All sensitive configuration should use environment variables:
- ✅ API keys (already using env vars)
- ✅ Database URLs (already using env vars)
- ✅ Supabase URLs (now required via env vars)
- ✅ Project paths (now using `PROJECT_ROOT` env var or auto-detection)

### 2. Documentation

- ✅ Removed hardcoded user paths from documentation
- Consider adding a `.env.example` file with placeholder values (without actual secrets)

### 3. Code Review Checklist

For future code reviews, check for:
- [ ] Hardcoded absolute paths (especially user-specific)
- [ ] Hardcoded API keys, tokens, or secrets
- [ ] Hardcoded service URLs (Supabase, databases, etc.)
- [ ] Email addresses or personal information
- [ ] IP addresses or internal network information

---

## Files Modified

1. `apps/rust-api/src/kalshi.rs` - Removed hardcoded user paths
2. `apps/web/app/api/notify/route.ts` - Removed hardcoded Supabase URL
3. `docs/kalshi_integration_status.md` - Removed hardcoded user path
4. `.gitignore` - Added `.env.kalshi_key`

---

## Testing Recommendations

After these changes:

1. **Test Rust API Kalshi refresh endpoint:**
   - Verify it works with `PROJECT_ROOT` environment variable set
   - Verify it works without `PROJECT_ROOT` (auto-detection)
   - Verify it works from different working directories

2. **Test Supabase integration:**
   - Verify `NEXT_PUBLIC_SUPABASE_URL` is required and properly validated
   - Test error handling when URL is missing

3. **Verify .gitignore:**
   - Ensure `.env.kalshi_key` files are not tracked by git

---

## Conclusion

All identified security issues have been addressed. The codebase now:
- ✅ Uses environment variables for all sensitive configuration
- ✅ Dynamically detects project paths instead of hardcoding
- ✅ Properly ignores sensitive files in `.gitignore`
- ✅ Removes hardcoded service URLs

No further action required at this time.

