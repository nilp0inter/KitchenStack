-- Migration 002: Separate events from projections
-- Moves projection tables from data schema to logic schema (idempotent).
-- The logic.sql file now creates these tables inside logic schema.
-- This migration drops the old data-schema copies so replay can rebuild cleanly.

-- Drop old trigger that references logic functions about to be recreated
DROP TRIGGER IF EXISTS event_handler ON data.event;

-- Drop projection tables from data schema (reverse dependency order)
DROP TABLE IF EXISTS data.recipe_ingredient CASCADE;
DROP TABLE IF EXISTS data.batch_ingredient CASCADE;
DROP TABLE IF EXISTS data.portion CASCADE;
DROP TABLE IF EXISTS data.recipe CASCADE;
DROP TABLE IF EXISTS data.batch CASCADE;
DROP TABLE IF EXISTS data.label_preset CASCADE;
DROP TABLE IF EXISTS data.container_type CASCADE;
DROP TABLE IF EXISTS data.ingredient CASCADE;
DROP TABLE IF EXISTS data.image CASCADE;
