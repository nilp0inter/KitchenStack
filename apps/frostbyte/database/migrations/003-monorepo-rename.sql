-- Migration 003: Rename schemas for monorepo (multi-app isolation)
-- Renames: data -> frostbyte_data
-- Logic and API schemas are DROP+CREATE (handled by logic.sql / api.sql)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.schemata
        WHERE schema_name = 'frostbyte_data'
    ) THEN
        -- Already migrated: clean up stale schemas from 001 re-run
        DROP SCHEMA IF EXISTS data CASCADE;
        DROP SCHEMA IF EXISTS logic CASCADE;
        DROP SCHEMA IF EXISTS api CASCADE;
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'data' AND table_name = 'event'
    ) THEN
        -- First run on existing DB: rename data -> frostbyte_data
        DROP SCHEMA IF EXISTS logic CASCADE;
        DROP SCHEMA IF EXISTS api CASCADE;
        ALTER SCHEMA data RENAME TO frostbyte_data;
    ELSE
        -- Clean install: nothing to do (001 created empty schemas, drop them)
        DROP SCHEMA IF EXISTS data CASCADE;
        DROP SCHEMA IF EXISTS logic CASCADE;
        DROP SCHEMA IF EXISTS api CASCADE;
    END IF;
END;
$$;
