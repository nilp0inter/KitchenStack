# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
- http://localhost/new - Create new batch
- http://localhost/batch/{uuid} - Batch detail
- http://localhost/item/{uuid} - Portion detail (QR scan target)
- http://localhost/history - Freezer history
- http://localhost/containers - Container type management

## Architecture Overview

FrostByte is an **append-only** home freezer management system. Each physical food portion has its own UUID and printed QR label. Portions transition between states (FROZEN → CONSUMED) but are never deleted.

### Data Flow

1. **Batch Creation**: User creates a batch via Elm UI → `POST /api/db/rpc/create_batch` → PostgreSQL function creates batch + N portions → Returns `{batch_id, portion_ids[]}` → Client calls printer service for each portion_id
2. **QR Scan Consumption**: User scans QR code → `/item/{portion_uuid}` route → Fetches from `portion_detail` view → User confirms → `PATCH /api/db/portion` sets status=CONSUMED
3. **Dashboard**: Fetches `batch_summary` view (batches grouped with frozen/consumed counts)

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

- **`create_batch` function**: RPC endpoint that atomically creates a batch with N portions, auto-calculates expiry from category.safe_days
- **`batch_summary` view**: Aggregates portions by batch for dashboard display
- **`portion_detail` view**: Joins portion with batch info for QR scan page
- **`freezer_history` view**: Running totals of frozen portions over time for chart

### Elm Client Structure

Modular SPA using `Browser.application` with page-based architecture:

```
client/src/
├── Main.elm              # Entry point, routing, global state
├── Route.elm             # Route type and URL parsing
├── Types.elm             # Shared domain types (BatchSummary, PortionDetail, etc.)
├── Api.elm               # HTTP functions (parameterized msg constructors)
├── Api/
│   ├── Decoders.elm      # JSON decoders (uses andMap helper for >8 fields)
│   └── Encoders.elm      # JSON encoders for POST/PATCH bodies
├── Components.elm        # Shared UI (header, notification, modal, loading)
└── Page/
    ├── Dashboard.elm     # Batch list with servings calculation
    ├── NewBatch.elm      # Batch creation form with printing
    ├── ItemDetail.elm    # Portion consumption (QR scan target)
    ├── BatchDetail.elm   # Batch detail with portion list, reprinting
    ├── History.elm       # Freezer history chart and table
    ├── ContainerTypes.elm# Container type CRUD
    └── NotFound.elm      # 404 page
```

**Architecture pattern:**
- Each page module exposes: `Model`, `Msg`, `OutMsg`, `init`, `update`, `view`
- Pages communicate up via `OutMsg` (navigation, notifications, refresh requests)
- Main.elm wraps page messages: `DashboardMsg Page.Dashboard.Msg`
- Shared data (categories, containerTypes, batches) lives in Main and passed to pages

**Routes:** `/` (Dashboard), `/new` (NewBatch), `/item/{uuid}` (ItemDetail), `/batch/{uuid}` (BatchDetail), `/history` (History), `/containers` (ContainerTypes)

**Styling:** Tailwind CSS with custom "frost" color palette

### Printer Service

Python FastAPI service generates 62mm Brother QL labels with QR codes. Runs in dry-run mode by default (saves PNG to volume instead of printing).

## API Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/db/rpc/create_batch` | POST | Create batch with N portions |
| `/api/db/batch_summary?frozen_count=gt.0` | GET | Dashboard data |
| `/api/db/portion_detail?portion_id=eq.{uuid}` | GET | QR scan page data |
| `/api/db/portion?id=eq.{uuid}` | PATCH | Consume portion (set status, consumed_at) |
| `/api/db/portion?batch_id=eq.{uuid}` | GET | Get portions for a batch |
| `/api/db/freezer_history` | GET | Chart data |
| `/api/db/category` | GET | List food categories |
| `/api/db/container_type` | GET/POST | List or create container types |
| `/api/db/container_type?name=eq.{name}` | PATCH/DELETE | Update or delete container type |
| `/api/printer/print` | POST | Print single label |
| `/api/printer/preview` | GET | Preview label as PNG image |

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

## Language Notes

- UI is in Spanish (expiry label: "Caduca:", food categories like "Arroz", "Pollo", etc.)
