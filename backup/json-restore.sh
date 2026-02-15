#!/bin/sh
set -e

API_URL="${API_URL:-http://localhost/api/db}"
BACKUP_DIR="${1:-.}"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Error: Backup directory '$BACKUP_DIR' not found"
  exit 1
fi

# Restore in dependency order
TABLES="label_preset image ingredient container_type batch recipe portion batch_ingredient recipe_ingredient"

for table in $TABLES; do
  FILE="$BACKUP_DIR/$table.json"
  if [ ! -f "$FILE" ]; then
    echo "Warning: $FILE not found, skipping"
    continue
  fi

  echo "Restoring $table..."
  curl -sf -X POST "$API_URL/$table" \
    -H "Content-Type: application/json" \
    -H "Prefer: resolution=ignore-duplicates" \
    -d @"$FILE"
done

echo "JSON restore complete"
