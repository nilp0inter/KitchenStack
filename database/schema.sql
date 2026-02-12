-- FrostByte Database Schema
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable citext extension for case-insensitive text
CREATE EXTENSION IF NOT EXISTS citext;

-- Label preset table: named label configurations for printing
CREATE TABLE label_preset (
    name TEXT PRIMARY KEY,
    label_type TEXT NOT NULL DEFAULT '62',
    width INTEGER NOT NULL DEFAULT 696,
    height INTEGER NOT NULL DEFAULT 300,
    qr_size INTEGER NOT NULL DEFAULT 200,
    padding INTEGER NOT NULL DEFAULT 20,
    title_font_size INTEGER NOT NULL DEFAULT 48,
    date_font_size INTEGER NOT NULL DEFAULT 32,
    small_font_size INTEGER NOT NULL DEFAULT 18,
    font_family TEXT NOT NULL DEFAULT 'Atkinson Hyperlegible, sans-serif',
    -- Field visibility toggles
    show_title BOOLEAN NOT NULL DEFAULT TRUE,
    show_ingredients BOOLEAN NOT NULL DEFAULT FALSE,
    show_expiry_date BOOLEAN NOT NULL DEFAULT TRUE,
    show_best_before BOOLEAN NOT NULL DEFAULT FALSE,
    show_qr BOOLEAN NOT NULL DEFAULT TRUE,
    show_branding BOOLEAN NOT NULL DEFAULT TRUE,
    -- Layout settings
    vertical_spacing INTEGER NOT NULL DEFAULT 10,
    show_separator BOOLEAN NOT NULL DEFAULT TRUE,
    separator_thickness INTEGER NOT NULL DEFAULT 1,
    separator_color TEXT NOT NULL DEFAULT '#cccccc',
    corner_radius INTEGER NOT NULL DEFAULT 0,
    -- Text fitting settings
    title_min_font_size INTEGER NOT NULL DEFAULT 24,
    ingredients_max_chars INTEGER NOT NULL DEFAULT 45,
    -- Rotation flag: when TRUE, swap width/height in display and rotate PNG 90° CW for printing
    rotate BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ingredient table: defines ingredients with optional shelf life info
CREATE TABLE ingredient (
    name CITEXT PRIMARY KEY,
    expire_days INTEGER NULL,       -- days until unsafe
    best_before_days INTEGER NULL   -- days until quality degrades
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
    container_id TEXT NOT NULL REFERENCES container_type(name),
    best_before_date DATE NULL,
    label_preset TEXT NULL REFERENCES label_preset(name) ON UPDATE CASCADE ON DELETE SET NULL,
    details TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Junction table for batch-ingredient relationship
CREATE TABLE batch_ingredient (
    batch_id UUID NOT NULL REFERENCES batch(id) ON DELETE CASCADE,
    ingredient_name CITEXT NOT NULL REFERENCES ingredient(name) ON UPDATE CASCADE,
    PRIMARY KEY (batch_id, ingredient_name)
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
-- Client pre-computes expiry_date and best_before_date from ingredients
CREATE OR REPLACE FUNCTION create_batch(
    p_batch_id UUID,
    p_portion_ids UUID[],
    p_name TEXT,
    p_ingredient_names TEXT[],
    p_container_id TEXT,
    p_created_at DATE DEFAULT CURRENT_DATE,
    p_expiry_date DATE DEFAULT NULL,
    p_best_before_date DATE DEFAULT NULL,
    p_label_preset TEXT DEFAULT NULL,
    p_details TEXT DEFAULT NULL
)
RETURNS TABLE (
    batch_id UUID,
    portion_ids UUID[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_ingredient_name TEXT;
BEGIN
    -- Expiry date must be provided by client (computed from ingredients client-side)
    IF p_expiry_date IS NULL THEN
        RAISE EXCEPTION 'Expiry date must be provided by client';
    END IF;

    -- Auto-create unknown ingredients with NULL expire/best_before
    FOREACH v_ingredient_name IN ARRAY p_ingredient_names
    LOOP
        INSERT INTO ingredient (name)
        VALUES (LOWER(v_ingredient_name))
        ON CONFLICT (name) DO NOTHING;
    END LOOP;

    -- Create batch with client-provided UUID
    INSERT INTO batch (id, name, container_id, best_before_date, label_preset, details)
    VALUES (p_batch_id, p_name, p_container_id, p_best_before_date, p_label_preset, p_details);

    -- Link ingredients to batch
    INSERT INTO batch_ingredient (batch_id, ingredient_name)
    SELECT p_batch_id, LOWER(unnest(p_ingredient_names));

    -- Create portions with client-provided UUIDs
    INSERT INTO portion (id, batch_id, created_at, expiry_date)
    SELECT unnest(p_portion_ids), p_batch_id, p_created_at, p_expiry_date;

    RETURN QUERY SELECT p_batch_id, p_portion_ids;
END;
$$;

-- View for Dashboard: batches grouped with frozen/consumed counts
CREATE VIEW batch_summary AS
SELECT
    b.id AS batch_id,
    b.name,
    b.container_id,
    b.best_before_date,
    b.label_preset,
    b.created_at AS batch_created_at,
    MIN(p.expiry_date) AS expiry_date,
    COUNT(*) FILTER (WHERE p.status = 'FROZEN') AS frozen_count,
    COUNT(*) FILTER (WHERE p.status = 'CONSUMED') AS consumed_count,
    COUNT(*) AS total_count,
    COALESCE(
        (SELECT string_agg(bi.ingredient_name::TEXT, ', ' ORDER BY bi.ingredient_name)
         FROM batch_ingredient bi
         WHERE bi.batch_id = b.id),
        ''
    ) AS ingredients,
    b.details
FROM batch b
JOIN portion p ON p.batch_id = b.id
GROUP BY b.id, b.name, b.container_id, b.best_before_date, b.label_preset, b.created_at, b.details;

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
    b.container_id,
    b.best_before_date,
    COALESCE(
        (SELECT string_agg(bi.ingredient_name::TEXT, ', ' ORDER BY bi.ingredient_name)
         FROM batch_ingredient bi
         WHERE bi.batch_id = b.id),
        ''
    ) AS ingredients,
    b.details
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
),
date_range AS (
    SELECT generate_series(
        COALESCE((SELECT MIN(created_at) FROM portion), CURRENT_DATE),
        CURRENT_DATE,
        '1 day'::interval
    )::date AS date
)
SELECT
    d.date,
    COALESCE(a.added, 0) AS added,
    COALESCE(a.consumed, 0) AS consumed,
    SUM(COALESCE(a.added, 0) - COALESCE(a.consumed, 0)) OVER (ORDER BY d.date) AS frozen_total
FROM date_range d
LEFT JOIN aggregated a ON d.date = a.date
ORDER BY d.date;

-- Recipe table: reusable templates for batch creation
CREATE TABLE recipe (
    name CITEXT PRIMARY KEY,
    default_portions INTEGER NOT NULL DEFAULT 1,
    default_container_id TEXT NULL REFERENCES container_type(name),
    default_label_preset TEXT NULL REFERENCES label_preset(name) ON UPDATE CASCADE ON DELETE SET NULL,
    details TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Junction table for recipe-ingredient relationship
CREATE TABLE recipe_ingredient (
    recipe_name CITEXT NOT NULL REFERENCES recipe(name) ON DELETE CASCADE ON UPDATE CASCADE,
    ingredient_name CITEXT NOT NULL REFERENCES ingredient(name) ON UPDATE CASCADE,
    PRIMARY KEY (recipe_name, ingredient_name)
);

CREATE INDEX idx_recipe_ingredient_recipe ON recipe_ingredient(recipe_name);

-- Function to atomically save a recipe with ingredients
CREATE OR REPLACE FUNCTION save_recipe(
    p_name TEXT,
    p_ingredient_names TEXT[],
    p_default_portions INTEGER DEFAULT 1,
    p_default_container_id TEXT DEFAULT NULL,
    p_original_name TEXT DEFAULT NULL,
    p_default_label_preset TEXT DEFAULT NULL,
    p_details TEXT DEFAULT NULL
) RETURNS TABLE (recipe_name TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_ingredient_name TEXT;
BEGIN
    -- Auto-create unknown ingredients with NULL expire/best_before
    FOREACH v_ingredient_name IN ARRAY p_ingredient_names
    LOOP
        INSERT INTO ingredient (name)
        VALUES (LOWER(v_ingredient_name))
        ON CONFLICT (name) DO NOTHING;
    END LOOP;

    -- If editing (original name provided), delete old recipe first
    IF p_original_name IS NOT NULL THEN
        DELETE FROM recipe WHERE name = LOWER(p_original_name);
    END IF;

    -- Insert or update recipe
    INSERT INTO recipe (name, default_portions, default_container_id, default_label_preset, details)
    VALUES (LOWER(p_name), p_default_portions, p_default_container_id, p_default_label_preset, p_details)
    ON CONFLICT (name) DO UPDATE SET
        default_portions = EXCLUDED.default_portions,
        default_container_id = EXCLUDED.default_container_id,
        default_label_preset = EXCLUDED.default_label_preset,
        details = EXCLUDED.details;

    -- Clear old ingredients and insert new ones
    DELETE FROM recipe_ingredient WHERE recipe_ingredient.recipe_name = LOWER(p_name);
    INSERT INTO recipe_ingredient (recipe_name, ingredient_name)
    SELECT LOWER(p_name), LOWER(unnest(p_ingredient_names));

    RETURN QUERY SELECT LOWER(p_name)::TEXT AS recipe_name;
END;
$$;

-- View for recipe list with ingredients
CREATE VIEW recipe_summary AS
SELECT
    r.name,
    r.default_portions,
    r.default_container_id,
    r.default_label_preset,
    r.created_at,
    COALESCE(
        (SELECT string_agg(ri.ingredient_name::TEXT, ', ' ORDER BY ri.ingredient_name)
         FROM recipe_ingredient ri
         WHERE ri.recipe_name = r.name),
        ''
    ) AS ingredients,
    r.details
FROM recipe r;
