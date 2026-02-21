-- LabelMaker API Layer
-- Read views and RPC write functions exposed via PostgREST
-- This file is idempotent: DROP + CREATE on each deploy

DROP SCHEMA IF EXISTS labelmaker_api CASCADE;
CREATE SCHEMA labelmaker_api;

-- =============================================================================
-- Read Views
-- =============================================================================

-- Template list (for list page — summary only, excludes deleted)
CREATE VIEW labelmaker_api.template_list AS
SELECT id, name, label_type_id, created_at
FROM labelmaker_logic.template
WHERE deleted = FALSE
ORDER BY created_at DESC;

-- Template detail (for editor — full state, single row)
CREATE VIEW labelmaker_api.template_detail AS
SELECT id, name, label_type_id, label_width, label_height, corner_radius,
       rotate, padding, offset_x, offset_y, content, next_id, sample_values
FROM labelmaker_logic.template
WHERE deleted = FALSE;

-- Label list (for list page — summary with template info, excludes deleted)
CREATE VIEW labelmaker_api.label_list AS
SELECT l.id, l.template_id, t.name AS template_name, t.label_type_id,
       l.name, l.values, l.created_at
FROM labelmaker_logic.label l
JOIN labelmaker_logic.template t ON t.id = l.template_id AND t.deleted = FALSE
WHERE l.deleted = FALSE
ORDER BY l.created_at DESC;

-- Label detail (for editor — full template data for rendering)
CREATE VIEW labelmaker_api.label_detail AS
SELECT l.id, l.template_id, t.name AS template_name, t.label_type_id,
       t.label_width, t.label_height, t.corner_radius, t.rotate, t.padding, t.offset_x, t.offset_y, t.content,
       l.name, l.values, l.created_at
FROM labelmaker_logic.label l
JOIN labelmaker_logic.template t ON t.id = l.template_id AND t.deleted = FALSE
WHERE l.deleted = FALSE;

-- LabelSet list (for list page — summary with template info, excludes deleted)
CREATE VIEW labelmaker_api.labelset_list AS
SELECT ls.id, ls.template_id, t.name AS template_name, t.label_type_id,
       ls.name, jsonb_array_length(ls.rows) AS row_count, ls.created_at
FROM labelmaker_logic.labelset ls
JOIN labelmaker_logic.template t ON t.id = ls.template_id AND t.deleted = FALSE
WHERE ls.deleted = FALSE
ORDER BY ls.created_at DESC;

-- LabelSet detail (for editor — full template data for rendering + rows)
CREATE VIEW labelmaker_api.labelset_detail AS
SELECT ls.id, ls.template_id, t.name AS template_name, t.label_type_id,
       t.label_width, t.label_height, t.corner_radius, t.rotate, t.padding, t.offset_x, t.offset_y, t.content,
       ls.name, ls.rows, ls.created_at
FROM labelmaker_logic.labelset ls
JOIN labelmaker_logic.template t ON t.id = ls.template_id AND t.deleted = FALSE
WHERE ls.deleted = FALSE;

-- =============================================================================
-- RPC Functions
-- =============================================================================

-- Create label from template (copies sample_values as initial values)
CREATE FUNCTION labelmaker_api.create_label(p_template_id UUID, p_name TEXT)
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
        'name', p_name,
        'values', v_sample_values
    ));
    RETURN QUERY SELECT v_id;
END;
$$;

-- Create labelset from template (copies sample_values as first row)
CREATE FUNCTION labelmaker_api.create_labelset(p_template_id UUID, p_name TEXT)
RETURNS TABLE(labelset_id UUID) LANGUAGE plpgsql AS $$
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
    VALUES ('labelset_created', jsonb_build_object(
        'labelset_id', v_id,
        'template_id', p_template_id,
        'name', p_name,
        'rows', jsonb_build_array(v_sample_values)
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

-- Delete template
CREATE FUNCTION labelmaker_api.delete_template(p_template_id UUID)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('template_deleted', jsonb_build_object('template_id', p_template_id));
END;
$$;

-- Set template name
CREATE FUNCTION labelmaker_api.set_template_name(p_template_id UUID, p_name TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('template_name_set', jsonb_build_object('template_id', p_template_id, 'name', p_name));
END;
$$;

-- Set template label type
CREATE FUNCTION labelmaker_api.set_template_label_type(p_template_id UUID, p_label_type_id TEXT, p_label_width INT, p_label_height INT, p_corner_radius INT, p_rotate BOOLEAN)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('template_label_type_set', jsonb_build_object(
        'template_id', p_template_id,
        'label_type_id', p_label_type_id,
        'label_width', p_label_width,
        'label_height', p_label_height,
        'corner_radius', p_corner_radius,
        'rotate', p_rotate
    ));
END;
$$;

-- Set template height
CREATE FUNCTION labelmaker_api.set_template_height(p_template_id UUID, p_label_height INT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('template_height_set', jsonb_build_object('template_id', p_template_id, 'label_height', p_label_height));
END;
$$;

-- Set template padding
CREATE FUNCTION labelmaker_api.set_template_padding(p_template_id UUID, p_padding INT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('template_padding_set', jsonb_build_object('template_id', p_template_id, 'padding', p_padding));
END;
$$;

-- Set template offset
CREATE FUNCTION labelmaker_api.set_template_offset(p_template_id UUID, p_offset_x INT, p_offset_y INT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('template_offset_set', jsonb_build_object('template_id', p_template_id, 'offset_x', p_offset_x, 'offset_y', p_offset_y));
END;
$$;

-- Set template content
CREATE FUNCTION labelmaker_api.set_template_content(p_template_id UUID, p_content JSONB, p_next_id INT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('template_content_set', jsonb_build_object('template_id', p_template_id, 'content', p_content, 'next_id', p_next_id));
END;
$$;

-- Set template sample value
CREATE FUNCTION labelmaker_api.set_template_sample_value(p_template_id UUID, p_variable_name TEXT, p_value TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('template_sample_value_set', jsonb_build_object('template_id', p_template_id, 'variable_name', p_variable_name, 'value', p_value));
END;
$$;

-- Delete label
CREATE FUNCTION labelmaker_api.delete_label(p_label_id UUID)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('label_deleted', jsonb_build_object('label_id', p_label_id));
END;
$$;

-- Set label name
CREATE FUNCTION labelmaker_api.set_label_name(p_label_id UUID, p_name TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('label_name_set', jsonb_build_object('label_id', p_label_id, 'name', p_name));
END;
$$;

-- Set label values
CREATE FUNCTION labelmaker_api.set_label_values(p_label_id UUID, p_values JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('label_values_set', jsonb_build_object('label_id', p_label_id, 'values', p_values));
END;
$$;

-- Delete labelset
CREATE FUNCTION labelmaker_api.delete_labelset(p_labelset_id UUID)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('labelset_deleted', jsonb_build_object('labelset_id', p_labelset_id));
END;
$$;

-- Set labelset name
CREATE FUNCTION labelmaker_api.set_labelset_name(p_labelset_id UUID, p_name TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('labelset_name_set', jsonb_build_object('labelset_id', p_labelset_id, 'name', p_name));
END;
$$;

-- Set labelset rows
CREATE FUNCTION labelmaker_api.set_labelset_rows(p_labelset_id UUID, p_rows JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_data.event (type, payload)
    VALUES ('labelset_rows_set', jsonb_build_object('labelset_id', p_labelset_id, 'rows', p_rows));
END;
$$;
