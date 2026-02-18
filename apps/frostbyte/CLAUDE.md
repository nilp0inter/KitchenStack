# FrostByte App — CLAUDE.md

FrostByte is an **append-only** home freezer management system with **CQRS + Event Sourcing**. Each physical food portion has its own UUID and printed QR label. All writes go through an append-only event table; projection tables are rebuilt from events.

## Three-Schema Architecture

```
frostbyte_data   — Persistent storage: event store (append-only)
frostbyte_logic  — Business logic: projection tables, event handlers, replay, helpers
frostbyte_api    — External interface: read views + RPC write functions (exposed via PostgREST)
```

- `frostbyte_data` schema is created once via migration and never dropped
- `frostbyte_logic` and `frostbyte_api` schemas are idempotent (DROP + CREATE) and can be redeployed without data loss
- All writes INSERT into `frostbyte_data.event`; a trigger calls `frostbyte_logic.apply_event()` to update projections
- `frostbyte_logic.replay_all_events()` truncates all projections and rebuilds from the event store

## Data Flow

1. **Batch Creation**: User creates a batch via Elm UI → `POST /api/db/rpc/create_batch` → API function computes expiry dates server-side, INSERTs event → trigger creates batch + N portions → Returns `{batch_id, portion_ids[], expiry_date, best_before_date}` → Client renders SVG labels → converts to PNG via JS ports → sends to printer service
2. **QR Scan Consumption**: User scans QR code → `/item/{portion_uuid}` route → Fetches from `portion_detail` view → User confirms → `POST /api/db/rpc/consume_portion` → INSERTs event → trigger updates portion status
3. **Inventory**: Fetches `batch_summary` view (batches grouped with frozen/consumed counts)
4. **All CRUD**: Every write operation (ingredient/container/preset/recipe/batch/portion) goes through a typed RPC function that INSERTs an event

## Key Database Objects

**Data schema (persistent — `frostbyte_data`):**
- **`frostbyte_data.event`**: Append-only event store (id BIGSERIAL, type TEXT, payload JSONB, created_at TIMESTAMPTZ)

**Logic schema (idempotent — `frostbyte_logic`):**
- **Projection tables**: `image`, `ingredient`, `container_type`, `label_preset`, `batch`, `batch_ingredient`, `portion`, `recipe`, `recipe_ingredient`
- **`frostbyte_logic.apply_event()`**: CASE dispatcher to 14 individual handler functions
- **`frostbyte_logic.compute_expiry_date()`** / **`frostbyte_logic.compute_best_before_date()`**: Server-side date computation from ingredient data
- **`frostbyte_logic.store_image_base64()`** / **`frostbyte_logic.get_image_base64()`**: Image helpers
- **`frostbyte_logic.replay_all_events()`**: Truncates projections and rebuilds from events

**API schema (idempotent — `frostbyte_api`):**
- **`frostbyte_api.batch_summary`**: Aggregates portions by batch for dashboard display, includes image
- **`frostbyte_api.portion_detail`**: Joins portion with batch info for QR scan page
- **`frostbyte_api.freezer_history`**: Running totals of frozen portions over time for chart
- **`frostbyte_api.recipe_summary`**: Recipes with aggregated ingredient names for listing, includes image
- **`frostbyte_api.create_batch()`**: Computes expiry server-side, INSERTs event, returns computed dates
- **`frostbyte_api.consume_portion()`** / **`frostbyte_api.return_portion()`**: Portion state changes via events
- **`frostbyte_api.create_ingredient()`** / **`frostbyte_api.update_ingredient()`** / **`frostbyte_api.delete_ingredient()`**: Ingredient CRUD via events
- Similar CRUD RPCs for container_type, label_preset, recipe

## Database File Structure

```
apps/frostbyte/database/
├── migrations/001-initial.sql            # Data schema (tables, indexes, extensions)
├── migrations/003-monorepo-rename.sql    # Schema rename: data → frostbyte_data
├── logic.sql                             # Logic schema (event handlers, replay) — idempotent
├── api.sql                               # API schema (views, RPC functions) — idempotent
├── seed.sql                              # Seed data as events
├── migrate.sh                            # Auto-migration (runs in db_migrator container on every startup)
├── deploy.sh                             # Manual redeploy from host (uses docker exec)
└── migrate-from-json.py                  # Convert old JSON backup to events
```

### Deploying Schema Changes

Schema changes are **auto-applied on every `docker compose up`** by the `frostbyte_db_migrator` one-shot container. It runs migrations, redeploys logic/api schemas, and replays events before PostgREST starts. No manual intervention needed after updates.

For manual redeploy from the host (without restarting containers):

```bash
./apps/frostbyte/database/deploy.sh
# Equivalent to:
# psql < migrations/*.sql  (apply pending migrations)
# psql < logic.sql          (DROP + CREATE frostbyte_logic schema)
# psql < api.sql            (DROP + CREATE frostbyte_api schema)
# SELECT frostbyte_logic.replay_all_events();  (rebuild projections)
```

**Note:** After manual `deploy.sh`, restart PostgREST to refresh its schema cache: `docker restart kitchen_postgrest`

## Elm Client Structure

Modular SPA using `Browser.application` with page-based architecture:

```
apps/frostbyte/client/src/
├── Main.elm              # Entry point, routing, global state, port subscriptions
├── Route.elm             # Route type and URL parsing
├── Types.elm             # Shared domain types (BatchSummary, PortionDetail, LabelPreset, etc.)
├── Api.elm               # HTTP functions (parameterized msg constructors)
├── Api/
│   ├── Decoders.elm      # JSON decoders (uses andMap helper for >8 fields)
│   └── Encoders.elm      # JSON encoders for RPC bodies (all writes use POST)
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

### RemoteData Pattern for Loading State

```elm
type RemoteData a
    = NotAsked    -- Initial state before any request
    | Loading     -- Request is in progress
    | Loaded a    -- Data successfully loaded
    | Failed String  -- Request failed with error message
