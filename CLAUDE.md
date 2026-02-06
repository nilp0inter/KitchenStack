# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run Commands

```bash
# Start all services (full stack)
docker compose up --build

# Rebuild from scratch (clears database)
docker compose down -v && docker compose up --build

# View logs
docker compose logs -f [service_name]  # postgres, postgrest, printer_service, caddy, client_builder

# Local Elm client development (requires services running)
cd client && npm install && npm run dev
```

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

Single-file SPA (`client/src/Main.elm`) using `Browser.application`:
- Routes: Dashboard (`/`), NewBatch (`/new`), ItemDetail (`/item/{uuid}`), History (`/history`)
- Uses `andMap` helper pattern for JSON decoders with >8 fields
- Tailwind CSS with custom "frost" color palette

### Printer Service

Python FastAPI service generates 62mm Brother QL labels with QR codes. Runs in dry-run mode by default (saves PNG to volume instead of printing).

## API Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/db/rpc/create_batch` | POST | Create batch with N portions |
| `/api/db/batch_summary?frozen_count=gt.0` | GET | Dashboard data |
| `/api/db/portion_detail?portion_id=eq.{uuid}` | GET | QR scan page data |
| `/api/db/portion?id=eq.{uuid}` | PATCH | Consume portion (set status, consumed_at) |
| `/api/db/freezer_history` | GET | Chart data |
| `/api/printer/print` | POST | Print single label |

## Language Notes

- UI is in Spanish (expiry label: "Caduca:", food categories like "Arroz", "Pollo", etc.)
