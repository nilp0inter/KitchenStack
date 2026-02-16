# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Production Environment

FrostByte runs on a Raspberry Pi Zero 2W (aarch64):
- **Hostname**: `KitchenLabelPrinter.local`
- **IP**: `10.40.8.32`
- **User**: `nil`
- **Repo path**: `~/FrostByte`
- **OS**: Debian 13 (trixie)
- **Systemd service**: `frostbyte.service` (starts on boot)

```bash
# Service management
sudo systemctl status frostbyte
sudo systemctl restart frostbyte
sudo systemctl stop frostbyte
```

## Build and Run Commands

```bash
# Start all services (full stack, runs in background)
docker compose up --build -d

# Rebuild from scratch (clears database)
docker compose down -v && docker compose up --build -d

# Check Elm compilation status (after making client changes)
docker compose logs client_builder

# View logs for a specific service
docker compose logs -f [service_name]  # postgres, postgrest, printer_service, caddy, client_builder

# Stop all services
docker compose down
```

**Testing changes (rebuild mode):**
1. Make changes to Elm files in `client/src/`
2. Run `docker compose up --build -d` to rebuild
3. Check `docker compose logs client_builder` for compilation errors
4. If successful, test at http://localhost/

### Development Mode with Hot Reloading

For faster iteration, use the dev overlay which runs Vite's dev server with hot module replacement (HMR):

```bash
# Start dev mode (Vite HMR - no rebuild needed for changes)
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Watch Vite dev server logs
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f client_dev

# Stop dev mode
docker compose -f docker-compose.yml -f docker-compose.dev.yml down
```

**How it works:**
- `client_dev` service runs Vite dev server on port 5173
- Caddy proxies non-API requests to Vite (instead of serving static files)
- Source code is mounted, so edits trigger automatic browser refresh
- API routing (`/api/db/*`, `/api/printer/*`) works identically to production

**Request flow (dev mode):**
```
Browser :80 → Caddy → client_dev:5173 (Vite HMR)
Browser :80 → Caddy → postgrest:3000 (/api/db/*)
Browser :80 → Caddy → printer_service:8000 (/api/printer/*)
```

**Key files:**
- `docker-compose.dev.yml` - Dev overlay (adds `client_dev` service, swaps Caddyfile)
- `gateway/Caddyfile.dev` - Dev Caddyfile (proxies to Vite instead of static files)

**Available routes to test:**
- http://localhost/ - Menu (visual card grid of what's in the freezer)
- http://localhost/inventory - Inventory (batch table with servings)
- http://localhost/new - Create new batch (with recipe search)
- http://localhost/batch/{uuid} - Batch detail
- http://localhost/item/{uuid} - Portion detail (QR scan target)
- http://localhost/history - Freezer history
- http://localhost/recipes - Recipe management (reusable batch templates)
- http://localhost/ingredients - Ingredient management
- http://localhost/containers - Container type management
- http://localhost/labels - Label designer (preset management)

## Installing Elm Packages

**IMPORTANT:** Do not manually edit `client/elm.json` to add dependencies. Elm requires proper dependency resolution which only `elm install` can perform correctly.

To install a new Elm package, run from the `client/` directory:

```bash
# Install a package (auto-confirms the prompt)
docker run --rm -v "$(pwd)":/app -w /app node:20-alpine sh -c "npm install -g elm && echo y | elm install <package-name>"

# Example: install elm-charts
docker run --rm -v "$(pwd)":/app -w /app node:20-alpine sh -c "npm install -g elm && echo y | elm install terezka/elm-charts"
```

To verify compilation after installing:

```bash
docker run --rm -v "$(pwd)":/app -w /app node:20-alpine sh -c "npm install -g elm && elm make src/Main.elm --output=/dev/null"
```

If you encounter dependency errors after manual elm.json edits:
1. Restore elm.json to its previous valid state
2. Clear elm-stuff: `docker run --rm -v "$(pwd)":/app -w /app node:20-alpine rm -rf elm-stuff`
3. Use `elm install` to add packages properly

## Architecture Overview

FrostByte is an **append-only** home freezer management system. Each physical food portion has its own UUID and printed QR label. Portions transition between states (FROZEN → CONSUMED) but are never deleted.

### Data Flow

