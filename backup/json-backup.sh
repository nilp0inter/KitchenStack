#!/bin/sh
set -e

API_URL="${API_URL:-http://caddy/api/db}"
OUTPUT_DIR="/data/json"

mkdir -p "$OUTPUT_DIR"

# Event store (primary backup — all state can be rebuilt from events)
TABLES="event"

# Projection tables (supplementary — for quick inspection and partial restores)
TABLES="$TABLES label_preset image ingredient container_type batch recipe portion batch_ingredient recipe_ingredient"

for table in $TABLES; do
  echo "Backing up $table..."
  curl -sf "$API_URL/$table" > "$OUTPUT_DIR/$table.json"
done

echo "JSON backup complete: $OUTPUT_DIR"