```

## Label Rendering Architecture

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
- `frostbyte_logic.label_preset` table - Stores named label configurations (dimensions, fonts, min font sizes)

**Key types:**
- `LabelSettings` - Label dimensions, fonts, visibility toggles (from preset)
- `LabelData` - Content to render (name, ingredients, dates, QR URL)
- `ComputedLabelData` - JS-measured values: `titleFontSize`, `titleLines`, `ingredientLines`

**Label presets** are stored in PostgreSQL and allow users to configure different label sizes (62mm, 29mm, 12mm tape). The Label Designer page (`/labels`) provides a live preview with editable sample text and real-time text fitting.

## Image Handling

Recipes and batches support optional images stored as binary data in PostgreSQL.

### Database Design

Images use a normalized design with a separate `image` table in `frostbyte_logic`:

```sql
CREATE TABLE frostbyte_logic.image (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    image_data BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE FUNCTION frostbyte_logic.store_image_base64(base64_data TEXT) RETURNS UUID
CREATE FUNCTION frostbyte_logic.get_image_base64(image_id UUID) RETURNS TEXT
```

Foreign keys link images to recipes and batches:
- `frostbyte_logic.recipe.image_id` → `frostbyte_logic.image(id)` (nullable, ON DELETE SET NULL)
- `frostbyte_logic.batch.image_id` → `frostbyte_logic.image(id)` (nullable, ON DELETE SET NULL)

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

### Adding Image Support to New Entities

1. **Database**: Add `image_id UUID NULL REFERENCES frostbyte_logic.image(id) ON DELETE SET NULL` to table
2. **Event handler**: In `logic.sql`, call `frostbyte_logic.store_image_base64()` if `p->>'image_data'` is present
3. **API RPC**: Add `p_image_data TEXT DEFAULT NULL` parameter, include in event payload
4. **View**: LEFT JOIN with `frostbyte_logic.image` table, include `encode(i.image_data, 'base64') AS image`
5. **Elm Types**: Add `image : Maybe String` to both the entity type and form type
6. **Decoders**: Add `|> andMap (Decode.field "image" (Decode.nullable Decode.string))`
7. **Encoders**: Add image field encoding with `p_image_data` key
8. **Page Types**: Add `SelectImage`, `GotImageResult Ports.FileSelectResult`, `RemoveImage` to Msg
9. **Page Types**: Add `RequestFileSelect Ports.FileSelectRequest` to OutMsg
10. **Page update**: Handle the three image messages
11. **Page view**: Add `viewImageSelector` component
12. **Main.elm**: Forward `GotFileSelectResult` to page, handle `RequestFileSelect` OutMsg

## API Reference

All writes go through RPC functions (POST). Reads use PostgREST views (GET).

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/db/rpc/create_batch` | POST | Create batch with N portions (server computes expiry) |
| `/api/db/rpc/consume_portion` | POST | Mark portion as consumed |
| `/api/db/rpc/return_portion` | POST | Return consumed portion to freezer |
| `/api/db/rpc/save_recipe` | POST | Create or update recipe with ingredients |
| `/api/db/rpc/delete_recipe` | POST | Delete recipe |
| `/api/db/rpc/create_ingredient` | POST | Create ingredient |
| `/api/db/rpc/update_ingredient` | POST | Update ingredient (supports rename) |
| `/api/db/rpc/delete_ingredient` | POST | Delete ingredient |
| `/api/db/rpc/create_container_type` | POST | Create container type |
| `/api/db/rpc/update_container_type` | POST | Update container type (supports rename) |
| `/api/db/rpc/delete_container_type` | POST | Delete container type |
| `/api/db/rpc/create_label_preset` | POST | Create label preset |
| `/api/db/rpc/update_label_preset` | POST | Update label preset (supports rename) |
| `/api/db/rpc/delete_label_preset` | POST | Delete label preset |
| `/api/db/batch_summary?frozen_count=gt.0` | GET | Inventory data |
| `/api/db/portion_detail?portion_id=eq.{uuid}` | GET | QR scan page data |
| `/api/db/portion?batch_id=eq.{uuid}` | GET | Get portions for a batch |
| `/api/db/freezer_history` | GET | Chart data |
| `/api/db/ingredient` | GET | List ingredients |
| `/api/db/recipe_summary` | GET | List recipes with ingredients |
| `/api/db/container_type` | GET | List container types |
| `/api/db/label_preset` | GET | List label presets |
| `/api/db/event` | GET | Event store (for backup) |
| `/api/printer/print` | POST | Print PNG label (body: `{image_data: "base64..."}`) |
| `/api/printer/health` | GET | Printer service health check |

## Installing Elm Packages

**IMPORTANT:** Do not manually edit `apps/frostbyte/client/elm.json` to add dependencies. Elm requires proper dependency resolution which only `elm install` can perform correctly.

To install a new Elm package, run from the `apps/frostbyte/client/` directory:

```bash
# Install a package (auto-confirms the prompt)
docker run --rm -v "$(pwd)":/app -w /app node:20-alpine sh -c "npm install -g elm && echo y | elm install <package-name>"
```

To verify compilation after installing:

```bash
docker run --rm -v "$(pwd)":/app -w /app node:20-alpine sh -c "npm install -g elm && elm make src/Main.elm --output=/dev/null"
```

## Adding a New Page

1. Create `apps/frostbyte/client/src/Page/NewPage.elm` with:
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

2. Add JavaScript handlers in `apps/frostbyte/client/src/main.js`:
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
