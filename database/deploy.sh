#!/usr/bin/env bash
# Deploy schema changes to a running FrostByte database.
# Usage: ./deploy.sh
#
# This script:
# 1. Runs any pending migrations
# 2. Drops and recreates the logic schema (projection tables + event handlers)
# 3. Drops and recreates the api schema (views + RPC functions)
# 4. Replays all events to rebuild projection tables
#
# Safe to run on a live system — events are preserved, only projections are rebuilt.

set -euo pipefail

CONTAINER="${CONTAINER:-frostbyte_postgres}"
DB_USER="${DB_USER:-frostbyte_user}"
DB_NAME="${DB_NAME:-frostbyte_db}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Running migrations..."
for f in "$SCRIPT_DIR/migrations/"*.sql; do
    echo "  Applying $(basename "$f")..."
    docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" < "$f"
done

echo "Deploying logic schema..."
docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/logic.sql"

echo "Deploying api schema..."
docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/api.sql"

echo "Replaying events..."
docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT logic.replay_all_events();"

echo "Deploy complete."
