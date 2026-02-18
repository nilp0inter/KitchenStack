-- FrostByte API Layer
-- Read views and RPC write functions exposed via PostgREST
-- This file is idempotent: DROP + CREATE on each deploy

DROP SCHEMA IF EXISTS api CASCADE;
CREATE SCHEMA api;

-- =============================================================================
-- Read Views (same shape as original — client reads unchanged)
-- =============================================================================

CREATE VIEW api.ingredient AS
SELECT * FROM logic.ingredient;

CREATE VIEW api.container_type AS
SELECT * FROM logic.container_type;

CREATE VIEW api.label_preset AS
SELECT * FROM logic.label_preset;

CREATE VIEW api.portion AS
SELECT id, batch_id, created_at, expiry_date, status, consumed_at, discarded_at
FROM logic.portion;

CREATE VIEW api.event AS
SELECT * FROM data.event;

-- Batch ingredients: exposed for edit page pre-fill
CREATE VIEW api.batch_ingredient AS
SELECT batch_id, ingredient_name FROM logic.batch_ingredient;

-- Batch summary: batches grouped with frozen/consumed/discarded counts
CREATE VIEW api.batch_summary AS
SELECT
    b.id AS batch_id,
    b.name,
    b.container_id,
    b.best_before_date,
    b.label_preset,
    b.created_at AS batch_created_at,
    MIN(p.expiry_date) FILTER (WHERE p.status != 'DISCARDED') AS expiry_date,
    COUNT(*) FILTER (WHERE p.status = 'FROZEN') AS frozen_count,
    COUNT(*) FILTER (WHERE p.status = 'CONSUMED') AS consumed_count,
    COUNT(*) FILTER (WHERE p.status = 'DISCARDED') AS discarded_count,
    COUNT(*) AS total_count,
    COALESCE(
        (SELECT string_agg(bi.ingredient_name::TEXT, ', ' ORDER BY bi.ingredient_name)
         FROM logic.batch_ingredient bi
         WHERE bi.batch_id = b.id),
        ''
    ) AS ingredients,
    b.details,
    encode(i.image_data, 'base64') AS image
FROM logic.batch b
JOIN logic.portion p ON p.batch_id = b.id
LEFT JOIN logic.image i ON i.id = b.image_id
GROUP BY b.id, b.name, b.container_id, b.best_before_date, b.label_preset, b.created_at, b.details, i.image_data;

-- Portion detail: for QR scan page
CREATE VIEW api.portion_detail AS
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
         FROM logic.batch_ingredient bi
         WHERE bi.batch_id = b.id),
        ''
    ) AS ingredients,
    b.details,
    encode(i.image_data, 'base64') AS image
FROM logic.portion p
JOIN logic.batch b ON b.id = p.batch_id
LEFT JOIN logic.image i ON i.id = b.image_id;

