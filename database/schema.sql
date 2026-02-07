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
    font_family TEXT NOT NULL DEFAULT 'sans-serif',
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

-- Insert default presets for all brother_ql supported label sizes
-- Endless labels use silver ratio (1 + sqrt(2)) for height
-- Feature tiers: Minimal (<200px), Small (200-350px), Medium (350-600px), Large (≥600px)
-- rotate: TRUE if height > width (portrait stored, display landscape), FALSE otherwise
INSERT INTO label_preset (
    name, label_type, width, height, qr_size, padding, title_font_size, date_font_size, small_font_size,
    show_title, show_ingredients, show_expiry_date, show_best_before, show_qr, show_branding,
    vertical_spacing, show_separator, separator_thickness, separator_color, corner_radius,
    title_min_font_size, ingredients_max_chars, rotate
) VALUES
    -- ENDLESS LABELS (height = width × silver ratio) - all portrait, rotate=TRUE
    -- Minimal tier
    ('12mm endless', '12', 106, ROUND(106 * (1 + SQRT(2)))::INTEGER, 64, 5, 12, 10, 8,
     TRUE, FALSE, FALSE, FALSE, TRUE, FALSE,
     3, FALSE, 1, '#cccccc', 0,
     8, 20, TRUE),
    -- Small tier
    ('29mm endless', '29', 306, ROUND(306 * (1 + SQRT(2)))::INTEGER, 180, 10, 24, 16, 12,
     TRUE, FALSE, TRUE, FALSE, TRUE, FALSE,
     6, TRUE, 1, '#cccccc', 0,
     16, 30, TRUE),
    -- Medium tier
    ('38mm endless', '38', 413, ROUND(413 * (1 + SQRT(2)))::INTEGER, 200, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, FALSE,
     8, TRUE, 1, '#cccccc', 0,
     20, 50, TRUE),
    ('50mm endless', '50', 554, ROUND(554 * (1 + SQRT(2)))::INTEGER, 200, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, FALSE,
     8, TRUE, 1, '#cccccc', 0,
     20, 50, TRUE),
    ('54mm endless', '54', 590, ROUND(590 * (1 + SQRT(2)))::INTEGER, 200, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, FALSE,
     8, TRUE, 1, '#cccccc', 0,
     20, 50, TRUE),
    -- Large tier
    ('62mm endless', '62', 696, ROUND(696 * (1 + SQRT(2)))::INTEGER, 200, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', 0,
     24, 60, TRUE),
    ('62mm endless (black/red/white)', '62red', 696, ROUND(696 * (1 + SQRT(2)))::INTEGER, 200, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', 0,
     24, 60, TRUE),
    ('102mm endless', '102', 1164, ROUND(1164 * (1 + SQRT(2)))::INTEGER, 280, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', 0,
     24, 80, TRUE),

    -- DIE-CUT RECTANGULAR LABELS (fixed dimensions)
    -- corner_radius = 5% of min(width, height) for rounded corners
    -- Minimal tier - portrait, rotate=TRUE
    ('17mm x 54mm die-cut', '17x54', 165, 566, 100, 5, 12, 10, 8,
     TRUE, FALSE, FALSE, FALSE, TRUE, FALSE,
     3, FALSE, 1, '#cccccc', ROUND(LEAST(165, 566) * 0.05)::INTEGER,
     8, 20, TRUE),
    ('17mm x 87mm die-cut', '17x87', 165, 956, 100, 5, 12, 10, 8,
     TRUE, FALSE, FALSE, FALSE, TRUE, FALSE,
     3, FALSE, 1, '#cccccc', ROUND(LEAST(165, 956) * 0.05)::INTEGER,
     8, 20, TRUE),
    -- Small tier
    ('23mm x 23mm die-cut', '23x23', 202, 202, 120, 10, 24, 16, 12,
     TRUE, FALSE, TRUE, FALSE, TRUE, FALSE,
     6, TRUE, 1, '#cccccc', ROUND(LEAST(202, 202) * 0.05)::INTEGER,
     16, 30, FALSE),  -- square, no rotation needed
    ('29mm x 42mm die-cut', '29x42', 306, 425, 180, 10, 24, 16, 12,
     TRUE, FALSE, TRUE, FALSE, TRUE, FALSE,
     6, TRUE, 1, '#cccccc', ROUND(LEAST(306, 425) * 0.05)::INTEGER,
     16, 30, TRUE),
    ('29mm x 90mm die-cut', '29x90', 306, 991, 180, 10, 24, 16, 12,
     TRUE, FALSE, TRUE, FALSE, TRUE, FALSE,
     6, TRUE, 1, '#cccccc', ROUND(LEAST(306, 991) * 0.05)::INTEGER,
     16, 30, TRUE),
    -- Medium tier
    ('39mm x 48mm die-cut', '39x48', 425, 495, 200, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, FALSE,
     8, TRUE, 1, '#cccccc', ROUND(LEAST(425, 495) * 0.05)::INTEGER,
     20, 50, TRUE),
    ('38mm x 90mm die-cut', '39x90', 413, 991, 200, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, FALSE,
     8, TRUE, 1, '#cccccc', ROUND(LEAST(413, 991) * 0.05)::INTEGER,
     20, 50, TRUE),
    ('52mm x 29mm die-cut', '52x29', 578, 271, 180, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, FALSE,
     8, TRUE, 1, '#cccccc', ROUND(LEAST(578, 271) * 0.05)::INTEGER,
     20, 50, FALSE),  -- landscape, no rotation needed
    -- Large tier
    ('62mm x 29mm die-cut', '62x29', 696, 271, 180, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', ROUND(LEAST(696, 271) * 0.05)::INTEGER,
     24, 60, FALSE),  -- landscape, no rotation needed
    ('62mm x 100mm die-cut', '62x100', 696, 1109, 200, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', ROUND(LEAST(696, 1109) * 0.05)::INTEGER,
     24, 60, TRUE),
    ('102mm x 51mm die-cut', '102x51', 1164, 526, 250, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', ROUND(LEAST(1164, 526) * 0.05)::INTEGER,
     24, 80, FALSE),  -- landscape, no rotation needed
    ('102mm x 153mm die-cut', '102x152', 1164, 1660, 280, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', ROUND(LEAST(1164, 1660) * 0.05)::INTEGER,
     24, 80, TRUE),

    -- ROUND DIE-CUT LABELS (square dimensions, no rotation needed)
    -- Minimal tier
    ('12mm round die-cut', 'd12', 94, 94, 60, 5, 10, 8, 6,
     TRUE, FALSE, FALSE, FALSE, TRUE, FALSE,
     2, FALSE, 1, '#cccccc', 47,
     6, 15, FALSE),
    -- Small tier
    ('24mm round die-cut', 'd24', 236, 236, 140, 10, 24, 16, 12,
     TRUE, FALSE, TRUE, FALSE, TRUE, FALSE,
     6, TRUE, 1, '#cccccc', 118,
     16, 30, FALSE),
    -- Large tier
    ('58mm round die-cut', 'd58', 618, 618, 200, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     8, TRUE, 1, '#cccccc', 309,
     20, 50, FALSE);

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
    v_expiry DATE;
    v_best_before DATE;
    v_ingredient_name TEXT;
    v_min_expire_days INTEGER;
    v_min_best_before_days INTEGER;
