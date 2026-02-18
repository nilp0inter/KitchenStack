#!/usr/bin/env bash
# Deploy schema changes to a running LabelMaker database.
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

CONTAINER="${CONTAINER:-kitchen_postgres}"
DB_USER="${DB_USER:-kitchen_user}"
DB_NAME="${DB_NAME:-kitchen_db}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Running LabelMaker migrations..."
for f in "$SCRIPT_DIR/migrations/"*.sql; do
    echo "  Applying $(basename "$f")..."
    docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < "$f" 2>&1 || echo "  (already applied, skipping)"
done

echo "Deploying LabelMaker logic schema..."
docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/logic.sql"

echo "Deploying LabelMaker api schema..."
docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/api.sql"

echo "Replaying LabelMaker events..."
docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT labelmaker_logic.replay_all_events();"

echo "LabelMaker deploy complete."
