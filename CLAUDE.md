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

**Testing changes:**
1. Make changes to Elm files in `client/src/`
2. Run `docker compose up --build -d` to rebuild
3. Check `docker compose logs client_builder` for compilation errors
4. If successful, test at http://localhost/

**Available routes to test:**
- http://localhost/ - Dashboard (batch list)
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
3. **Dashboard**: Fetches `batch_summary` view (batches grouped with frozen/consumed counts)

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
- `Ports.elm` - Port definitions for text measurement and SVG→PNG conversion
- `main.js` - JavaScript handlers for text measurement (Canvas measureText) and PNG conversion
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
```

### Key Database Objects

- **`create_batch` function**: RPC endpoint that atomically creates a batch with N portions, auto-calculates expiry from ingredient.expire_days
- **`save_recipe` function**: RPC endpoint that atomically creates/updates a recipe with ingredients, auto-creates unknown ingredients
- **`batch_summary` view**: Aggregates portions by batch for dashboard display
- **`portion_detail` view**: Joins portion with batch info for QR scan page
- **`freezer_history` view**: Running totals of frozen portions over time for chart
- **`recipe_summary` view**: Recipes with aggregated ingredient names for listing
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
    ├── Dashboard.elm     # Batch list with servings calculation
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
- Main.elm wraps page messages: `DashboardMsg Page.Dashboard.Msg`
- Shared data (ingredients, containerTypes, batches, recipes, labelPresets) lives in Main and passed to pages
- Port subscriptions handled in Main.elm, results forwarded to active page

**Routes:** `/` (Dashboard), `/new` (NewBatch), `/item/{uuid}` (ItemDetail), `/batch/{uuid}` (BatchDetail), `/history` (History), `/recipes` (Recipes), `/ingredients` (Ingredients), `/containers` (ContainerTypes), `/labels` (LabelDesigner)

**Styling:** Tailwind CSS with custom "frost" color palette

### Printer Service

Python FastAPI service that receives pre-rendered PNG labels and prints them via brother_ql. Runs in dry-run mode by default (saves PNG to volume instead of printing).

**Key features:**
- Accepts base64-encoded PNG images
- Direct printing via brother_ql library (no PIL/image generation)
- Configurable via environment variables: `DRY_RUN`, `PRINTER_MODEL`, `PRINTER_TAPE`

## API Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/db/rpc/create_batch` | POST | Create batch with N portions |
| `/api/db/rpc/save_recipe` | POST | Create or update recipe with ingredients |
| `/api/db/batch_summary?frozen_count=gt.0` | GET | Dashboard data |
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

## Language Notes

- UI is in Spanish (expiry label: "Caduca:", food categories like "Arroz", "Pollo", etc.)

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