BEGIN
    -- Auto-create unknown ingredients with NULL expire/best_before
    FOREACH v_ingredient_name IN ARRAY p_ingredient_names
    LOOP
        INSERT INTO ingredient (name)
        VALUES (LOWER(v_ingredient_name))
        ON CONFLICT (name) DO NOTHING;
    END LOOP;

    -- Get minimum expire_days from ingredients
    SELECT MIN(expire_days) INTO v_min_expire_days
    FROM ingredient
    WHERE name = ANY(SELECT LOWER(unnest(p_ingredient_names)));

    -- Get minimum best_before_days from ingredients
    SELECT MIN(best_before_days) INTO v_min_best_before_days
    FROM ingredient
    WHERE name = ANY(SELECT LOWER(unnest(p_ingredient_names)));

    -- Calculate expiry if not provided
    IF p_expiry_date IS NOT NULL THEN
        v_expiry := p_expiry_date;
    ELSIF v_min_expire_days IS NOT NULL THEN
        v_expiry := p_created_at + v_min_expire_days;
    ELSE
        -- No ingredient has expire_days and no manual expiry provided - error
        RAISE EXCEPTION 'Expiry date required: no ingredient has expire_days defined';
    END IF;

    -- Calculate best_before if not provided
    IF p_best_before_date IS NOT NULL THEN
        v_best_before := p_best_before_date;
    ELSIF v_min_best_before_days IS NOT NULL THEN
        v_best_before := p_created_at + v_min_best_before_days;
    ELSE
        v_best_before := NULL;
    END IF;

    -- Create batch with client-provided UUID
    INSERT INTO batch (id, name, container_id, best_before_date, label_preset, details)
    VALUES (p_batch_id, p_name, p_container_id, v_best_before, p_label_preset, p_details);

    -- Link ingredients to batch
    INSERT INTO batch_ingredient (batch_id, ingredient_name)
    SELECT p_batch_id, LOWER(unnest(p_ingredient_names));

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
)
SELECT
    date,
    added,
    consumed,
    SUM(added - consumed) OVER (ORDER BY date) AS frozen_total
FROM aggregated
ORDER BY date;

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

-- Seed data: common ingredients with expiry info (migrated from old categories)
INSERT INTO ingredient (name, expire_days, best_before_days) VALUES
    ('arroz', 120, 90),
    ('pollo', 365, 270),
    ('verduras', 240, 180),
    ('carne', 365, 270),
    ('pescado', 180, 120),
    ('legumbres', 365, 300),
    ('pasta', 180, 120),
    ('pan', 90, 60),
    ('caldo', 120, 90);

-- Seed data: container types
INSERT INTO container_type (name, servings_per_unit) VALUES
    ('Bolsa 1L', 2),
    ('Tupper pequeño', 1),
    ('Tupper mediano', 2),
    ('Tupper grande', 4);
