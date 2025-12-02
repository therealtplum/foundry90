-- =====================================================================
-- SPORTS TEAMS VENUE CODES SCHEMA
-- =====================================================================
-- Junction table for mapping sports teams to venue-specific codes
-- Supports multiple prediction market venues (Kalshi, CME, Polymarket, etc.)
-- Run this after schema_sports_teams.sql

-- =====================================================================
-- TABLE: venues
-- Master list of prediction market venues/exchanges
-- =====================================================================

CREATE TABLE venues (
    id                  BIGSERIAL PRIMARY KEY,
    venue_code          TEXT NOT NULL UNIQUE,        -- 'KALSHI', 'CME', 'POLYMARKET', 'PREDICTOIT', etc.
    venue_name          TEXT NOT NULL,                -- 'Kalshi', 'CME Group', 'Polymarket', etc.
    venue_type          TEXT NOT NULL,                -- 'exchange', 'platform', 'derivatives_exchange'
    
    -- Regulatory & Geographic Information
    country             TEXT NOT NULL DEFAULT 'US',   -- ISO country code: 'US', 'GB', 'IE', etc.
    regulator           TEXT,                         -- Regulatory body: 'CFTC', 'SEC', 'FCA', 'CBI', etc.
    mic_code            TEXT,                         -- Market Identifier Code (ISO 10383): 'XCME', 'XKAL', etc.
    
    -- URLs
    website_url         TEXT,
    api_documentation_url TEXT,
    
    -- Metadata
    is_active           BOOLEAN NOT NULL DEFAULT true,
    notes               TEXT,                         -- Any notes about the venue
    
    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX venues_code_idx ON venues (venue_code) WHERE is_active = true;
CREATE INDEX venues_type_idx ON venues (venue_type, is_active);
CREATE INDEX venues_country_idx ON venues (country, is_active);
CREATE INDEX venues_mic_code_idx ON venues (mic_code) WHERE mic_code IS NOT NULL;

-- Trigger for updated_at
CREATE TRIGGER venues_set_updated_at
BEFORE UPDATE ON venues
FOR EACH ROW EXECUTE FUNCTION set_updated_at_timestamp();

-- =====================================================================
-- TABLE: sports_teams_venue_codes
-- Maps teams to venue-specific codes
-- =====================================================================

CREATE TABLE sports_teams_venue_codes (
    id                  BIGSERIAL PRIMARY KEY,
    team_id             BIGINT NOT NULL REFERENCES sports_teams(id) ON DELETE CASCADE,
    venue_id            BIGINT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
    
    -- Venue-specific code for this team
    venue_code          TEXT NOT NULL,                -- e.g., 'KU' for Kalshi, 'BGKUX' for CME, etc.
    
    -- Optional: venue-specific team name if different
    venue_team_name     TEXT,                         -- e.g., 'Kansas Jayhawks' (may differ from our canonical name)
    
    -- Metadata
    is_active           BOOLEAN NOT NULL DEFAULT true,
    is_primary          BOOLEAN NOT NULL DEFAULT true, -- If team has multiple codes on same venue
    confidence          NUMERIC(3, 2),                -- 0.00-1.00 confidence in this mapping
    
    -- How we matched this code (for audit/debugging)
    match_method        TEXT,                         -- 'manual', 'api_lookup', 'fuzzy_match', 'exact_match'
    match_source        TEXT,                         -- Where the mapping came from (API, documentation, etc.)
    
    -- Notes
    notes               TEXT,                         -- Any notes about this specific mapping
    
    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Unique constraint: one active code per team per venue (unless is_primary=false)
    UNIQUE (team_id, venue_id, venue_code)
);

-- Index for fast lookups: team -> venue codes
CREATE INDEX sports_teams_venue_codes_team_idx 
    ON sports_teams_venue_codes (team_id, is_active);

-- Index for fast lookups: venue -> teams
CREATE INDEX sports_teams_venue_codes_venue_idx 
    ON sports_teams_venue_codes (venue_id, is_active);

-- Index for reverse lookup: venue_code -> team
CREATE INDEX sports_teams_venue_codes_code_idx 
    ON sports_teams_venue_codes (venue_id, venue_code, is_active);

-- Composite index for common query pattern: "get all active codes for team on venue"
CREATE INDEX sports_teams_venue_codes_team_venue_active_idx 
    ON sports_teams_venue_codes (team_id, venue_id) 
    WHERE is_active = true;

-- Trigger for updated_at
CREATE TRIGGER sports_teams_venue_codes_set_updated_at
BEFORE UPDATE ON sports_teams_venue_codes
FOR EACH ROW EXECUTE FUNCTION set_updated_at_timestamp();

-- =====================================================================
-- VIEW: sports_teams_with_venue_codes
-- Convenience view showing teams with their venue codes
-- =====================================================================

CREATE OR REPLACE VIEW sports_teams_with_venue_codes AS
SELECT 
    st.id as team_id,
    st.team_code,
    st.team_name,
    st.league_code,
    st.sport_type,
    v.venue_code as venue_code,
    v.venue_name,
    stvc.venue_code as team_venue_code,
    stvc.venue_team_name,
    stvc.is_active as code_is_active,
    stvc.is_primary,
    stvc.confidence,
    stvc.match_method
FROM sports_teams st
INNER JOIN sports_teams_venue_codes stvc ON st.id = stvc.team_id
INNER JOIN venues v ON stvc.venue_id = v.id
WHERE st.is_active = true 
  AND stvc.is_active = true
  AND v.is_active = true;

-- =====================================================================
-- VIEW: venue_codes_by_team
-- Pivoted view showing all venue codes for a team (one row per team)
-- =====================================================================

CREATE OR REPLACE VIEW venue_codes_by_team AS
SELECT 
    st.id as team_id,
    st.team_code,
    st.team_name,
    st.league_code,
    st.sport_type,
    jsonb_object_agg(
        v.venue_code, 
        jsonb_build_object(
            'code', stvc.venue_code,
            'name', stvc.venue_team_name,
            'is_primary', stvc.is_primary,
            'confidence', stvc.confidence
        )
    ) FILTER (WHERE stvc.is_active = true AND v.is_active = true) as venue_codes
FROM sports_teams st
LEFT JOIN sports_teams_venue_codes stvc ON st.id = stvc.team_id
LEFT JOIN venues v ON stvc.venue_id = v.id
WHERE st.is_active = true
GROUP BY st.id, st.team_code, st.team_name, st.league_code, st.sport_type;

-- =====================================================================
-- INITIAL VENUE DATA
-- =====================================================================

INSERT INTO venues (
    venue_code, venue_name, venue_type, 
    country, regulator, mic_code,
    website_url, is_active, notes
) VALUES
    ('KALSHI', 'Kalshi', 'exchange', 
     'US', 'CFTC', NULL,
     'https://kalshi.com', true, NULL),
    ('CME', 'CME Group', 'derivatives_exchange', 
     'US', 'CFTC', 'XCME',
     'https://www.cmegroup.com', true, NULL),
    ('POLYMARKET', 'Polymarket', 'platform', 
     'IE', 'CBI', NULL,
     'https://polymarket.com', true, 'Polymarket Ireland (CBI regulated)'),
    ('POLYMARKET_US', 'Polymarket US', 'exchange', 
     'US', 'CFTC', NULL,
     'https://polymarket.com', true, 'Polymarket US entity (CFTC regulated)'),
    ('CRYPTOCOM', 'Crypto.com', 'derivatives_exchange', 
     'US', 'CFTC', NULL,
     'https://crypto.com', true, NULL),
    ('NADEX', 'NADex', 'derivatives_exchange', 
     'US', 'CFTC', NULL,
     'https://www.nadex.com', true, 'North American Derivatives Exchange (owned by Crypto.com)'),
    ('FORECASTEX', 'ForecastEx', 'exchange', 
     'US', 'CFTC', NULL,
     'https://forecastex.com', true, NULL),
    ('MIAXDX', 'MIAXdx', 'derivatives_exchange', 
     'US', 'CFTC', NULL,
     'https://www.miaxoptions.com', true, 'Formerly LedgerX, purchased by Robinhood (likely to rename in 2026)'),
    ('RAILBIRD', 'Railbird', 'derivatives_exchange', 
     'US', 'CFTC', NULL,
     NULL, true, 'CFTC regulated, purchased by DraftKings (likely to rename in 2026)'),
    ('SMALL_EXCHANGE', 'Small Exchange', 'derivatives_exchange', 
     'US', 'CFTC', NULL,
     'https://smallexchange.com', true, 'CFTC regulated, purchased by Kraken (likely to rename in 2026)'),
    ('COINBASE_DX', 'Coinbase Derivatives Exchange', 'derivatives_exchange', 
     'US', 'CFTC', NULL,
     'https://www.coinbase.com', true, NULL),
    ('METACULUS', 'Metaculus', 'platform', 
     'US', NULL, NULL,
     'https://www.metaculus.com', true, NULL)
ON CONFLICT (venue_code) DO UPDATE SET
    venue_name = EXCLUDED.venue_name,
    country = EXCLUDED.country,
    regulator = EXCLUDED.regulator,
    mic_code = EXCLUDED.mic_code,
    website_url = EXCLUDED.website_url,
    notes = EXCLUDED.notes,
    updated_at = NOW();

