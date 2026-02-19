-- LabelMaker API Layer
-- Read views and RPC write functions exposed via PostgREST
-- This file is idempotent: DROP + CREATE on each deploy

DROP SCHEMA IF EXISTS labelmaker_api CASCADE;
CREATE SCHEMA labelmaker_api;

-- =============================================================================
-- Read Views
-- =============================================================================

-- Event view (supports INSERT for writes via PostgREST auto-updatable view)
CREATE VIEW labelmaker_api.event AS
SELECT * FROM labelmaker_data.event;

-- Template list (for list page — summary only, excludes deleted)
CREATE VIEW labelmaker_api.template_list AS
SELECT id, name, label_type_id, created_at
FROM labelmaker_logic.template
WHERE deleted = FALSE
ORDER BY created_at DESC;

-- Template detail (for editor — full state, single row)
CREATE VIEW labelmaker_api.template_detail AS
SELECT id, name, label_type_id, label_width, label_height, corner_radius,
       rotate, padding, content, next_id, sample_values
FROM labelmaker_logic.template
WHERE deleted = FALSE;

-- Label list (for list page — summary with template info, excludes deleted)
CREATE VIEW labelmaker_api.label_list AS
SELECT l.id, l.template_id, t.name AS template_name, t.label_type_id,
       l.values, l.created_at
FROM labelmaker_logic.label l
JOIN labelmaker_logic.template t ON t.id = l.template_id AND t.deleted = FALSE
WHERE l.deleted = FALSE
ORDER BY l.created_at DESC;

-- Label detail (for editor — full template data for rendering)
CREATE VIEW labelmaker_api.label_detail AS
SELECT l.id, l.template_id, t.name AS template_name, t.label_type_id,
       t.label_width, t.label_height, t.corner_radius, t.rotate, t.padding, t.content,
       l.values, l.created_at
FROM labelmaker_logic.label l
JOIN labelmaker_logic.template t ON t.id = l.template_id AND t.deleted = FALSE
WHERE l.deleted = FALSE;

-- =============================================================================
-- RPC Functions
-- =============================================================================

-- Create label from template (copies sample_values as initial values)
CREATE FUNCTION labelmaker_api.create_label(p_template_id UUID)
RETURNS TABLE(label_id UUID) LANGUAGE plpgsql AS $$
DECLARE
    v_id UUID := gen_random_uuid();
    v_sample_values JSONB;
BEGIN
    SELECT sample_values INTO v_sample_values
    FROM labelmaker_logic.template
    WHERE id = p_template_id AND deleted = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Template not found: %', p_template_id;
    END IF;

    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('label_created', jsonb_build_object(
        'label_id', v_id,
        'template_id', p_template_id,
        'values', v_sample_values
    ));
    RETURN QUERY SELECT v_id;
END;
$$;

-- Create template (server generates UUID, returns it)
CREATE FUNCTION labelmaker_api.create_template(p_name TEXT)
RETURNS TABLE(template_id UUID) LANGUAGE plpgsql AS $$
DECLARE
    v_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('template_created', jsonb_build_object('template_id', v_id, 'name', p_name));
    RETURN QUERY SELECT v_id;
END;
$$;
