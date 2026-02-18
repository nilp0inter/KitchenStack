-- FrostByte Logic Layer
-- Projection tables, event handlers, business logic, and replay functions
-- This file is idempotent: DROP + CREATE on each deploy

DROP SCHEMA IF EXISTS logic CASCADE;
CREATE SCHEMA logic;

-- =============================================================================
-- Projection Tables (rebuilt from events on replay)
-- =============================================================================

CREATE TABLE logic.image (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    image_data BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE logic.ingredient (
    name CITEXT PRIMARY KEY,
    expire_days INTEGER NULL,
    best_before_days INTEGER NULL
);

CREATE TABLE logic.container_type (
    name TEXT PRIMARY KEY,
    servings_per_unit NUMERIC(5,2) NOT NULL
);

CREATE TABLE logic.label_preset (
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
    show_title BOOLEAN NOT NULL DEFAULT TRUE,
    show_ingredients BOOLEAN NOT NULL DEFAULT FALSE,
    show_expiry_date BOOLEAN NOT NULL DEFAULT TRUE,
    show_best_before BOOLEAN NOT NULL DEFAULT FALSE,
    show_qr BOOLEAN NOT NULL DEFAULT TRUE,
    show_branding BOOLEAN NOT NULL DEFAULT TRUE,
    vertical_spacing INTEGER NOT NULL DEFAULT 10,
    show_separator BOOLEAN NOT NULL DEFAULT TRUE,
    separator_thickness INTEGER NOT NULL DEFAULT 1,
    separator_color TEXT NOT NULL DEFAULT '#cccccc',
    corner_radius INTEGER NOT NULL DEFAULT 0,
    title_min_font_size INTEGER NOT NULL DEFAULT 24,
    ingredients_max_chars INTEGER NOT NULL DEFAULT 45,
    rotate BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE logic.batch (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    container_id TEXT NOT NULL REFERENCES logic.container_type(name),
    best_before_date DATE NULL,
    label_preset TEXT NULL REFERENCES logic.label_preset(name) ON UPDATE CASCADE ON DELETE SET NULL,
    details TEXT NULL,
    image_id UUID NULL REFERENCES logic.image(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE logic.batch_ingredient (
    batch_id UUID NOT NULL REFERENCES logic.batch(id) ON DELETE CASCADE,
    ingredient_name CITEXT NOT NULL REFERENCES logic.ingredient(name) ON UPDATE CASCADE,
    PRIMARY KEY (batch_id, ingredient_name)
);

CREATE TABLE logic.portion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES logic.batch(id),
    created_at DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'FROZEN' CHECK (status IN ('FROZEN', 'CONSUMED', 'DISCARDED')),
    consumed_at TIMESTAMPTZ NULL,
    discarded_at TIMESTAMPTZ NULL,
    print_count INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_portion_status ON logic.portion(status);
CREATE INDEX idx_portion_expiry_date ON logic.portion(expiry_date);
CREATE INDEX idx_portion_batch_id ON logic.portion(batch_id);

CREATE TABLE logic.recipe (
    name CITEXT PRIMARY KEY,
    default_portions INTEGER NOT NULL DEFAULT 1,
    default_container_id TEXT NULL REFERENCES logic.container_type(name),
    default_label_preset TEXT NULL REFERENCES logic.label_preset(name) ON UPDATE CASCADE ON DELETE SET NULL,
    details TEXT NULL,
    image_id UUID NULL REFERENCES logic.image(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE logic.recipe_ingredient (
    recipe_name CITEXT NOT NULL REFERENCES logic.recipe(name) ON DELETE CASCADE ON UPDATE CASCADE,
    ingredient_name CITEXT NOT NULL REFERENCES logic.ingredient(name) ON UPDATE CASCADE,
    PRIMARY KEY (recipe_name, ingredient_name)
);

CREATE INDEX idx_recipe_ingredient_recipe ON logic.recipe_ingredient(recipe_name);

-- =============================================================================
-- Helper Functions
-- =============================================================================

CREATE FUNCTION logic.store_image_base64(base64_data TEXT)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    new_id UUID;
BEGIN
    INSERT INTO logic.image (image_data)
    VALUES (decode(base64_data, 'base64'))
    RETURNING id INTO new_id;
    RETURN new_id;
END;
$$;

CREATE FUNCTION logic.get_image_base64(image_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    result TEXT;
BEGIN
    SELECT encode(image_data, 'base64')
    INTO result
    FROM logic.image
    WHERE id = image_id;
    RETURN result;
END;
$$;

CREATE FUNCTION logic.compute_expiry_date(
    p_created_at DATE,
    p_manual_expiry DATE,
    p_ingredient_names TEXT[]
) RETURNS DATE
LANGUAGE plpgsql
AS $$
DECLARE
    v_min_days INTEGER;
BEGIN
    -- Use manual override if provided
    IF p_manual_expiry IS NOT NULL THEN
        RETURN p_manual_expiry;
    END IF;

    -- Compute from min(expire_days) of selected ingredients
    SELECT MIN(i.expire_days)
    INTO v_min_days
    FROM logic.ingredient i
    WHERE i.name = ANY(p_ingredient_names)
      AND i.expire_days IS NOT NULL;

    IF v_min_days IS NULL THEN
        RAISE EXCEPTION 'No expiry data available for ingredients and no manual expiry provided';
    END IF;

    RETURN p_created_at + v_min_days;
END;
$$;

CREATE FUNCTION logic.compute_best_before_date(
    p_created_at DATE,
    p_ingredient_names TEXT[]
) RETURNS DATE
LANGUAGE plpgsql
AS $$
DECLARE
    v_min_days INTEGER;
BEGIN
    SELECT MIN(i.best_before_days)
    INTO v_min_days
    FROM logic.ingredient i
    WHERE i.name = ANY(p_ingredient_names)
      AND i.best_before_days IS NOT NULL;

    IF v_min_days IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN p_created_at + v_min_days;
END;
$$;

-- =============================================================================
-- Individual Event Handler Functions
-- =============================================================================

-- Ingredient handlers
CREATE FUNCTION logic.apply_ingredient_created(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO logic.ingredient (name, expire_days, best_before_days)
    VALUES (
        p->>'name',
        (p->>'expire_days')::INTEGER,
        (p->>'best_before_days')::INTEGER
    );
END;
$$;

CREATE FUNCTION logic.apply_ingredient_updated(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE logic.ingredient
    SET name = COALESCE(p->>'new_name', p->>'name'),
        expire_days = (p->>'expire_days')::INTEGER,
        best_before_days = (p->>'best_before_days')::INTEGER
    WHERE name = COALESCE(p->>'original_name', p->>'name');
END;
$$;

CREATE FUNCTION logic.apply_ingredient_deleted(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM logic.ingredient WHERE name = p->>'name';
END;
$$;

-- Container type handlers
CREATE FUNCTION logic.apply_container_type_created(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO logic.container_type (name, servings_per_unit)
    VALUES (
        p->>'name',
        (p->>'servings_per_unit')::NUMERIC(5,2)
    );
END;
$$;

CREATE FUNCTION logic.apply_container_type_updated(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE logic.container_type
    SET name = COALESCE(p->>'new_name', p->>'name'),
        servings_per_unit = (p->>'servings_per_unit')::NUMERIC(5,2)
    WHERE name = COALESCE(p->>'original_name', p->>'name');
END;
$$;

CREATE FUNCTION logic.apply_container_type_deleted(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM logic.container_type WHERE name = p->>'name';
END;
$$;

-- Label preset handlers
CREATE FUNCTION logic.apply_label_preset_created(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO logic.label_preset (
        name, label_type, width, height, qr_size, padding,
        title_font_size, date_font_size, small_font_size, font_family,
        show_title, show_ingredients, show_expiry_date, show_best_before,
        show_qr, show_branding,
        vertical_spacing, show_separator, separator_thickness, separator_color,
        corner_radius, title_min_font_size, ingredients_max_chars, rotate
    ) VALUES (
        p->>'name',
        COALESCE(p->>'label_type', '62'),
        COALESCE((p->>'width')::INTEGER, 696),
        COALESCE((p->>'height')::INTEGER, 300),
        COALESCE((p->>'qr_size')::INTEGER, 200),
        COALESCE((p->>'padding')::INTEGER, 20),
        COALESCE((p->>'title_font_size')::INTEGER, 48),
        COALESCE((p->>'date_font_size')::INTEGER, 32),
        COALESCE((p->>'small_font_size')::INTEGER, 18),
        COALESCE(p->>'font_family', 'Atkinson Hyperlegible, sans-serif'),
        COALESCE((p->>'show_title')::BOOLEAN, TRUE),
        COALESCE((p->>'show_ingredients')::BOOLEAN, FALSE),
        COALESCE((p->>'show_expiry_date')::BOOLEAN, TRUE),
        COALESCE((p->>'show_best_before')::BOOLEAN, FALSE),
        COALESCE((p->>'show_qr')::BOOLEAN, TRUE),
        COALESCE((p->>'show_branding')::BOOLEAN, TRUE),
        COALESCE((p->>'vertical_spacing')::INTEGER, 10),
        COALESCE((p->>'show_separator')::BOOLEAN, TRUE),
        COALESCE((p->>'separator_thickness')::INTEGER, 1),
        COALESCE(p->>'separator_color', '#cccccc'),
        COALESCE((p->>'corner_radius')::INTEGER, 0),
        COALESCE((p->>'title_min_font_size')::INTEGER, 24),
        COALESCE((p->>'ingredients_max_chars')::INTEGER, 45),
        COALESCE((p->>'rotate')::BOOLEAN, FALSE)
    );
END;
$$;

CREATE FUNCTION logic.apply_label_preset_updated(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE logic.label_preset
    SET name = COALESCE(p->>'new_name', p->>'name'),
        label_type = COALESCE(p->>'label_type', label_type),
        width = COALESCE((p->>'width')::INTEGER, width),
        height = COALESCE((p->>'height')::INTEGER, height),
        qr_size = COALESCE((p->>'qr_size')::INTEGER, qr_size),
        padding = COALESCE((p->>'padding')::INTEGER, padding),
        title_font_size = COALESCE((p->>'title_font_size')::INTEGER, title_font_size),
        date_font_size = COALESCE((p->>'date_font_size')::INTEGER, date_font_size),
        small_font_size = COALESCE((p->>'small_font_size')::INTEGER, small_font_size),
        font_family = COALESCE(p->>'font_family', font_family),
        show_title = COALESCE((p->>'show_title')::BOOLEAN, show_title),
        show_ingredients = COALESCE((p->>'show_ingredients')::BOOLEAN, show_ingredients),
        show_expiry_date = COALESCE((p->>'show_expiry_date')::BOOLEAN, show_expiry_date),
        show_best_before = COALESCE((p->>'show_best_before')::BOOLEAN, show_best_before),
        show_qr = COALESCE((p->>'show_qr')::BOOLEAN, show_qr),
        show_branding = COALESCE((p->>'show_branding')::BOOLEAN, show_branding),
        vertical_spacing = COALESCE((p->>'vertical_spacing')::INTEGER, vertical_spacing),
        show_separator = COALESCE((p->>'show_separator')::BOOLEAN, show_separator),
        separator_thickness = COALESCE((p->>'separator_thickness')::INTEGER, separator_thickness),
        separator_color = COALESCE(p->>'separator_color', separator_color),
        corner_radius = COALESCE((p->>'corner_radius')::INTEGER, corner_radius),
        title_min_font_size = COALESCE((p->>'title_min_font_size')::INTEGER, title_min_font_size),
        ingredients_max_chars = COALESCE((p->>'ingredients_max_chars')::INTEGER, ingredients_max_chars),
        rotate = COALESCE((p->>'rotate')::BOOLEAN, rotate)
    WHERE name = COALESCE(p->>'original_name', p->>'name');
END;
$$;

CREATE FUNCTION logic.apply_label_preset_deleted(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM logic.label_preset WHERE name = p->>'name';
END;
$$;

-- Batch handler
CREATE FUNCTION logic.apply_batch_created(p JSONB, p_created_at TIMESTAMPTZ)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_ingredient_name TEXT;
    v_image_id UUID;
    v_portion_id TEXT;
    v_ingredient_names TEXT[];
    v_portion_ids TEXT[];
BEGIN
    -- Extract arrays from JSONB
    SELECT array_agg(elem::TEXT)
    INTO v_ingredient_names
    FROM jsonb_array_elements_text(p->'ingredient_names') elem;

    SELECT array_agg(elem::TEXT)
    INTO v_portion_ids
    FROM jsonb_array_elements_text(p->'portion_ids') elem;

    -- Auto-create unknown ingredients
    IF v_ingredient_names IS NOT NULL THEN
        FOREACH v_ingredient_name IN ARRAY v_ingredient_names
        LOOP
            INSERT INTO logic.ingredient (name)
            VALUES (LOWER(v_ingredient_name))
            ON CONFLICT (name) DO NOTHING;
        END LOOP;
    END IF;

    -- Store image if provided
    IF p->>'image_data' IS NOT NULL AND p->>'image_data' != '' THEN
        v_image_id := logic.store_image_base64(p->>'image_data');
    END IF;

    -- Create batch
    INSERT INTO logic.batch (id, name, container_id, best_before_date, label_preset, details, image_id, created_at)
    VALUES (
        (p->>'batch_id')::UUID,
        p->>'name',
        p->>'container_id',
        (p->>'best_before_date')::DATE,
        p->>'label_preset',
        p->>'details',
        v_image_id,
        COALESCE((p->>'created_at')::TIMESTAMPTZ, p_created_at)
    );

    -- Link ingredients
    IF v_ingredient_names IS NOT NULL THEN
        INSERT INTO logic.batch_ingredient (batch_id, ingredient_name)
        SELECT (p->>'batch_id')::UUID, LOWER(unnest(v_ingredient_names));
    END IF;

    -- Create portions
    IF v_portion_ids IS NOT NULL THEN
        FOREACH v_portion_id IN ARRAY v_portion_ids
        LOOP
            INSERT INTO logic.portion (id, batch_id, created_at, expiry_date)
            VALUES (
                v_portion_id::UUID,
                (p->>'batch_id')::UUID,
                COALESCE((p->>'created_at')::DATE, p_created_at::DATE),
                (p->>'expiry_date')::DATE
            );
        END LOOP;
    END IF;
END;
$$;

-- Batch update handler
CREATE FUNCTION logic.apply_batch_updated(p JSONB, p_created_at TIMESTAMPTZ)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_batch_id UUID;
    v_ingredient_name TEXT;
    v_ingredient_names TEXT[];
    v_image_id UUID;
    v_existing_image_id UUID;
BEGIN
    v_batch_id := (p->>'batch_id')::UUID;

    -- Extract ingredient names
    SELECT array_agg(elem::TEXT)
    INTO v_ingredient_names
    FROM jsonb_array_elements_text(p->'ingredient_names') elem;

    -- Auto-create unknown ingredients
    IF v_ingredient_names IS NOT NULL THEN
        FOREACH v_ingredient_name IN ARRAY v_ingredient_names
        LOOP
            INSERT INTO logic.ingredient (name)
            VALUES (LOWER(v_ingredient_name))
            ON CONFLICT (name) DO NOTHING;
        END LOOP;
    END IF;

    -- Handle image
    SELECT image_id INTO v_existing_image_id FROM logic.batch WHERE id = v_batch_id;

    IF p->>'image_data' IS NOT NULL AND p->>'image_data' != '' THEN
        -- New image provided
        v_image_id := logic.store_image_base64(p->>'image_data');
    ELSIF (p->>'remove_image')::BOOLEAN IS TRUE THEN
        -- Explicitly remove image
        v_image_id := NULL;
    ELSE
        -- Keep existing image
        v_image_id := v_existing_image_id;
    END IF;

    -- Update batch fields
    UPDATE logic.batch
    SET name = COALESCE(p->>'name', name),
        container_id = COALESCE(p->>'container_id', container_id),
        best_before_date = (p->>'best_before_date')::DATE,
        label_preset = p->>'label_preset',
        details = p->>'details',
        image_id = v_image_id
    WHERE id = v_batch_id;

    -- Replace ingredients
    DELETE FROM logic.batch_ingredient WHERE batch_id = v_batch_id;
    IF v_ingredient_names IS NOT NULL THEN
        INSERT INTO logic.batch_ingredient (batch_id, ingredient_name)
        SELECT v_batch_id, LOWER(unnest(v_ingredient_names));
    END IF;
END;
$$;

-- Portions added handler (for adding portions to existing batch)
CREATE FUNCTION logic.apply_portions_added(p JSONB, p_created_at TIMESTAMPTZ)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_portion_id TEXT;
    v_portion_ids TEXT[];
BEGIN
    SELECT array_agg(elem::TEXT)
    INTO v_portion_ids
    FROM jsonb_array_elements_text(p->'portion_ids') elem;

    IF v_portion_ids IS NOT NULL THEN
        FOREACH v_portion_id IN ARRAY v_portion_ids
        LOOP
            INSERT INTO logic.portion (id, batch_id, created_at, expiry_date)
            VALUES (
                v_portion_id::UUID,
                (p->>'batch_id')::UUID,
                COALESCE((p->>'created_at')::DATE, p_created_at::DATE),
                (p->>'expiry_date')::DATE
            );
        END LOOP;
    END IF;
END;
$$;

-- Portion handlers
CREATE FUNCTION logic.apply_portion_consumed(p JSONB, p_created_at TIMESTAMPTZ)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE logic.portion
    SET status = 'CONSUMED',
        consumed_at = COALESCE((p->>'consumed_at')::TIMESTAMPTZ, p_created_at)
    WHERE id = (p->>'portion_id')::UUID;
END;
$$;

CREATE FUNCTION logic.apply_portion_returned(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE logic.portion
    SET status = 'FROZEN',
        consumed_at = NULL
    WHERE id = (p->>'portion_id')::UUID;
END;
$$;

CREATE FUNCTION logic.apply_portion_discarded(p JSONB, p_created_at TIMESTAMPTZ)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE logic.portion
    SET status = 'DISCARDED',
        discarded_at = COALESCE((p->>'discarded_at')::TIMESTAMPTZ, p_created_at)
    WHERE id = (p->>'portion_id')::UUID;
END;
$$;

CREATE FUNCTION logic.apply_portion_printed(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE logic.portion
    SET print_count = print_count + 1
    WHERE id = (p->>'portion_id')::UUID;
END;
$$;

-- Recipe handlers
CREATE FUNCTION logic.apply_recipe_saved(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_ingredient_name TEXT;
    v_image_id UUID;
    v_ingredient_names TEXT[];
    v_recipe_name TEXT;
BEGIN
    v_recipe_name := p->>'name';

    -- Extract ingredient names
    SELECT array_agg(elem::TEXT)
    INTO v_ingredient_names
    FROM jsonb_array_elements_text(p->'ingredient_names') elem;

    -- Auto-create unknown ingredients
    IF v_ingredient_names IS NOT NULL THEN
        FOREACH v_ingredient_name IN ARRAY v_ingredient_names
        LOOP
            INSERT INTO logic.ingredient (name)
            VALUES (LOWER(v_ingredient_name))
            ON CONFLICT (name) DO NOTHING;
        END LOOP;
    END IF;

    -- Store image if provided
    IF p->>'image_data' IS NOT NULL AND p->>'image_data' != '' THEN
        v_image_id := logic.store_image_base64(p->>'image_data');
    END IF;

    -- If editing (original name provided), delete old recipe first
    IF p->>'original_name' IS NOT NULL THEN
        DELETE FROM logic.recipe WHERE name = p->>'original_name';
    END IF;

    -- Insert or update recipe
    INSERT INTO logic.recipe (name, default_portions, default_container_id, default_label_preset, details, image_id)
    VALUES (
        v_recipe_name,
        COALESCE((p->>'default_portions')::INTEGER, 1),
        p->>'default_container_id',
        p->>'default_label_preset',
        p->>'details',
        v_image_id
    )
    ON CONFLICT (name) DO UPDATE SET
        default_portions = EXCLUDED.default_portions,
        default_container_id = EXCLUDED.default_container_id,
        default_label_preset = EXCLUDED.default_label_preset,
        details = EXCLUDED.details,
        image_id = COALESCE(EXCLUDED.image_id, logic.recipe.image_id);

    -- Clear old ingredients and insert new ones
    DELETE FROM logic.recipe_ingredient WHERE recipe_name = v_recipe_name;
    IF v_ingredient_names IS NOT NULL THEN
        INSERT INTO logic.recipe_ingredient (recipe_name, ingredient_name)
        SELECT v_recipe_name, LOWER(unnest(v_ingredient_names));
    END IF;
END;
$$;

CREATE FUNCTION logic.apply_recipe_deleted(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM logic.recipe WHERE name = p->>'name';
END;
$$;

-- =============================================================================
-- Event Dispatcher
-- =============================================================================

CREATE FUNCTION logic.apply_event(p_type TEXT, p_payload JSONB, p_created_at TIMESTAMPTZ)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    CASE p_type
        -- Ingredients
        WHEN 'ingredient_created' THEN
            PERFORM logic.apply_ingredient_created(p_payload);
        WHEN 'ingredient_updated' THEN
            PERFORM logic.apply_ingredient_updated(p_payload);
        WHEN 'ingredient_deleted' THEN
            PERFORM logic.apply_ingredient_deleted(p_payload);
        -- Container types
        WHEN 'container_type_created' THEN
            PERFORM logic.apply_container_type_created(p_payload);
        WHEN 'container_type_updated' THEN
            PERFORM logic.apply_container_type_updated(p_payload);
        WHEN 'container_type_deleted' THEN
            PERFORM logic.apply_container_type_deleted(p_payload);
        -- Label presets
        WHEN 'label_preset_created' THEN
            PERFORM logic.apply_label_preset_created(p_payload);
        WHEN 'label_preset_updated' THEN
            PERFORM logic.apply_label_preset_updated(p_payload);
        WHEN 'label_preset_deleted' THEN
            PERFORM logic.apply_label_preset_deleted(p_payload);
        -- Batches
        WHEN 'batch_created' THEN
            PERFORM logic.apply_batch_created(p_payload, p_created_at);
        WHEN 'batch_updated' THEN
            PERFORM logic.apply_batch_updated(p_payload, p_created_at);
        WHEN 'portions_added' THEN
            PERFORM logic.apply_portions_added(p_payload, p_created_at);
        -- Portions
        WHEN 'portion_consumed' THEN
            PERFORM logic.apply_portion_consumed(p_payload, p_created_at);
        WHEN 'portion_returned' THEN
            PERFORM logic.apply_portion_returned(p_payload);
        WHEN 'portion_discarded' THEN
            PERFORM logic.apply_portion_discarded(p_payload, p_created_at);
        WHEN 'portion_printed' THEN
            PERFORM logic.apply_portion_printed(p_payload);
        -- Recipes
        WHEN 'recipe_saved' THEN
            PERFORM logic.apply_recipe_saved(p_payload);
        WHEN 'recipe_deleted' THEN
            PERFORM logic.apply_recipe_deleted(p_payload);
        ELSE
            RAISE WARNING 'Unknown event type: %', p_type;
    END CASE;
END;
$$;

-- =============================================================================
-- Trigger: auto-apply events on INSERT
-- =============================================================================

CREATE FUNCTION logic.handle_event()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM logic.apply_event(NEW.type, NEW.payload, NEW.created_at);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER event_handler
    AFTER INSERT ON data.event
    FOR EACH ROW EXECUTE FUNCTION logic.handle_event();

-- =============================================================================
-- Replay Function
-- =============================================================================

CREATE FUNCTION logic.replay_all_events()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    -- Truncate all projection tables (reverse dependency order)
    TRUNCATE logic.recipe_ingredient, logic.batch_ingredient,
             logic.portion, logic.recipe, logic.batch,
             logic.label_preset, logic.container_type,
             logic.ingredient, logic.image CASCADE;

    -- Replay each event in order (calls apply_event directly, no trigger)
    PERFORM logic.apply_event(e.type, e.payload, e.created_at)
    FROM data.event e ORDER BY e.id;
END;
$$;