-- Freezer history: daily running totals (DISCARDED portions excluded entirely)
CREATE VIEW api.freezer_history AS
WITH daily_changes AS (
    SELECT created_at::DATE AS date, COUNT(*) AS added, 0 AS consumed
    FROM logic.portion
    WHERE status != 'DISCARDED'
    GROUP BY created_at::DATE
    UNION ALL
    SELECT consumed_at::DATE AS date, 0 AS added, COUNT(*) AS consumed
    FROM logic.portion
    WHERE consumed_at IS NOT NULL AND status != 'DISCARDED'
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
        COALESCE((SELECT MIN(created_at) FROM logic.portion WHERE status != 'DISCARDED'), CURRENT_DATE),
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

-- Recipe summary: recipes with aggregated ingredient names
CREATE VIEW api.recipe_summary AS
SELECT
    r.name,
    r.default_portions,
    r.default_container_id,
    r.default_label_preset,
    r.created_at,
    COALESCE(
        (SELECT string_agg(ri.ingredient_name::TEXT, ', ' ORDER BY ri.ingredient_name)
         FROM logic.recipe_ingredient ri
         WHERE ri.recipe_name = r.name),
        ''
    ) AS ingredients,
    r.details,
    encode(i.image_data, 'base64') AS image
FROM logic.recipe r
LEFT JOIN logic.image i ON i.id = r.image_id;

-- =============================================================================
-- Write RPC Functions (all writes go through events)
-- =============================================================================

-- Ingredient CRUD
CREATE FUNCTION api.create_ingredient(
    p_name TEXT,
    p_expire_days INTEGER DEFAULT NULL,
    p_best_before_days INTEGER DEFAULT NULL
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('ingredient_created', jsonb_build_object(
        'name', LOWER(p_name),
        'expire_days', p_expire_days,
        'best_before_days', p_best_before_days
    ));
END;
$$;

CREATE FUNCTION api.update_ingredient(
    p_original_name TEXT,
    p_name TEXT,
    p_expire_days INTEGER DEFAULT NULL,
    p_best_before_days INTEGER DEFAULT NULL
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('ingredient_updated', jsonb_build_object(
        'original_name', LOWER(p_original_name),
        'new_name', LOWER(p_name),
        'expire_days', p_expire_days,
        'best_before_days', p_best_before_days
    ));
END;
$$;

CREATE FUNCTION api.delete_ingredient(
    p_name TEXT
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('ingredient_deleted', jsonb_build_object(
        'name', LOWER(p_name)
    ));
END;
$$;

-- Container Type CRUD
CREATE FUNCTION api.create_container_type(
    p_name TEXT,
    p_servings_per_unit NUMERIC DEFAULT 1.0
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('container_type_created', jsonb_build_object(
        'name', p_name,
        'servings_per_unit', p_servings_per_unit
    ));
END;
$$;

CREATE FUNCTION api.update_container_type(
    p_original_name TEXT,
    p_name TEXT,
    p_servings_per_unit NUMERIC DEFAULT 1.0
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('container_type_updated', jsonb_build_object(
        'original_name', p_original_name,
        'new_name', p_name,
        'servings_per_unit', p_servings_per_unit
    ));
END;
$$;

CREATE FUNCTION api.delete_container_type(
    p_name TEXT
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('container_type_deleted', jsonb_build_object(
        'name', p_name
    ));
END;
$$;

-- Label Preset CRUD
CREATE FUNCTION api.create_label_preset(
    p_name TEXT,
    p_label_type TEXT DEFAULT '62',
    p_width INTEGER DEFAULT 696,
    p_height INTEGER DEFAULT 300,
    p_qr_size INTEGER DEFAULT 200,
    p_padding INTEGER DEFAULT 20,
    p_title_font_size INTEGER DEFAULT 48,
    p_date_font_size INTEGER DEFAULT 32,
    p_small_font_size INTEGER DEFAULT 18,
    p_font_family TEXT DEFAULT 'Atkinson Hyperlegible, sans-serif',
    p_show_title BOOLEAN DEFAULT TRUE,
    p_show_ingredients BOOLEAN DEFAULT FALSE,
    p_show_expiry_date BOOLEAN DEFAULT TRUE,
    p_show_best_before BOOLEAN DEFAULT FALSE,
    p_show_qr BOOLEAN DEFAULT TRUE,
    p_show_branding BOOLEAN DEFAULT TRUE,
    p_vertical_spacing INTEGER DEFAULT 10,
    p_show_separator BOOLEAN DEFAULT TRUE,
    p_separator_thickness INTEGER DEFAULT 1,
    p_separator_color TEXT DEFAULT '#cccccc',
    p_corner_radius INTEGER DEFAULT 0,
    p_title_min_font_size INTEGER DEFAULT 24,
    p_ingredients_max_chars INTEGER DEFAULT 45,
    p_rotate BOOLEAN DEFAULT FALSE
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('label_preset_created', jsonb_build_object(
        'name', p_name,
        'label_type', p_label_type,
        'width', p_width,
        'height', p_height,
        'qr_size', p_qr_size,
        'padding', p_padding,
        'title_font_size', p_title_font_size,
        'date_font_size', p_date_font_size,
        'small_font_size', p_small_font_size,
        'font_family', p_font_family,
        'show_title', p_show_title,
        'show_ingredients', p_show_ingredients,
        'show_expiry_date', p_show_expiry_date,
        'show_best_before', p_show_best_before,
        'show_qr', p_show_qr,
        'show_branding', p_show_branding,
        'vertical_spacing', p_vertical_spacing,
        'show_separator', p_show_separator,
        'separator_thickness', p_separator_thickness,
        'separator_color', p_separator_color,
        'corner_radius', p_corner_radius,
        'title_min_font_size', p_title_min_font_size,
        'ingredients_max_chars', p_ingredients_max_chars,
        'rotate', p_rotate
    ));
END;
$$;

CREATE FUNCTION api.update_label_preset(
    p_original_name TEXT,
    p_name TEXT,
    p_label_type TEXT DEFAULT '62',
    p_width INTEGER DEFAULT 696,
    p_height INTEGER DEFAULT 300,
    p_qr_size INTEGER DEFAULT 200,
    p_padding INTEGER DEFAULT 20,
    p_title_font_size INTEGER DEFAULT 48,
    p_date_font_size INTEGER DEFAULT 32,
    p_small_font_size INTEGER DEFAULT 18,
    p_font_family TEXT DEFAULT 'Atkinson Hyperlegible, sans-serif',
    p_show_title BOOLEAN DEFAULT TRUE,
    p_show_ingredients BOOLEAN DEFAULT FALSE,
    p_show_expiry_date BOOLEAN DEFAULT TRUE,
    p_show_best_before BOOLEAN DEFAULT FALSE,
    p_show_qr BOOLEAN DEFAULT TRUE,
    p_show_branding BOOLEAN DEFAULT TRUE,
    p_vertical_spacing INTEGER DEFAULT 10,
    p_show_separator BOOLEAN DEFAULT TRUE,
    p_separator_thickness INTEGER DEFAULT 1,
    p_separator_color TEXT DEFAULT '#cccccc',
    p_corner_radius INTEGER DEFAULT 0,
    p_title_min_font_size INTEGER DEFAULT 24,
    p_ingredients_max_chars INTEGER DEFAULT 45,
    p_rotate BOOLEAN DEFAULT FALSE
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('label_preset_updated', jsonb_build_object(
        'original_name', p_original_name,
        'new_name', p_name,
        'label_type', p_label_type,
        'width', p_width,
        'height', p_height,
        'qr_size', p_qr_size,
        'padding', p_padding,
        'title_font_size', p_title_font_size,
        'date_font_size', p_date_font_size,
        'small_font_size', p_small_font_size,
        'font_family', p_font_family,
        'show_title', p_show_title,
        'show_ingredients', p_show_ingredients,
        'show_expiry_date', p_show_expiry_date,
        'show_best_before', p_show_best_before,
        'show_qr', p_show_qr,
        'show_branding', p_show_branding,
        'vertical_spacing', p_vertical_spacing,
        'show_separator', p_show_separator,
        'separator_thickness', p_separator_thickness,
        'separator_color', p_separator_color,
        'corner_radius', p_corner_radius,
        'title_min_font_size', p_title_min_font_size,
        'ingredients_max_chars', p_ingredients_max_chars,
        'rotate', p_rotate
    ));
END;
$$;

CREATE FUNCTION api.delete_label_preset(
    p_name TEXT
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('label_preset_deleted', jsonb_build_object(
        'name', p_name
    ));
END;
$$;

-- Batch creation (computes expiry server-side)
CREATE FUNCTION api.create_batch(
    p_batch_id UUID,
    p_portion_ids UUID[],
    p_name TEXT,
    p_ingredient_names TEXT[],
    p_container_id TEXT,
    p_created_at DATE DEFAULT CURRENT_DATE,
    p_expiry_date DATE DEFAULT NULL,
    p_best_before_date DATE DEFAULT NULL,
    p_label_preset TEXT DEFAULT NULL,
    p_details TEXT DEFAULT NULL,
    p_image_data TEXT DEFAULT NULL
) RETURNS TABLE (
    batch_id UUID,
    portion_ids UUID[],
    expiry_date DATE,
    best_before_date DATE
) LANGUAGE plpgsql AS $$
DECLARE
    v_expiry_date DATE;
    v_best_before_date DATE;
BEGIN
    -- Compute expiry date server-side
    v_expiry_date := logic.compute_expiry_date(p_created_at, p_expiry_date, p_ingredient_names);

    -- Compute best before date server-side
    v_best_before_date := logic.compute_best_before_date(p_created_at, p_ingredient_names);

    -- Override best_before_date if client passed one explicitly
    IF p_best_before_date IS NOT NULL THEN
        v_best_before_date := p_best_before_date;
    END IF;

    -- Insert event with computed values (self-contained for replay)
    INSERT INTO data.event (type, payload)
    VALUES ('batch_created', jsonb_build_object(
        'batch_id', p_batch_id,
        'portion_ids', to_jsonb(p_portion_ids),
        'name', p_name,
        'ingredient_names', to_jsonb(p_ingredient_names),
        'container_id', p_container_id,
        'created_at', p_created_at,
        'expiry_date', v_expiry_date,
        'best_before_date', v_best_before_date,
        'label_preset', p_label_preset,
        'details', p_details,
        'image_data', p_image_data
    ));

    RETURN QUERY SELECT p_batch_id, p_portion_ids, v_expiry_date, v_best_before_date;
END;
$$;

-- Batch update (single endpoint for edit form)
CREATE FUNCTION api.update_batch(
    p_batch_id UUID,
    p_name TEXT,
    p_container_id TEXT,
    p_ingredient_names TEXT[],
    p_label_preset TEXT DEFAULT NULL,
    p_details TEXT DEFAULT NULL,
    p_image_data TEXT DEFAULT NULL,
    p_remove_image BOOLEAN DEFAULT FALSE,
    p_best_before_date DATE DEFAULT NULL,
    p_new_portion_ids UUID[] DEFAULT ARRAY[]::UUID[],
    p_discard_portion_ids UUID[] DEFAULT ARRAY[]::UUID[],
    p_new_portions_created_at DATE DEFAULT CURRENT_DATE,
    p_new_portions_expiry_date DATE DEFAULT NULL
) RETURNS TABLE (
    new_portion_ids UUID[],
    new_expiry_date DATE,
    best_before_date DATE
) LANGUAGE plpgsql AS $$
DECLARE
    v_best_before_date DATE;
    v_new_expiry_date DATE;
    v_portion_id UUID;
BEGIN
    -- Compute best_before_date from ingredients (or use manual override)
    v_best_before_date := logic.compute_best_before_date(p_new_portions_created_at, p_ingredient_names);
    IF p_best_before_date IS NOT NULL THEN
        v_best_before_date := p_best_before_date;
    END IF;

    -- 1. Emit batch_updated event
    INSERT INTO data.event (type, payload)
    VALUES ('batch_updated', jsonb_build_object(
        'batch_id', p_batch_id,
        'name', p_name,
        'container_id', p_container_id,
        'ingredient_names', to_jsonb(p_ingredient_names),
        'best_before_date', v_best_before_date,
        'label_preset', p_label_preset,
        'details', p_details,
        'image_data', p_image_data,
        'remove_image', p_remove_image
    ));

    -- 2. Emit portion_discarded events
    IF p_discard_portion_ids IS NOT NULL AND array_length(p_discard_portion_ids, 1) > 0 THEN
        FOREACH v_portion_id IN ARRAY p_discard_portion_ids
        LOOP
            INSERT INTO data.event (type, payload)
            VALUES ('portion_discarded', jsonb_build_object(
                'portion_id', v_portion_id
            ));
        END LOOP;
    END IF;

    -- 3. Emit portions_added event if new portions requested
    IF p_new_portion_ids IS NOT NULL AND array_length(p_new_portion_ids, 1) > 0 THEN
        -- Compute expiry for new portions
        v_new_expiry_date := logic.compute_expiry_date(
            p_new_portions_created_at,
            p_new_portions_expiry_date,
            p_ingredient_names
        );

        INSERT INTO data.event (type, payload)
        VALUES ('portions_added', jsonb_build_object(
            'batch_id', p_batch_id,
            'portion_ids', to_jsonb(p_new_portion_ids),
            'created_at', p_new_portions_created_at,
            'expiry_date', v_new_expiry_date
        ));
    END IF;

    RETURN QUERY SELECT p_new_portion_ids, v_new_expiry_date, v_best_before_date;
END;
$$;

-- Portion state changes
CREATE FUNCTION api.consume_portion(
    p_portion_id UUID
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('portion_consumed', jsonb_build_object(
        'portion_id', p_portion_id
    ));
END;
$$;

CREATE FUNCTION api.return_portion(
    p_portion_id UUID
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('portion_returned', jsonb_build_object(
        'portion_id', p_portion_id
    ));
END;
$$;

CREATE FUNCTION api.discard_portion(
    p_portion_id UUID
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('portion_discarded', jsonb_build_object(
        'portion_id', p_portion_id
    ));
END;
$$;

-- Recipe CRUD
CREATE FUNCTION api.save_recipe(
    p_name TEXT,
    p_ingredient_names TEXT[],
    p_default_portions INTEGER DEFAULT 1,
    p_default_container_id TEXT DEFAULT NULL,
    p_original_name TEXT DEFAULT NULL,
    p_default_label_preset TEXT DEFAULT NULL,
    p_details TEXT DEFAULT NULL,
    p_image_data TEXT DEFAULT NULL
) RETURNS TABLE (recipe_name TEXT) LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('recipe_saved', jsonb_build_object(
        'name', p_name,
        'ingredient_names', to_jsonb(p_ingredient_names),
        'default_portions', p_default_portions,
        'default_container_id', p_default_container_id,
        'original_name', p_original_name,
        'default_label_preset', p_default_label_preset,
        'details', p_details,
        'image_data', p_image_data
    ));

    RETURN QUERY SELECT p_name::TEXT AS recipe_name;
END;
$$;

CREATE FUNCTION api.delete_recipe(
    p_name TEXT
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO data.event (type, payload)
    VALUES ('recipe_deleted', jsonb_build_object(
        'name', p_name
    ));
END;
$$;
