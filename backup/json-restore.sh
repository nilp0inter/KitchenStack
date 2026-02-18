#!/bin/sh
set -e

API_URL="${API_URL:-http://localhost/api/db}"
BACKUP_DIR="${1:-.}"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Error: Backup directory '$BACKUP_DIR' not found"
  exit 1
fi

# Restore events only — projections rebuild via trigger on INSERT
FILE="$BACKUP_DIR/event.json"
if [ ! -f "$FILE" ]; then
  echo "Error: $FILE not found"
  exit 1
fi

echo "Restoring events..."
curl -sf -X POST "$API_URL/event" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=ignore-duplicates" \
  -d @"$FILE"

echo "JSON restore complete"
