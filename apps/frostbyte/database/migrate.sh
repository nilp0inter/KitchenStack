#!/usr/bin/env bash
# Auto-migration script for running inside a Docker container.
# Applies pending migrations, redeploys logic/api schemas, and replays events.
# Used by the db_migrator service on every `docker compose up`.

set -euo pipefail

echo "Running migrations..."
for f in /database/migrations/*.sql; do
    echo "  Applying $(basename "$f")..."
    psql < "$f" 2>&1 || echo "  (already applied)"
done

echo "Deploying logic schema..."
psql < /database/logic.sql

echo "Deploying api schema..."
psql < /database/api.sql

echo "Replaying events..."
psql -c "SELECT frostbyte_logic.replay_all_events();"

echo "Migration complete."
