-- FrostByte Database Schema: Data Layer (Event Sourcing)
-- All persistent tables live in the 'data' schema

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS citext;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS data;
CREATE SCHEMA IF NOT EXISTS logic;
CREATE SCHEMA IF NOT EXISTS api;

-- =============================================================================
-- Event Store
-- =============================================================================

CREATE TABLE data.event (
    id BIGSERIAL PRIMARY KEY,
    type TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_event_type ON data.event(type);
CREATE INDEX idx_event_created_at ON data.event(created_at);

-- =============================================================================
-- Projection Tables (rebuilt from events)
-- =============================================================================

-- Label preset table: named label configurations for printing
CREATE TABLE data.label_preset (
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

-- Image table: stores images as binary data
CREATE TABLE data.image (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    image_data BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ingredient table: defines ingredients with optional shelf life info
CREATE TABLE data.ingredient (
    name CITEXT PRIMARY KEY,
    expire_days INTEGER NULL,
    best_before_days INTEGER NULL
);

-- Container type table: defines container types and their serving sizes
CREATE TABLE data.container_type (
    name TEXT PRIMARY KEY,
    servings_per_unit NUMERIC(5,2) NOT NULL
);

-- Batch table: groups portions created together
CREATE TABLE data.batch (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    container_id TEXT NOT NULL REFERENCES data.container_type(name),
    best_before_date DATE NULL,
    label_preset TEXT NULL REFERENCES data.label_preset(name) ON UPDATE CASCADE ON DELETE SET NULL,
    details TEXT NULL,
    image_id UUID NULL REFERENCES data.image(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Junction table for batch-ingredient relationship
CREATE TABLE data.batch_ingredient (
    batch_id UUID NOT NULL REFERENCES data.batch(id) ON DELETE CASCADE,
    ingredient_name CITEXT NOT NULL REFERENCES data.ingredient(name) ON UPDATE CASCADE,
    PRIMARY KEY (batch_id, ingredient_name)
);

-- Portion table: individual frozen items (one per physical container/label)
CREATE TABLE data.portion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES data.batch(id),
    created_at DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'FROZEN' CHECK (status IN ('FROZEN', 'CONSUMED')),
    consumed_at TIMESTAMPTZ NULL
);

CREATE INDEX idx_portion_status ON data.portion(status);
CREATE INDEX idx_portion_expiry_date ON data.portion(expiry_date);
CREATE INDEX idx_portion_batch_id ON data.portion(batch_id);

-- Recipe table: reusable templates for batch creation
CREATE TABLE data.recipe (
    name CITEXT PRIMARY KEY,
    default_portions INTEGER NOT NULL DEFAULT 1,
    default_container_id TEXT NULL REFERENCES data.container_type(name),
    default_label_preset TEXT NULL REFERENCES data.label_preset(name) ON UPDATE CASCADE ON DELETE SET NULL,
    details TEXT NULL,
    image_id UUID NULL REFERENCES data.image(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Junction table for recipe-ingredient relationship
CREATE TABLE data.recipe_ingredient (
    recipe_name CITEXT NOT NULL REFERENCES data.recipe(name) ON DELETE CASCADE ON UPDATE CASCADE,
    ingredient_name CITEXT NOT NULL REFERENCES data.ingredient(name) ON UPDATE CASCADE,
    PRIMARY KEY (recipe_name, ingredient_name)
);

CREATE INDEX idx_recipe_ingredient_recipe ON data.recipe_ingredient(recipe_name);
