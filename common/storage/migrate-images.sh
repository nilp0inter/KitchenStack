#!/bin/sh
# migrate-images.sh — Migrate base64 image data from event payloads to VersityGW S3 storage
#
# This script:
# 1. Queries events with image_data in their payload
# 2. Decodes base64 data and uploads to VersityGW via curl
# 3. Updates event payloads: replaces image_data with image_url
#
# Run inside the docker network with psql + curl available:
#   docker run --rm --network kitchenstack_kitchen_network \
#     -e PGHOST=postgres -e PGUSER=kitchen_user \
#     -e PGPASSWORD=kitchen_password -e PGDATABASE=kitchen_db \
#     -v ./common/storage/migrate-images.sh:/migrate.sh:ro \
#     alpine:latest sh -c "apk add --no-cache curl postgresql-client && sh /migrate.sh"

set -eu

STORAGE_URL="${STORAGE_URL:-http://storage:7070}"
BUCKET="${BUCKET:-frostbyte-assets}"
ASSETS_PATH="${ASSETS_PATH:-/api/assets}"

echo "=== FrostByte Image Migration ==="
echo "Storage: ${STORAGE_URL}/${BUCKET}"
echo ""

# Get event IDs with image_data
EVENT_IDS=$(psql -t -A -c "
  SELECT id
  FROM frostbyte_data.event
  WHERE payload->>'image_data' IS NOT NULL
    AND payload->>'image_data' <> ''
  ORDER BY id;
")

if [ -z "$EVENT_IDS" ]; then
  echo "No events with image_data found. Nothing to migrate."
  exit 0
fi

COUNT=$(echo "$EVENT_IDS" | wc -l)
echo "Found ${COUNT} events with embedded image data."
echo ""

MIGRATED=0
FAILED=0

for event_id in $EVENT_IDS; do
  # Generate a UUID for the image
  image_uuid=$(cat /proc/sys/kernel/random/uuid)

  echo -n "Event ${event_id}: uploading as ${image_uuid}... "

  # Extract base64 from DB, decode, and upload via curl in one pipeline
  if psql -t -A -c "SELECT payload->>'image_data' FROM frostbyte_data.event WHERE id = ${event_id};" \
     | base64 -d \
     | curl -s -f -X PUT -H "Content-Type: image/png" --data-binary @- \
         "${STORAGE_URL}/${BUCKET}/${image_uuid}"; then

    # Update event payload: remove image_data, add image_url
    image_url="${ASSETS_PATH}/${image_uuid}"
    psql -q -c "
      UPDATE frostbyte_data.event
      SET payload = (payload - 'image_data') || jsonb_build_object('image_url', '${image_url}')
      WHERE id = ${event_id};
    "
    echo " OK (${image_url})"
    MIGRATED=$((MIGRATED + 1))
  else
    echo " FAILED to upload"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "=== Migration Complete ==="
echo "Migrated: ${MIGRATED}"
echo "Failed: ${FAILED}"

if [ "$MIGRATED" -gt 0 ]; then
  echo ""
  echo "Replaying events to rebuild projections..."
  psql -c "SELECT frostbyte_logic.replay_all_events();"
  echo "Replay complete."
fi
