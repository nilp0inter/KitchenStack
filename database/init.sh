#!/usr/bin/env bash
set -e

echo "Running migrations..."
for f in /database/migrations/*.sql; do
    echo "  Applying $(basename "$f")..."
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$f"
done

echo "Deploying logic schema..."
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" < /database/logic.sql

echo "Deploying api schema..."
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" < /database/api.sql

echo "Loading seed data..."
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" < /database/seed.sql

echo "Database initialization complete."
