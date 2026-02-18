#!/usr/bin/env bash
set -euo pipefail

APP="${1:?Usage: $0 <app> <path/to/events.csv>  (app = frostbyte | labelmaker)}"
CSV_FILE="${2:?Usage: $0 <app> <path/to/events.csv>}"

case "$APP" in
  frostbyte|labelmaker) ;;
  *) echo "Error: unknown app '$APP'"; exit 1 ;;
esac

CONTAINER="${CONTAINER:-kitchen_postgres}"
DB_USER="${DB_USER:-kitchen_user}"
DB_NAME="${DB_NAME:-kitchen_db}"
EVENT_TABLE="${APP}_data.event"
LOGIC_SCHEMA="${APP}_logic"

if [ ! -f "$CSV_FILE" ]; then
  echo "Error: CSV file '$CSV_FILE' not found"
  exit 1
fi

SEQ_NAME="${EVENT_TABLE}_id_seq"

echo "Restoring $APP events from $CSV_FILE into $EVENT_TABLE..."

# Disable trigger, truncate, load CSV, reset sequence, enable trigger
{
  echo "BEGIN;"
  echo "ALTER TABLE ${EVENT_TABLE} DISABLE TRIGGER event_handler;"
  echo "TRUNCATE ${EVENT_TABLE} CASCADE;"
  echo "COPY ${EVENT_TABLE} (id, type, payload, created_at) FROM stdin WITH CSV HEADER;"
  cat "$CSV_FILE"
  echo "\."
  echo "SELECT setval('${SEQ_NAME}', COALESCE((SELECT MAX(id) FROM ${EVENT_TABLE}), 1));"
  echo "ALTER TABLE ${EVENT_TABLE} ENABLE TRIGGER event_handler;"
  echo "COMMIT;"
} | docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1

echo "Replaying $APP events to rebuild projections..."
docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" \
  -c "SELECT ${LOGIC_SCHEMA}.replay_all_events();"

echo "$APP restore complete."
