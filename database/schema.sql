-- FrostByte Database Schema
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Category table: defines food categories and their freezer shelf life
CREATE TABLE category (
    name TEXT PRIMARY KEY,
    safe_days INTEGER NOT NULL
);

-- Container type table: defines container types and their serving sizes
CREATE TABLE container_type (
    name TEXT PRIMARY KEY,
    servings_per_unit NUMERIC(5,2) NOT NULL
);

-- Batch table: groups portions created together
CREATE TABLE batch (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category_id TEXT NOT NULL REFERENCES category(name),
    container_id TEXT NOT NULL REFERENCES container_type(name),
    ingredients TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Portion table: individual frozen items (one per physical container/label)
CREATE TABLE portion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES batch(id),
    created_at DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'FROZEN' CHECK (status IN ('FROZEN', 'CONSUMED')),
    consumed_at TIMESTAMPTZ NULL
);

-- Index on status for filtering frozen/consumed portions
CREATE INDEX idx_portion_status ON portion(status);

-- Index on expiry_date for efficient sorting
CREATE INDEX idx_portion_expiry_date ON portion(expiry_date);

-- Index on batch_id for efficient joins
CREATE INDEX idx_portion_batch_id ON portion(batch_id);

-- Function to create a batch with N portions
-- Exposed via PostgREST as RPC endpoint: POST /rpc/create_batch
-- Client provides UUIDs for idempotency (duplicate requests will fail on PK constraint)
CREATE OR REPLACE FUNCTION create_batch(
    p_batch_id UUID,
    p_portion_ids UUID[],
    p_name TEXT,
    p_category_id TEXT,
    p_container_id TEXT,
    p_ingredients TEXT DEFAULT '',
    p_created_at DATE DEFAULT CURRENT_DATE,
    p_expiry_date DATE DEFAULT NULL
)
RETURNS TABLE (
    batch_id UUID,
    portion_ids UUID[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_expiry DATE;
BEGIN
    -- Calculate expiry if not provided
    IF p_expiry_date IS NULL THEN
        SELECT p_created_at + c.safe_days INTO v_expiry
        FROM category c WHERE c.name = p_category_id;
    ELSE
        v_expiry := p_expiry_date;
    END IF;

    -- Create batch with client-provided UUID
    INSERT INTO batch (id, name, category_id, container_id, ingredients)
    VALUES (p_batch_id, p_name, p_category_id, p_container_id, p_ingredients);

    -- Create portions with client-provided UUIDs
    INSERT INTO portion (id, batch_id, created_at, expiry_date)
    SELECT unnest(p_portion_ids), p_batch_id, p_created_at, v_expiry;

    RETURN QUERY SELECT p_batch_id, p_portion_ids;
END;
$$;

-- View for Dashboard: batches grouped with frozen/consumed counts
CREATE VIEW batch_summary AS
SELECT
    b.id AS batch_id,
    b.name,
    b.category_id,
    b.container_id,
    b.ingredients,
    b.created_at AS batch_created_at,
    MIN(p.expiry_date) AS expiry_date,
    COUNT(*) FILTER (WHERE p.status = 'FROZEN') AS frozen_count,
    COUNT(*) FILTER (WHERE p.status = 'CONSUMED') AS consumed_count,
    COUNT(*) AS total_count
FROM batch b
JOIN portion p ON p.batch_id = b.id
GROUP BY b.id, b.name, b.category_id, b.container_id, b.ingredients, b.created_at;

-- View for portion details including batch info (for QR scan page)
CREATE VIEW portion_detail AS
SELECT
    p.id AS portion_id,
    p.batch_id,
    p.created_at,
    p.expiry_date,
    p.status,
    p.consumed_at,
    b.name,
    b.category_id,
    b.container_id,
    b.ingredients
FROM portion p
JOIN batch b ON b.id = p.batch_id;

-- View for History Chart: daily count of frozen portions
-- This calculates the running total of frozen portions over time
CREATE VIEW freezer_history AS
WITH daily_changes AS (
    -- Portions added (frozen)
    SELECT created_at::DATE AS date, COUNT(*) AS added, 0 AS consumed
    FROM portion
    GROUP BY created_at::DATE
    UNION ALL
    -- Portions consumed
    SELECT consumed_at::DATE AS date, 0 AS added, COUNT(*) AS consumed
    FROM portion
    WHERE consumed_at IS NOT NULL
    GROUP BY consumed_at::DATE
),
aggregated AS (
    SELECT date, SUM(added) AS added, SUM(consumed) AS consumed
    FROM daily_changes
    WHERE date IS NOT NULL
    GROUP BY date
)
SELECT
    date,
    added,
    consumed,
    SUM(added - consumed) OVER (ORDER BY date) AS frozen_total
FROM aggregated
ORDER BY date;
