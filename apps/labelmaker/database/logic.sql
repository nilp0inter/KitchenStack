-- LabelMaker Logic Layer
-- Projection tables, event handlers, business logic, and replay functions
-- This file is idempotent: DROP + CREATE on each deploy

DROP SCHEMA IF EXISTS labelmaker_logic CASCADE;
CREATE SCHEMA labelmaker_logic;

-- =============================================================================
-- Projection Tables (rebuilt from events on replay)
-- =============================================================================

CREATE TABLE labelmaker_logic.template (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL DEFAULT 'Sin nombre',
    label_type_id TEXT NOT NULL DEFAULT '62',
    label_width INTEGER NOT NULL DEFAULT 696,
    label_height INTEGER NOT NULL DEFAULT 1680,
    corner_radius INTEGER NOT NULL DEFAULT 0,
    rotate BOOLEAN NOT NULL DEFAULT FALSE,
    padding INTEGER NOT NULL DEFAULT 20,
    content JSONB NOT NULL DEFAULT '[]'::JSONB,
    next_id INTEGER NOT NULL DEFAULT 2,
    sample_values JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- =============================================================================
-- Event Handler Functions
-- =============================================================================

CREATE FUNCTION labelmaker_logic.apply_template_created(p JSONB, p_created_at TIMESTAMPTZ)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_logic.template (id, name, created_at)
    VALUES ((p->>'template_id')::UUID, p->>'name', p_created_at);
END;
$$;

CREATE FUNCTION labelmaker_logic.apply_template_deleted(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE labelmaker_logic.template SET deleted = TRUE
    WHERE id = (p->>'template_id')::UUID;
END;
$$;

CREATE FUNCTION labelmaker_logic.apply_template_name_set(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE labelmaker_logic.template SET name = p->>'name'
    WHERE id = (p->>'template_id')::UUID;
END;
$$;

CREATE FUNCTION labelmaker_logic.apply_template_label_type_set(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE labelmaker_logic.template
    SET label_type_id = p->>'label_type_id',
        label_width = (p->>'label_width')::INTEGER,
        label_height = (p->>'label_height')::INTEGER,
        corner_radius = (p->>'corner_radius')::INTEGER,
        rotate = (p->>'rotate')::BOOLEAN
    WHERE id = (p->>'template_id')::UUID;
END;
$$;

CREATE FUNCTION labelmaker_logic.apply_template_height_set(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE labelmaker_logic.template SET label_height = (p->>'label_height')::INTEGER
    WHERE id = (p->>'template_id')::UUID;
END;
$$;

CREATE FUNCTION labelmaker_logic.apply_template_padding_set(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE labelmaker_logic.template SET padding = (p->>'padding')::INTEGER
    WHERE id = (p->>'template_id')::UUID;
END;
$$;

CREATE FUNCTION labelmaker_logic.apply_template_content_set(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE labelmaker_logic.template
    SET content = p->'content',
        next_id = (p->>'next_id')::INTEGER
    WHERE id = (p->>'template_id')::UUID;
END;
$$;

CREATE FUNCTION labelmaker_logic.apply_template_sample_value_set(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE labelmaker_logic.template
    SET sample_values = sample_values || jsonb_build_object(p->>'variable_name', p->>'value')
    WHERE id = (p->>'template_id')::UUID;
END;
$$;

-- =============================================================================
-- Label Projection Table
-- =============================================================================

CREATE TABLE labelmaker_logic.label (
    id UUID PRIMARY KEY,
    template_id UUID NOT NULL REFERENCES labelmaker_logic.template(id),
    name TEXT NOT NULL DEFAULT 'Sin nombre',
    values JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- =============================================================================
-- LabelSet Projection Table
-- =============================================================================

CREATE TABLE labelmaker_logic.labelset (
    id UUID PRIMARY KEY,
    template_id UUID NOT NULL REFERENCES labelmaker_logic.template(id),
    name TEXT NOT NULL DEFAULT 'Sin nombre',
    rows JSONB NOT NULL DEFAULT '[]'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- =============================================================================
-- Label Event Handler Functions
-- =============================================================================

CREATE FUNCTION labelmaker_logic.apply_label_created(p JSONB, p_created_at TIMESTAMPTZ)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_logic.label (id, template_id, name, values, created_at)
    VALUES ((p->>'label_id')::UUID, (p->>'template_id')::UUID, COALESCE(p->>'name', 'Sin nombre'), p->'values', p_created_at);
END;
$$;

CREATE FUNCTION labelmaker_logic.apply_label_deleted(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE labelmaker_logic.label SET deleted = TRUE
    WHERE id = (p->>'label_id')::UUID;
END;
$$;

CREATE FUNCTION labelmaker_logic.apply_label_values_set(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE labelmaker_logic.label SET values = p->'values'
    WHERE id = (p->>'label_id')::UUID;
END;
$$;

CREATE FUNCTION labelmaker_logic.apply_label_name_set(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE labelmaker_logic.label SET name = p->>'name'
    WHERE id = (p->>'label_id')::UUID;
END;
$$;

-- =============================================================================
-- LabelSet Event Handler Functions
-- =============================================================================

CREATE FUNCTION labelmaker_logic.apply_labelset_created(p JSONB, p_created_at TIMESTAMPTZ)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO labelmaker_logic.labelset (id, template_id, name, rows, created_at)
    VALUES ((p->>'labelset_id')::UUID, (p->>'template_id')::UUID, p->>'name', p->'rows', p_created_at);
END;
$$;

CREATE FUNCTION labelmaker_logic.apply_labelset_deleted(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE labelmaker_logic.labelset SET deleted = TRUE
    WHERE id = (p->>'labelset_id')::UUID;
END;
$$;

CREATE FUNCTION labelmaker_logic.apply_labelset_name_set(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE labelmaker_logic.labelset SET name = p->>'name'
    WHERE id = (p->>'labelset_id')::UUID;
END;
$$;

CREATE FUNCTION labelmaker_logic.apply_labelset_rows_set(p JSONB)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE labelmaker_logic.labelset SET rows = p->'rows'
    WHERE id = (p->>'labelset_id')::UUID;
END;
$$;

-- =============================================================================
-- Event Dispatcher
-- =============================================================================

CREATE FUNCTION labelmaker_logic.apply_event(p_type TEXT, p_payload JSONB, p_created_at TIMESTAMPTZ)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    CASE p_type
        WHEN 'template_created' THEN
            PERFORM labelmaker_logic.apply_template_created(p_payload, p_created_at);
        WHEN 'template_deleted' THEN
            PERFORM labelmaker_logic.apply_template_deleted(p_payload);
        WHEN 'template_name_set' THEN
            PERFORM labelmaker_logic.apply_template_name_set(p_payload);
        WHEN 'template_label_type_set' THEN
            PERFORM labelmaker_logic.apply_template_label_type_set(p_payload);
        WHEN 'template_height_set' THEN
            PERFORM labelmaker_logic.apply_template_height_set(p_payload);
        WHEN 'template_padding_set' THEN
            PERFORM labelmaker_logic.apply_template_padding_set(p_payload);
        WHEN 'template_content_set' THEN
            PERFORM labelmaker_logic.apply_template_content_set(p_payload);
        WHEN 'template_sample_value_set' THEN
            PERFORM labelmaker_logic.apply_template_sample_value_set(p_payload);
        WHEN 'label_created' THEN
            PERFORM labelmaker_logic.apply_label_created(p_payload, p_created_at);
        WHEN 'label_deleted' THEN
            PERFORM labelmaker_logic.apply_label_deleted(p_payload);
        WHEN 'label_values_set' THEN
            PERFORM labelmaker_logic.apply_label_values_set(p_payload);
        WHEN 'label_name_set' THEN
            PERFORM labelmaker_logic.apply_label_name_set(p_payload);
        WHEN 'labelset_created' THEN
            PERFORM labelmaker_logic.apply_labelset_created(p_payload, p_created_at);
        WHEN 'labelset_deleted' THEN
            PERFORM labelmaker_logic.apply_labelset_deleted(p_payload);
        WHEN 'labelset_name_set' THEN
            PERFORM labelmaker_logic.apply_labelset_name_set(p_payload);
        WHEN 'labelset_rows_set' THEN
            PERFORM labelmaker_logic.apply_labelset_rows_set(p_payload);
        ELSE
            RAISE WARNING 'Unknown event type: %', p_type;
    END CASE;
END;
$$;

-- =============================================================================
-- Trigger: auto-apply events on INSERT
-- =============================================================================

CREATE FUNCTION labelmaker_logic.handle_event()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM labelmaker_logic.apply_event(NEW.type, NEW.payload, NEW.created_at);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER event_handler
    AFTER INSERT ON labelmaker_data.event
    FOR EACH ROW EXECUTE FUNCTION labelmaker_logic.handle_event();

-- =============================================================================
-- Replay Function
-- =============================================================================

CREATE FUNCTION labelmaker_logic.replay_all_events()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    TRUNCATE labelmaker_logic.labelset CASCADE;
    TRUNCATE labelmaker_logic.label CASCADE;
    TRUNCATE labelmaker_logic.template CASCADE;

    PERFORM labelmaker_logic.apply_event(e.type, e.payload, e.created_at)
    FROM labelmaker_data.event e ORDER BY e.id;
END;
$$;
