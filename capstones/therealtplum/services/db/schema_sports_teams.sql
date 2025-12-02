-- =====================================================================
-- SPORTS TEAMS SCHEMA
-- =====================================================================
-- This file contains schema for sports teams normalization.
-- Run this after the main schema.sql

-- =====================================================================
-- TABLE: sports_teams
-- Comprehensive table of sports teams for joining to instruments
-- =====================================================================

CREATE TABLE sports_teams (
    id                  BIGSERIAL PRIMARY KEY,
    
    -- Identification
    team_code           TEXT NOT NULL,              -- e.g., 'KU', 'TOR', 'CHI', 'OSU'
    team_name           TEXT NOT NULL,              -- e.g., 'Kansas Jayhawks', 'Chicago Bulls'
    team_name_short     TEXT,                       -- e.g., 'Jayhawks', 'Bulls'
    
    -- Sport & League Classification
    sport_type          TEXT NOT NULL,              -- 'Basketball', 'Football', 'Baseball', 'Hockey', 'Soccer'
    league_code         TEXT NOT NULL,              -- 'NBA', 'NCAAB', 'NCAAF', 'MLB', 'NFL', 'NHL', 'MLS', 'EPL', etc.
    league_name         TEXT NOT NULL,              -- 'National Basketball Association', 'NCAA Men's Basketball', etc.
    
    -- Level & Demographics
    level               TEXT NOT NULL,              -- 'Professional', 'Collegiate', 'International', 'Minor League'
    gender              TEXT,                       -- 'Men's', 'Women's', 'Co-ed' (NULL for professional where gender is implied)
    division            TEXT,                       -- For pro leagues: 'Eastern', 'Western', 'American', 'National'
    conference          TEXT,                       -- For college: 'Big 12', 'Big Ten', 'SEC', 'ACC', etc.
                                                    -- For pro: Conference name if applicable
    
    -- Geographic Information
    city                TEXT,                       -- 'Lawrence', 'Chicago', 'Columbus'
    state_province      TEXT,                       -- 'KS', 'IL', 'OH' (US states or Canadian provinces)
    country             TEXT NOT NULL DEFAULT 'US', -- ISO country code: 'US', 'CA', 'GB', etc.
    region              TEXT,                       -- 'Midwest', 'Northeast', etc. (optional)
    
    -- Alternative Identifiers (for matching)
    alternate_codes     TEXT[],                     -- Array of alternate abbreviations: ['KAN', 'KANSAS'] for KU
    official_team_id    TEXT,                       -- Official league/NCAA team ID if available
    espn_id             TEXT,                       -- ESPN team ID (if we integrate with ESPN API)
    sports_reference_id TEXT,                       -- Sports Reference ID
    
    -- Metadata
    is_active           BOOLEAN NOT NULL DEFAULT true,
    founded_year        SMALLINT,                   -- Year team was founded/established
    colors              TEXT[],                      -- Primary team colors: ['Blue', 'Red']
    logo_url            TEXT,                       -- URL to team logo (if we host/store logos)
    
    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Unique constraint: team code + league (allows same code in different leagues)
    UNIQUE (team_code, league_code)
);

-- Partial index for active teams (for faster lookups)
CREATE UNIQUE INDEX sports_teams_code_league_active_idx 
    ON sports_teams (team_code, league_code) 
    WHERE is_active = true;

-- Search by name (requires pg_trgm extension for fuzzy matching)
CREATE INDEX sports_teams_name_idx 
    ON sports_teams (team_name);

-- Filter by sport/league
CREATE INDEX sports_teams_sport_league_idx 
    ON sports_teams (sport_type, league_code, is_active);

-- Filter by level/conference (for college teams)
CREATE INDEX sports_teams_level_conference_idx 
    ON sports_teams (level, conference) 
    WHERE level = 'Collegiate';

-- Geographic lookup
CREATE INDEX sports_teams_location_idx 
    ON sports_teams (country, state_province, city);

-- Alternate codes lookup (using GIN for array search)
CREATE INDEX sports_teams_alternate_codes_idx 
    ON sports_teams USING GIN (alternate_codes);

-- Trigger for updated_at
CREATE TRIGGER sports_teams_set_updated_at
BEFORE UPDATE ON sports_teams
FOR EACH ROW EXECUTE FUNCTION set_updated_at_timestamp();

-- =====================================================================
-- TABLE: instrument_teams
-- Junction table linking instruments to teams (many-to-many)
-- =====================================================================

CREATE TABLE instrument_teams (
    id                  BIGSERIAL PRIMARY KEY,
    instrument_id       BIGINT NOT NULL REFERENCES instruments(id) ON DELETE CASCADE,
    team_id             BIGINT NOT NULL REFERENCES sports_teams(id) ON DELETE CASCADE,
    
    -- Role in the market (for multi-team markets)
    team_role           TEXT,                       -- 'home', 'away', 'team1', 'team2', 'participant'
    
    -- How we matched this team (for audit/debugging)
    match_method        TEXT NOT NULL,              -- 'code_exact', 'code_alternate', 'name_fuzzy', 'manual'
    match_confidence    NUMERIC(3, 2),             -- 0.00-1.00 confidence score
    
    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE (instrument_id, team_id, team_role)
);

CREATE INDEX instrument_teams_instrument_idx 
    ON instrument_teams (instrument_id);
    
CREATE INDEX instrument_teams_team_idx 
    ON instrument_teams (team_id);

-- Trigger for updated_at
CREATE TRIGGER instrument_teams_set_updated_at
BEFORE UPDATE ON instrument_teams
FOR EACH ROW EXECUTE FUNCTION set_updated_at_timestamp();

-- =====================================================================
-- VIEW: sports_teams_with_instruments
-- View showing teams with their associated instruments count
-- =====================================================================

CREATE OR REPLACE VIEW sports_teams_with_instruments AS
SELECT 
    st.*,
    COUNT(DISTINCT it.instrument_id) as instrument_count
FROM sports_teams st
LEFT JOIN instrument_teams it ON st.id = it.team_id
WHERE st.is_active = true
GROUP BY st.id;

