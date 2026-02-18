#!/bin/sh
set -e

OUTPUT_DIR="/data/json"
mkdir -p "$OUTPUT_DIR"

for app in frostbyte labelmaker; do
  TABLE="${app}_data.event"
  OUTPUT="$OUTPUT_DIR/${app}_events.csv"
  echo "Backing up ${TABLE} as CSV..."
  psql -c "COPY (SELECT id, type, payload, created_at FROM ${TABLE} ORDER BY id) TO STDOUT WITH CSV HEADER" > "$OUTPUT"
  ROW_COUNT=$(tail -n +2 "$OUTPUT" | wc -l)
  echo "CSV backup complete: $OUTPUT ($ROW_COUNT events)"
done
