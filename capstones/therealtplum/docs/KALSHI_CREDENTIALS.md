# Kalshi Credentials Structure

This document explains how Kalshi API credentials are organized in this project.

## Directory Structure

```
.kalshi_keys/
├── hadron_1.pem    # Fast-path key 1 (Hadron only)
├── hadron_2.pem    # Fast-path key 2 (Hadron only)
├── hadron_3.pem    # Fast-path key 3 (Hadron only)
├── hadron_4.pem    # Fast-path key 4 (Hadron only)
└── etl.pem         # Slow-path key (ETL/Rust API only)
```

## Fast-Path Credentials (Hadron)

**Purpose:** Real-time WebSocket connections for market data ingestion

**Location:** `.kalshi_keys/hadron_*.pem` files

**Configuration:**
- Environment variables in `.env`:
  - `KALSHI_API_KEY_1` through `KALSHI_API_KEY_4`
  - `KALSHI_PRIVATE_KEY_1_PATH=.kalshi_keys/hadron_1.pem`
  - `KALSHI_PRIVATE_KEY_2_PATH=.kalshi_keys/hadron_2.pem`
  - `KALSHI_PRIVATE_KEY_3_PATH=.kalshi_keys/hadron_3.pem`
  - `KALSHI_PRIVATE_KEY_4_PATH=.kalshi_keys/hadron_4.pem`

**Usage:** Only used by Hadron (`apps/hadron`) for fast-path WebSocket connections.

**Why separate?** Fast-path keys are used for high-frequency, real-time data streams. Keeping them separate ensures they're not accidentally used by slower, batch-oriented processes.

## Slow-Path Credentials (ETL / Rust API)

**Purpose:** REST API calls for account management, market queries, and batch operations

**Location:** `.kalshi_keys/etl.pem` file

**Configuration:**
- Environment variables in `.env`:
  - `KALSHI_API_KEY_ID=...` (the API key UUID)
  - `KALSHI_API_SECRET_FILE=.kalshi_keys/etl.pem` (path to private key file)
  - `KALSHI_USER_ID=default`

**Usage:** Used by:
- Python ETL scripts (`apps/python-etl/etl/kalshi_*.py`)
- Rust API Kalshi endpoints (`apps/rust-api/src/kalshi.rs`)

**Why separate?** Slow-path operations don't need the same level of performance isolation and can share a single credential set.

## Docker Volume Mounts

The `.kalshi_keys/` directory is mounted in Docker containers:

- **Hadron:** Mounts entire `.kalshi_keys/` directory to access `hadron_*.pem` files
- **ETL:** Mounts entire `.kalshi_keys/` directory to access `etl.pem` file
- **Rust API:** Can access keys via environment variables pointing to mounted paths

## Adding New Fast-Path Keys

When adding new fast-path keys (e.g., for additional Hadron shards):

1. Add the private key file: `.kalshi_keys/hadron_N.pem`
2. Add to `.env`:
   ```
   KALSHI_API_KEY_N=<api-key-uuid>
   KALSHI_PRIVATE_KEY_N_PATH=.kalshi_keys/hadron_N.pem
   ```
3. Hadron will automatically detect and use the new key

## Security Notes

- All `.kalshi_keys/*.pem` files should be in `.gitignore` (they contain private keys)
- Keys are mounted as read-only (`:ro`) in Docker containers
- Never commit private keys to version control