1. **Batch Creation**: User creates a batch via Elm UI → `POST /api/db/rpc/create_batch` → PostgreSQL function creates batch + N portions → Returns `{batch_id, portion_ids[]}` → Client renders SVG labels → converts to PNG via JS ports → sends to printer service
2. **QR Scan Consumption**: User scans QR code → `/item/{portion_uuid}` route → Fetches from `portion_detail` view → User confirms → `PATCH /api/db/portion` sets status=CONSUMED
3. **Inventory**: Fetches `batch_summary` view (batches grouped with frozen/consumed counts)

### Label Rendering Architecture

Labels are rendered client-side in Elm with dynamic text fitting and converted to PNG for printing:

```
Text Measure Request → JS Canvas measureText() → Computed Data (font size, wrapped lines)
    → Elm SVG with fitted text → JS Canvas → PNG (base64) → POST to printer service → brother_ql
```

**Text fitting flow:**
1. Elm requests text measurement via `requestTextMeasure` port
2. JavaScript measures text width using Canvas API, shrinks title font until it fits (down to `titleMinFontSize`)
3. If title still doesn't fit at min font, wraps into multiple lines
4. Ingredients are wrapped based on `ingredientsMaxChars`
5. Results returned via `receiveTextMeasureResult` port as `ComputedLabelData`
6. `Label.viewLabelWithComputed` renders SVG with computed font sizes and line breaks
7. SVG converted to PNG via `requestSvgToPng` port

**Key components:**
- `Label.elm` - SVG label rendering with `viewLabelWithComputed` for text-fitted labels
- `Ports.elm` - Port definitions for text measurement, SVG→PNG conversion, and file selection
- `main.js` - JavaScript handlers for text measurement (Canvas measureText), PNG conversion, and file selection (with validation)
- `label_preset` table - Stores named label configurations (dimensions, fonts, min font sizes)

**Key types:**
- `LabelSettings` - Label dimensions, fonts, visibility toggles (from preset)
- `LabelData` - Content to render (name, ingredients, dates, QR URL)
- `ComputedLabelData` - JS-measured values: `titleFontSize`, `titleLines`, `ingredientLines`

**Label presets** are stored in PostgreSQL and allow users to configure different label sizes (62mm, 29mm, 12mm tape). The Label Designer page (`/labels`) provides a live preview with editable sample text and real-time text fitting.

### Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Caddy (:80)                                                      │
│   /          → Elm SPA (static files from client_dist volume)    │
│   /api/db/*  → PostgREST (:3000) → PostgreSQL                    │
│   /api/printer/* → Printer Service (:8000)                       │
└─────────────────────────────────────────────────────────────────┘
│ GoBackup (:2703) → Web UI for backup management                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Database Objects

- **`image` table**: Stores images as BYTEA with helper functions `store_image_base64()` and `get_image_base64()`
- **`create_batch` function**: RPC endpoint that atomically creates a batch with N portions, auto-calculates expiry from ingredient.expire_days, optionally stores image
- **`save_recipe` function**: RPC endpoint that atomically creates/updates a recipe with ingredients, auto-creates unknown ingredients, optionally stores image
- **`batch_summary` view**: Aggregates portions by batch for dashboard display, includes image
- **`portion_detail` view**: Joins portion with batch info for QR scan page
- **`freezer_history` view**: Running totals of frozen portions over time for chart
- **`recipe_summary` view**: Recipes with aggregated ingredient names for listing, includes image
- **`label_preset` table**: Named label configurations with dimensions, font sizes, and styling

### Elm Client Structure

Modular SPA using `Browser.application` with page-based architecture:

```
client/src/
├── Main.elm              # Entry point, routing, global state, port subscriptions
├── Route.elm             # Route type and URL parsing
├── Types.elm             # Shared domain types (BatchSummary, PortionDetail, LabelPreset, etc.)
├── Api.elm               # HTTP functions (parameterized msg constructors)
├── Api/
│   ├── Decoders.elm      # JSON decoders (uses andMap helper for >8 fields)
│   └── Encoders.elm      # JSON encoders for POST/PATCH bodies
├── Components.elm        # Shared UI (header, notification, modal, loading)
├── Label.elm             # SVG label rendering with QR codes
├── Ports.elm             # Port definitions for SVG→PNG conversion
└── Page/
    ├── Menu.elm          # Visual menu grid (default landing page)
    ├── Inventory.elm     # Batch list with servings calculation (/inventory)
    ├── NewBatch.elm      # Batch creation form with printing and recipe search
    ├── ItemDetail.elm    # Portion consumption (QR scan target)
    ├── BatchDetail.elm   # Batch detail with portion list, reprinting
    ├── History.elm       # Freezer history chart and table
    ├── Recipes.elm       # Recipe CRUD (reusable batch templates)
    ├── Ingredients.elm   # Ingredient CRUD with expiry days
    ├── ContainerTypes.elm# Container type CRUD
    ├── LabelDesigner.elm # Label preset management with live preview
    └── NotFound.elm      # 404 page
```

**Architecture pattern:**
- Each page module exposes: `Model`, `Msg`, `OutMsg`, `init`, `update`, `view`
- Pages communicate up via `OutMsg` (navigation, notifications, refresh requests, port requests)
- Main.elm wraps page messages: `InventoryMsg Page.Inventory.Msg`
- Shared data (ingredients, containerTypes, batches, recipes, labelPresets) lives in Main and passed to pages
- Port subscriptions handled in Main.elm, results forwarded to active page

**OutMsg pattern for data refresh:**
When a page modifies shared data (create/update/delete), it must emit a compound `OutMsg` that both shows a notification AND triggers Main.elm to refresh the shared state. This ensures other pages see updated data without requiring a browser refresh.

- `RefreshIngredientsWithNotification Notification` - After ingredient save/delete
- `RefreshContainerTypesWithNotification Notification` - After container type save/delete
- `RefreshRecipesWithNotification Notification` - After recipe save/delete
- `RefreshPresetsWithNotification Notification` - After label preset save/delete

Main.elm handlers for these OutMsgs call the appropriate `Api.fetch*` function to update the shared state.

**Data loading and page initialization:**
On app load, Main.elm fetches all shared data (ingredients, containerTypes, batches, recipes, labelPresets) in parallel. Each is tracked with `RemoteData` type (`Loading` -> `Loaded` or `Failed`). The `maybeInitPage` function gates page initialization until all data has settled (loaded or failed). This prevents race conditions where pages initialize with empty data.

When pages receive fresh data from API responses (e.g., `GotBatches` in BatchDetail), they must recalculate any derived state (like `selectedPreset`) based on the new data, not just store it.

**Routes:** `/` (Menu), `/inventory` (Inventory), `/new` (NewBatch), `/item/{uuid}` (ItemDetail), `/batch/{uuid}` (BatchDetail), `/history` (History), `/recipes` (Recipes), `/ingredients` (Ingredients), `/containers` (ContainerTypes), `/labels` (LabelDesigner)

**Styling:** Tailwind CSS with custom "frost" color palette

### Printer Service

Python FastAPI service that receives pre-rendered PNG labels and prints them via brother_ql. Runs in dry-run mode by default (saves PNG to volume instead of printing).

**Key features:**
- Accepts base64-encoded PNG images
- Direct printing via brother_ql library (no PIL/image generation)
- Configurable via environment variables: `DRY_RUN`, `PRINTER_MODEL`, `PRINTER_TAPE`

**USB access requirements (production):**
- Container mounts `/dev/bus/usb` (not all of `/dev`) with `device_cgroup_rules: ['c 189:* rwm']` for USB device access — no `privileged: true` needed
- `/run/udev:/run/udev:ro` is mounted so `libusb` can discover USB devices after re-enumeration (e.g., printer standby/wake)
- Printing runs in a subprocess (`multiprocessing`) so each job gets fresh USB state — the long-running uvicorn process caches stale `libusb` handles after the printer re-enumerates from standby/wake, causing "Device not found" errors

## API Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/db/rpc/create_batch` | POST | Create batch with N portions |
| `/api/db/rpc/save_recipe` | POST | Create or update recipe with ingredients |
| `/api/db/batch_summary?frozen_count=gt.0` | GET | Inventory data |
| `/api/db/portion_detail?portion_id=eq.{uuid}` | GET | QR scan page data |
| `/api/db/portion?id=eq.{uuid}` | PATCH | Consume portion (set status, consumed_at) |
| `/api/db/portion?batch_id=eq.{uuid}` | GET | Get portions for a batch |
| `/api/db/freezer_history` | GET | Chart data |
| `/api/db/ingredient` | GET/POST | List or create ingredients |
| `/api/db/ingredient?name=eq.{name}` | PATCH/DELETE | Update or delete ingredient |
| `/api/db/recipe_summary` | GET | List recipes with ingredients |
| `/api/db/recipe?name=eq.{name}` | DELETE | Delete recipe |
| `/api/db/container_type` | GET/POST | List or create container types |
| `/api/db/container_type?name=eq.{name}` | PATCH/DELETE | Update or delete container type |
| `/api/db/label_preset` | GET/POST | List or create label presets |
| `/api/db/label_preset?name=eq.{name}` | PATCH/DELETE | Update or delete label preset |
| `/api/printer/print` | POST | Print PNG label (body: `{image_data: "base64..."}`) |
| `/api/printer/health` | GET | Printer service health check |

## Adding a New Page

1. Create `client/src/Page/NewPage.elm` with:
   ```elm
   module Page.NewPage exposing (Model, Msg, OutMsg(..), init, update, view)

   type alias Model = { ... }
   type Msg = ...
   type OutMsg = NoOp | ShowNotification Notification | ...

   init : ... -> ( Model, Cmd Msg )
   update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
   view : Model -> Html Msg
   ```

2. Add route in `Route.elm`:
   ```elm
   type Route = ... | NewPage
   -- Add to routeParser
   ```

3. Wire up in `Main.elm`:
   - Add `NewPagePage Page.NewPage.Model` to `Page` type
   - Add `NewPageMsg Page.NewPage.Msg` to `Msg` type
   - Add case in `initPage` to initialize the page
   - Add case in `update` to handle `NewPageMsg`
   - Add `handleNewPageOutMsg` function
   - Add case in `viewPage` to render the page

4. Add nav link in `Components.elm` `viewHeader`

## Working with Ports

For features requiring JavaScript interop (like text measurement and SVG→PNG conversion):

1. Define ports in `Ports.elm`:
   ```elm
   port requestSomething : SomeRequest -> Cmd msg
   port receiveSomethingResult : (SomeResult -> msg) -> Sub msg
   ```

2. Add JavaScript handlers in `client/src/main.js`:
   ```javascript
   app.ports.requestSomething.subscribe(function(request) {
       // Process and send result back
       app.ports.receiveSomethingResult.send(result);
   });
   ```

3. Subscribe in `Main.elm` subscriptions function
4. Forward results to the appropriate page via the update function

**Existing ports:**
- `requestTextMeasure` / `receiveTextMeasureResult` - Measure text width and compute font sizes/line wrapping
- `requestSvgToPng` / `receivePngResult` - Convert rendered SVG label to PNG for printing
- `requestFileSelect` / `receiveFileSelectResult` - Open file picker for image uploads

## Image Handling

Recipes and batches support optional images stored as binary data in PostgreSQL.

### Database Design

Images use a normalized design with a separate `image` table:

```sql
-- Image storage table
CREATE TABLE image (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    image_data BYTEA NOT NULL,  -- Binary storage
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Helper functions for base64 transport
CREATE FUNCTION store_image_base64(base64_data TEXT) RETURNS UUID  -- Store and get UUID
CREATE FUNCTION get_image_base64(image_id UUID) RETURNS TEXT       -- Retrieve as base64
```

Foreign keys link images to recipes and batches:
- `recipe.image_id` → `image(id)` (nullable, ON DELETE SET NULL)
- `batch.image_id` → `image(id)` (nullable, ON DELETE SET NULL)

### Image Flow

**Upload flow (Elm → JS → Elm → API → PostgreSQL):**
1. User clicks image selector → Elm sends `requestFileSelect` port
2. JavaScript opens file picker, validates file (500KB max, PNG/JPEG/WebP)
3. JS reads file as base64, sends via `receiveFileSelectResult` port
4. Elm stores base64 in form state (`form.image : Maybe String`)
5. On save, base64 sent as `p_image_data` parameter to RPC function
6. PostgreSQL function calls `store_image_base64()` to create image record
7. Image UUID stored in recipe/batch `image_id` column

**Retrieval flow:**
- `batch_summary` and `recipe_summary` views JOIN with `image` table
- Images returned as base64 via `encode(image_data, 'base64') AS image`
- Elm displays using `img [ src ("data:image/png;base64," ++ imageData) ]`

### Recipe → Batch Image Inheritance

When creating a batch from a recipe:
1. User searches for recipe in NewBatch page
2. Recipe suggestions dropdown shows thumbnails (if available)
3. User selects recipe → `form.image` populated from `recipe.image`
4. Image preview shown in form with change/remove buttons
5. User can keep inherited image, upload different one, or remove entirely
6. On save, new image record created if changed, or same `image_id` reused

### Adding Image Support to New Entities

To add images to a new entity:

1. **Database**: Add `image_id UUID NULL REFERENCES image(id) ON DELETE SET NULL` to table
2. **RPC function**: Add `p_image_data TEXT DEFAULT NULL` parameter, call `store_image_base64()` if provided
3. **View**: LEFT JOIN with `image` table, include `encode(i.image_data, 'base64') AS image`
4. **Elm Types**: Add `image : Maybe String` to both the entity type and form type
5. **Decoders**: Add `|> andMap (Decode.field "image" (Decode.nullable Decode.string))`
6. **Encoders**: Add image field encoding with `p_image_data` key
7. **Page Types**: Add `SelectImage`, `GotImageResult Ports.FileSelectResult`, `RemoveImage` to Msg
8. **Page Types**: Add `RequestFileSelect Ports.FileSelectRequest` to OutMsg
9. **Page update**: Handle the three image messages
10. **Page view**: Add `viewImageSelector` component
11. **Main.elm**: Forward `GotFileSelectResult` to page, handle `RequestFileSelect` OutMsg

## Language Notes

- UI is in Spanish (expiry label: "Caduca:", food categories like "Arroz", "Pollo", etc.)

## Build & Deployment Architecture

### Image Build Pipeline
- **CI (GitHub Actions)**: Builds multi-arch Docker images on push to main
- **Elm compilation**: Always runs on amd64 (output is platform-independent JS)
- **Final image**: Minimal Alpine with static files (~5MB), supports amd64 and arm64

### Development Workflow
Two modes available:

**Rebuild mode** (`docker compose up --build -d`):
- Builds Elm on each `docker compose up --build`
- Best for testing production-like builds

**Hot reload mode** (`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d`):
- Runs Vite dev server with HMR
- Instant browser refresh on file changes (no rebuild needed)
- Best for active development

Both modes use named volume `client_node_modules` for faster dependency handling.

### Production Workflow (Raspberry Pi)
- Pi pulls pre-built image from `ghcr.io/nilp0inter/frostbyte-client:latest`
- `docker-compose.prod.yml` overrides command to `cp -r /dist/* /output/`
- **Pi never runs Elm** - just copies pre-built static files to volume
- Caddy serves static files from shared volume

### Key Files
- `client/Dockerfile` - Multi-stage: builder (Node+Elm) -> final (Alpine+static)
- `docker-compose.yml` - Base config (uses `target: builder`)
- `docker-compose.dev.yml` - Dev overlay (Vite HMR, hot reloading)
- `docker-compose.prod.yml` - Prod overrides (uses pre-built image)
- `gateway/Caddyfile` - Production Caddyfile (serves static files)
- `gateway/Caddyfile.dev` - Dev Caddyfile (proxies to Vite)
- `.github/workflows/build-client.yml` - CI pipeline

### RemoteData Pattern for Loading State

The frontend uses a `RemoteData` union type to track async data loading:

```elm
type RemoteData a
    = NotAsked    -- Initial state before any request
    | Loading     -- Request is in progress
    | Loaded a    -- Data successfully loaded
    | Failed String  -- Request failed with error message
```

This pattern makes impossible states unrepresentable:
- No need for separate `data` and `dataLoaded` fields
- Clear distinction between "loaded empty" and "failed to load"
- Error messages stored with the failed state
- Pattern matching enforces handling all cases

## Secrets Management

FrostByte uses [SOPS](https://github.com/getsops/sops) with GPG (dev) and age (Pi) for secrets management. Encrypted secrets are stored in `.env.prod` and committed to version control.

### Prerequisites
- SOPS installed on dev machine and Raspberry Pi
- GPG key (YubiKey on dev), age key on Pi (`~/.config/sops/age/keys.txt`)

### Edit Secrets
```bash
sops .env.prod
```

### Production Deployment (on Raspberry Pi)
```bash
cd ~/FrostByte
sops -d .env.prod > /tmp/.env.decrypted && \
  docker compose --env-file /tmp/.env.decrypted \
    -f docker-compose.yml \
    -f docker-compose.secrets.yml \
    -f docker-compose.prod.yml \
    up -d && \
  rm /tmp/.env.decrypted
```

Note: Process substitution (`<(sops -d ...)`) doesn't work reliably with docker compose.

### Adding New Secrets
1. Edit secrets: `sops .env.prod`
2. Add new variable: `FROSTBYTE_NEW_SECRET=value`
3. Update `docker-compose.secrets.yml` to use `${FROSTBYTE_NEW_SECRET}`
4. Commit both files

### Current Secrets
- `FROSTBYTE_POSTGRES_PASSWORD` - PostgreSQL password
- `FROSTBYTE_B2_BUCKET` - Backblaze B2 bucket name
- `FROSTBYTE_B2_REGION` - B2 region (e.g., `us-west-002`)
- `FROSTBYTE_B2_ENDPOINT` - B2 S3-compatible endpoint (e.g., `https://s3.us-west-002.backblazeb2.com`)
- `FROSTBYTE_B2_KEY_ID` - B2 application key ID
- `FROSTBYTE_B2_APP_KEY` - B2 application key
- `FROSTBYTE_HEALTHCHECKS_URL` - Healthchecks.io ping URL

## Database Backups

FrostByte uses [GoBackup](https://gobackup.github.io/) for automated PostgreSQL backups to Backblaze B2 with Healthchecks.io monitoring.

### Configuration
- **Schedule**: Daily at 3:00 AM
- **Retention**: 30 days (managed by B2 lifecycle rules)
- **Storage**: Backblaze B2 (S3-compatible)
- **Monitoring**: Healthchecks.io ping on success/failure

### Key Files
- `backup/gobackup.yml` - GoBackup configuration (uses env vars for secrets)
- `docker-compose.secrets.yml` - Maps SOPS secrets to gobackup environment

### Web UI
Access backup status at: `http://KitchenLabelPrinter.local:2703/`

### Manual Backup
```bash
docker exec frostbyte_gobackup gobackup perform frostbyte_db
```

### Setting Up B2 Bucket
1. Log into Backblaze B2 console
2. Create bucket (e.g., `frostbyte-backups`)
3. Create Application Key with read/write access to the bucket
4. Note the region and construct endpoint: `https://s3.{region}.backblazeb2.com`

### Setting Up Healthchecks.io
1. Create account at healthchecks.io
2. Create new check with 24-hour period and grace period
3. Copy the ping URL (format: `https://healthchecks.io/ping/uuid`)

### JSON Backup via PostgREST API

In addition to PostgreSQL dumps, GoBackup also exports all tables as JSON files via the PostgREST API. This provides a human-readable backup that can be used for partial restores or data inspection.

**How it works:**
- `backup/json-backup.sh` runs as a `before_script` in GoBackup
- Fetches all 9 tables via `curl` to PostgREST API
- Saves JSON files to `/data/json/` volume
- JSON files are archived alongside the SQL dump

**Tables backed up (in dependency order):**
1. `label_preset`, `image`, `ingredient`, `container_type` (no dependencies)
2. `batch`, `recipe` (depend on level 1)
3. `portion`, `batch_ingredient`, `recipe_ingredient` (depend on level 2)

**Key files:**
- `backup/json-backup.sh` - Backup script (runs inside gobackup container)
- `backup/json-restore.sh` - Restore script (runs from dev machine or Pi)
- `backup/Dockerfile` - Custom gobackup image with scripts baked in

**Limitation:** GoBackup does not fail if `before_script` fails - it logs the error but continues. The SQL dump is the authoritative backup; JSON is supplementary.

### Restoring from JSON Backup

To restore data from a JSON backup (e.g., after wiping the database):

```bash
# 1. Download and extract the backup archive from B2
# 2. Locate the JSON files in data/json/

# 3. Restore to the Pi (from dev machine)
API_URL=http://10.40.8.32/api/db ./backup/json-restore.sh /path/to/backup/data/json

# Or restore to local dev environment
API_URL=http://localhost/api/db ./backup/json-restore.sh /path/to/backup/data/json
```

The restore script POSTs each table in dependency order with `Prefer: resolution=ignore-duplicates` header for idempotency.
