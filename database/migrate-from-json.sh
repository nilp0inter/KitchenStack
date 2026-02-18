#!/usr/bin/env python3
"""
Converts a JSON backup from the old (pre-event-sourcing) schema into
INSERT INTO data.event statements.

Usage:
    ./migrate-from-json.sh /path/to/backup/data/json > events.sql
    # Then load:
    docker exec -i frostbyte_postgres psql -U frostbyte_user -d frostbyte_db < events.sql
"""

import base64
import json
import sys
import os
from datetime import datetime


def sql_escape(s):
    """Escape single quotes for SQL string literals."""
    return s.replace("'", "''")


def emit_event(event_type, payload, created_at=None):
    """Print an INSERT INTO data.event statement."""
    payload_json = sql_escape(json.dumps(payload, ensure_ascii=False))
    if created_at:
        created_at_escaped = sql_escape(created_at)
        print(f"INSERT INTO data.event (type, payload, created_at) VALUES ('{event_type}', '{payload_json}', '{created_at_escaped}');")
    else:
        print(f"INSERT INTO data.event (type, payload) VALUES ('{event_type}', '{payload_json}');")


def load_json(backup_dir, filename):
    """Load a JSON file from the backup directory, or return empty list."""
    path = os.path.join(backup_dir, filename)
    if not os.path.exists(path):
        print(f"-- Warning: {filename} not found, skipping", file=sys.stderr)
        return []
    with open(path, "r") as f:
        return json.load(f)


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} /path/to/json/backup/dir", file=sys.stderr)
        sys.exit(1)

    backup_dir = sys.argv[1]
    if not os.path.isdir(backup_dir):
        print(f"Error: '{backup_dir}' is not a directory", file=sys.stderr)
        sys.exit(1)

    print(f"-- Migration from JSON backup: {backup_dir}")
    print(f"-- Generated: {datetime.now().isoformat()}")
    print()

    # Load all data upfront
    ingredients = load_json(backup_dir, "ingredient.json")
    container_types = load_json(backup_dir, "container_type.json")
    label_presets = load_json(backup_dir, "label_preset.json")
    images = load_json(backup_dir, "image.json")
    recipes = load_json(backup_dir, "recipe.json")
    recipe_ingredients = load_json(backup_dir, "recipe_ingredient.json")
    batches = load_json(backup_dir, "batch.json")
    batch_ingredients = load_json(backup_dir, "batch_ingredient.json")
    portions = load_json(backup_dir, "portion.json")

    # Index images by id for fast lookup, converting hex BYTEA to base64
    def hex_to_base64(hex_data):
        """Convert PostgreSQL hex BYTEA (\\x...) to base64."""
        if not hex_data:
            return ""
        if hex_data.startswith("\\x"):
            hex_data = hex_data[2:]
        try:
            return base64.b64encode(bytes.fromhex(hex_data)).decode("ascii")
        except ValueError:
            # Already base64 or unknown format, return as-is
            return hex_data

    image_by_id = {img["id"]: hex_to_base64(img.get("image_data", "")) for img in images}

    # 1. Ingredients
    if ingredients:
        print("-- Ingredients")
        for ing in ingredients:
            emit_event("ingredient_created", {
                "name": ing["name"],
                "expire_days": ing.get("expire_days"),
                "best_before_days": ing.get("best_before_days"),
            })
        print()

    # 2. Container types
    if container_types:
        print("-- Container types")
        for ct in container_types:
            emit_event("container_type_created", {
                "name": ct["name"],
                "servings_per_unit": ct["servings_per_unit"],
            })
        print()

    # 3. Label presets
    if label_presets:
        print("-- Label presets")
        for lp in label_presets:
            payload = {k: v for k, v in lp.items() if k != "created_at"}
            emit_event("label_preset_created", payload)
        print()

    # 4. Recipes
    if recipes:
        print("-- Recipes")
        for recipe in recipes:
            recipe_name = recipe["name"]
            ing_names = [
                ri["ingredient_name"]
                for ri in recipe_ingredients
                if ri["recipe_name"] == recipe_name
            ]
            image_id = recipe.get("image_id")
            image_data = image_by_id.get(image_id, "") if image_id else ""

            emit_event("recipe_saved", {
                "name": recipe_name,
                "ingredient_names": ing_names,
                "default_portions": recipe.get("default_portions", 1),
                "default_container_id": recipe.get("default_container_id"),
                "default_label_preset": recipe.get("default_label_preset"),
                "details": recipe.get("details"),
                "image_data": image_data if image_data else None,
            })
        print()

    # 5. Batches
    if batches:
        print("-- Batches")
        for batch in batches:
            batch_id = batch["id"]
            ing_names = [
                bi["ingredient_name"]
                for bi in batch_ingredients
                if bi["batch_id"] == batch_id
            ]
            batch_portions = [p for p in portions if p["batch_id"] == batch_id]
            portion_ids = [p["id"] for p in batch_portions]
            expiry_date = batch_portions[0]["expiry_date"] if batch_portions else ""

            image_id = batch.get("image_id")
            image_data = image_by_id.get(image_id, "") if image_id else ""

            # Use portion created_at (freeze date) not batch created_at (DB timestamp)
            freeze_date = batch_portions[0]["created_at"] if batch_portions else batch["created_at"]
            created_at = batch["created_at"]

            emit_event("batch_created", {
                "batch_id": batch_id,
                "portion_ids": portion_ids,
                "name": batch["name"],
                "ingredient_names": ing_names,
                "container_id": batch["container_id"],
                "created_at": freeze_date,
                "expiry_date": expiry_date,
                "best_before_date": batch.get("best_before_date"),
                "label_preset": batch.get("label_preset"),
                "details": batch.get("details"),
                "image_data": image_data if image_data else None,
            }, created_at=created_at)
        print()

    # 6. Consumed portions
    consumed = [p for p in portions if p.get("status") == "CONSUMED"]
    if consumed:
        print("-- Consumed portions")
        for p in consumed:
            consumed_at = p["consumed_at"]
            emit_event("portion_consumed", {
                "portion_id": p["id"],
                "consumed_at": consumed_at,
            }, created_at=consumed_at)
        print()

    print("-- Migration complete")


if __name__ == "__main__":
    main()
