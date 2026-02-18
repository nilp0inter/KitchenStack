#!/bin/sh
set -e

EVENT_TABLE="${EVENT_TABLE:-data.event}"
OUTPUT_DIR="/data/json"

mkdir -p "$OUTPUT_DIR"

echo "Backing up ${EVENT_TABLE} as CSV..."
psql -c "COPY (SELECT id, type, payload, created_at FROM ${EVENT_TABLE} ORDER BY id) TO STDOUT WITH CSV HEADER" \
  > "$OUTPUT_DIR/events.csv"

ROW_COUNT=$(tail -n +2 "$OUTPUT_DIR/events.csv" | wc -l)
echo "CSV backup complete: $OUTPUT_DIR/events.csv ($ROW_COUNT events)"
