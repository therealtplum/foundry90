-- =====================================================================
-- REFERENCE DATA TABLES
-- Market holidays, condition codes, and market status
-- =====================================================================

-- =====================================================================
-- TABLE: market_holidays
-- Upcoming market holidays from Polygon API
-- =====================================================================

CREATE TABLE market_holidays (
    id                  BIGSERIAL PRIMARY KEY,
    date                DATE NOT NULL,
    exchange            TEXT NOT NULL,              -- 'NYSE', 'NASDAQ', 'OTC', etc.
    name                TEXT NOT NULL,              -- 'Thanksgiving', 'Christmas', etc.
    status              TEXT NOT NULL,             -- 'closed', 'early-close'
    open_time           TIMESTAMPTZ,               -- For early-close days
    close_time          TIMESTAMPTZ,               -- For early-close days

    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Unique constraint: one row per exchange per date
CREATE UNIQUE INDEX market_holidays_unique
    ON market_holidays (date, exchange);

-- Index for date lookups
CREATE INDEX market_holidays_date_idx
    ON market_holidays (date);

-- Index for exchange lookups
CREATE INDEX market_holidays_exchange_idx
    ON market_holidays (exchange);

-- =====================================================================
-- TABLE: condition_codes
-- Trade and quote condition codes from Polygon API
-- =====================================================================

CREATE TABLE condition_codes (
    id                  INTEGER PRIMARY KEY,        -- Polygon condition ID
    abbreviation        TEXT,                      -- Common abbreviation
    name                TEXT NOT NULL,
    asset_class         TEXT NOT NULL,             -- 'stocks', 'options', 'crypto', 'fx'
    data_types          TEXT[] NOT NULL,           -- Array of data types: ['trade', 'quote']
    description         TEXT,
    exchange            INTEGER,                   -- Exchange identifier if applicable
    legacy              BOOLEAN NOT NULL DEFAULT FALSE,
    type                TEXT NOT NULL,             -- 'sale_condition', 'quote_condition', etc.
    sip_mapping         JSONB,                    -- Mapping from SIP codes to unified code
    update_rules        JSONB,                    -- Aggregation rules

    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for asset class lookups
CREATE INDEX condition_codes_asset_class_idx
    ON condition_codes (asset_class);

-- Index for type lookups
CREATE INDEX condition_codes_type_idx
    ON condition_codes (type);

-- Index for data type lookups (using GIN for array searches)
CREATE INDEX condition_codes_data_types_idx
    ON condition_codes USING GIN (data_types);

-- =====================================================================
-- TABLE: market_status
-- Current market status from Polygon API (snapshot table)
-- =====================================================================

CREATE TABLE market_status (
    id                  BIGSERIAL PRIMARY KEY,
    server_time         TIMESTAMPTZ NOT NULL,
    market              TEXT NOT NULL,             -- Overall market status
    after_hours         BOOLEAN NOT NULL,
    early_hours         BOOLEAN NOT NULL,
    
    -- Exchange statuses
    exchange_nasdaq     TEXT,
    exchange_nyse       TEXT,
    exchange_otc        TEXT,
    
    -- Currency statuses
    currency_crypto     TEXT,
    currency_fx         TEXT,
    
    -- Index group statuses (stored as JSONB for flexibility)
    indices_groups      JSONB,
    
    -- Raw response for reference
    raw_response        JSONB,

    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for time-based queries
CREATE INDEX market_status_server_time_idx
    ON market_status (server_time DESC);

-- Index for market status lookups
CREATE INDEX market_status_market_idx
    ON market_status (market);

-- =====================================================================
-- TRIGGERS: updated_at maintenance
-- =====================================================================

CREATE TRIGGER market_holidays_set_updated_at
BEFORE UPDATE ON market_holidays
FOR EACH ROW EXECUTE FUNCTION set_updated_at_timestamp();

CREATE TRIGGER condition_codes_set_updated_at
BEFORE UPDATE ON condition_codes
FOR EACH ROW EXECUTE FUNCTION set_updated_at_timestamp();

-- =====================================================================
-- VIEWS: Convenience views
-- =====================================================================

-- View for upcoming market holidays (next 30 days)
CREATE OR REPLACE VIEW market_holidays_upcoming AS
SELECT *
FROM market_holidays
WHERE date >= CURRENT_DATE
  AND date <= CURRENT_DATE + INTERVAL '30 days'
ORDER BY date, exchange;

-- View for current market status (most recent)
CREATE OR REPLACE VIEW market_status_current AS
SELECT *
FROM market_status
ORDER BY server_time DESC
LIMIT 1;

