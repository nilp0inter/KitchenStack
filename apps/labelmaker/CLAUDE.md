# LabelMaker App — CLAUDE.md

LabelMaker is a **label template designer & library** using **CQRS + Event Sourcing**. All writes go through an append-only event table; projection tables are rebuilt from events.

## Three-Schema Architecture

```
labelmaker_data   — Persistent storage: event store (append-only)
labelmaker_logic  — Business logic: projection tables, event handlers, replay, helpers
labelmaker_api    — External interface: read views + RPC write functions (exposed via PostgREST)
```

- `labelmaker_data` schema is created once via migration and never dropped
- `labelmaker_logic` and `labelmaker_api` schemas are idempotent (DROP + CREATE) and can be redeployed without data loss
- All writes INSERT into `labelmaker_data.event`; a trigger calls `labelmaker_logic.apply_event()` to update projections
- `labelmaker_logic.replay_all_events()` truncates all projections and rebuilds from the event store

## Key Database Objects

**Data schema (persistent — `labelmaker_data`):**
- **`labelmaker_data.event`**: Append-only event store (id BIGSERIAL, type TEXT, payload JSONB, created_at TIMESTAMPTZ)

**Logic schema (idempotent — `labelmaker_logic`):**
- **`labelmaker_logic.apply_event()`**: CASE dispatcher (currently empty — no event types yet)
- **`labelmaker_logic.replay_all_events()`**: Truncates projections and rebuilds from events

**API schema (idempotent — `labelmaker_api`):**
- **`labelmaker_api.event`**: View exposing the event store

## Database File Structure

```
apps/labelmaker/database/
├── migrations/001-initial.sql    # Data schema (event table, indexes, extensions)
├── logic.sql                     # Logic schema (event handlers, replay) — idempotent
├── api.sql                       # API schema (views, RPC functions) — idempotent
├── seed.sql                      # Seed data as events (empty)
├── migrate.sh                    # Auto-migration (runs in labelmaker_db_migrator container)
└── deploy.sh                     # Manual redeploy from host (uses docker exec)
```

### Deploying Schema Changes

Schema changes are **auto-applied on every `docker compose up`** by the `labelmaker_db_migrator` one-shot container. For manual redeploy:

```bash
./apps/labelmaker/database/deploy.sh
```

**Note:** After manual `deploy.sh`, restart PostgREST to refresh its schema cache: `docker restart kitchen_postgrest`

## Elm Client Structure

Minimal SPA using `Browser.application`:

```
apps/labelmaker/client/src/
├── Main.elm              # Entry point, routing, global state
├── Route.elm             # Route type: Home | NotFound
├── Types.elm             # Shared types (RemoteData, Notification)
├── Api.elm               # HTTP functions (placeholder)
├── Api/
│   ├── Decoders.elm      # JSON decoders (placeholder)
│   └── Encoders.elm      # JSON encoders (placeholder)
├── Ports.elm             # Port definitions (placeholder)
├── Components.elm        # Header, notification, loading
└── Page/
    ├── Home.elm          # Facade: Model, Msg, OutMsg, init, update, view
    ├── Home/
    │   ├── Types.elm     # Minimal model + msg types
    │   └── View.elm      # "Welcome to LabelMaker" page
    ├── NotFound.elm      # Facade
    └── NotFound/
        └── View.elm      # 404 page
```

**Architecture pattern:** Same as FrostByte — each page exposes Model, Msg, OutMsg, init, update, view. Pages communicate up via OutMsg.

**Routes:** `/` (Home)

**Styling:** Tailwind CSS with custom "label" color palette (warm brown tones)

**Served on:** Port `:8080` via Caddy

## API Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/db/event` | GET | Event store |
| `/api/printer/print` | POST | Print PNG label |
| `/api/printer/health` | GET | Printer service health check |

## Adding a New Page

Same pattern as FrostByte:

1. Create `Page/NewPage.elm` (facade) + `Page/NewPage/Types.elm` + `Page/NewPage/View.elm`
2. Add route in `Route.elm`
3. Wire up in `Main.elm` (Page type, Msg type, initPage, update, viewPage)
4. Add nav link in `Components.elm`
