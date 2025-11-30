-- =====================================================================
-- HADRON REAL-TIME INTELLIGENCE SYSTEM TABLES
-- =====================================================================

-- Enum types for Hadron
CREATE TYPE tick_type_enum AS ENUM (
    'Trade',
    'Quote',
    'BookUpdate',
    'Other'
);

CREATE TYPE order_side_enum AS ENUM (
    'Buy',
    'Sell'
);

CREATE TYPE order_type_enum AS ENUM (
    'Market',
    'Limit',
    'Stop',
    'StopLimit'
);

CREATE TYPE execution_status_enum AS ENUM (
    'Filled',
    'PartiallyFilled',
    'Rejected',
    'Cancelled'
);

-- =====================================================================
-- TABLE: hadron_ticks
-- Real-time normalized tick data
-- =====================================================================

CREATE TABLE hadron_ticks (
    id                  BIGSERIAL PRIMARY KEY,
    instrument_id       BIGINT NOT NULL REFERENCES instruments(id) ON DELETE CASCADE,
    timestamp           TIMESTAMPTZ NOT NULL,
    price               NUMERIC(18, 6) NOT NULL,
    size                NUMERIC(20, 0),              -- nullable for quote-only ticks
    venue               TEXT NOT NULL,
    tick_type           tick_type_enum NOT NULL,
    source              TEXT NOT NULL,                -- e.g., 'polygon'

    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for time-series queries
CREATE INDEX hadron_ticks_instrument_timestamp_idx
    ON hadron_ticks (instrument_id, timestamp DESC);

-- Index for recent ticks
CREATE INDEX hadron_ticks_timestamp_idx
    ON hadron_ticks (timestamp DESC);

-- Index for venue/source queries
CREATE INDEX hadron_ticks_venue_idx
    ON hadron_ticks (venue);

-- =====================================================================
-- TABLE: hadron_order_intents
-- Order intents produced by strategy coordinator
-- =====================================================================

CREATE TABLE hadron_order_intents (
    id                  UUID PRIMARY KEY,
    instrument_id       BIGINT NOT NULL REFERENCES instruments(id) ON DELETE CASCADE,
    strategy_id         TEXT NOT NULL,
    side                order_side_enum NOT NULL,
    quantity            NUMERIC(20, 6) NOT NULL,
    order_type          order_type_enum NOT NULL,
    limit_price         NUMERIC(18, 6),              -- nullable for market orders
    timestamp           TIMESTAMPTZ NOT NULL,
    metadata            JSONB,

    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for strategy queries
CREATE INDEX hadron_order_intents_strategy_idx
    ON hadron_order_intents (strategy_id, timestamp DESC);

-- Index for instrument queries
CREATE INDEX hadron_order_intents_instrument_idx
    ON hadron_order_intents (instrument_id, timestamp DESC);

-- =====================================================================
-- TABLE: hadron_order_executions
-- Order execution confirmations
-- =====================================================================

CREATE TABLE hadron_order_executions (
    id                  BIGSERIAL PRIMARY KEY,
    order_intent_id     UUID NOT NULL REFERENCES hadron_order_intents(id) ON DELETE CASCADE,
    instrument_id       BIGINT NOT NULL REFERENCES instruments(id) ON DELETE CASCADE,
    venue               TEXT NOT NULL,
    executed_at         TIMESTAMPTZ NOT NULL,
    executed_price      NUMERIC(18, 6) NOT NULL,
    executed_quantity   NUMERIC(20, 6) NOT NULL,
    status              execution_status_enum NOT NULL,
    venue_order_id      TEXT,                        -- external venue's order ID

    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for order intent lookups
CREATE INDEX hadron_order_executions_intent_idx
    ON hadron_order_executions (order_intent_id);

-- Index for instrument queries
CREATE INDEX hadron_order_executions_instrument_idx
    ON hadron_order_executions (instrument_id, executed_at DESC);

-- Index for venue queries
CREATE INDEX hadron_order_executions_venue_idx
    ON hadron_order_executions (venue, executed_at DESC);

-- =====================================================================
-- TABLE: hadron_strategy_decisions
-- Strategy decisions (for audit/debugging)
-- =====================================================================

CREATE TABLE hadron_strategy_decisions (
    id                  BIGSERIAL PRIMARY KEY,
    strategy_id         TEXT NOT NULL,
    strategy_name       TEXT NOT NULL,
    instrument_id       BIGINT NOT NULL REFERENCES instruments(id) ON DELETE CASCADE,
    timestamp           TIMESTAMPTZ NOT NULL,
    decision_type       TEXT NOT NULL,                -- JSON representation of DecisionType
    confidence          NUMERIC(5, 2),               -- 0.00 to 1.00
    metadata            JSONB,

    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for strategy analysis
CREATE INDEX hadron_strategy_decisions_strategy_idx
    ON hadron_strategy_decisions (strategy_id, timestamp DESC);

-- Index for instrument analysis
CREATE INDEX hadron_strategy_decisions_instrument_idx
    ON hadron_strategy_decisions (instrument_id, timestamp DESC);

