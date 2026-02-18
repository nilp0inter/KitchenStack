# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Monorepo Structure

This is the **Kitchen Management Stack** monorepo. Each app has its own database schemas within a shared PostgreSQL instance (`kitchen_db`).

```
FrostByte/
├── common/                    # Shared infrastructure
│   ├── gateway/               # Caddy reverse proxy (Caddyfile, Caddyfile.dev)
│   ├── printer_service/       # Python FastAPI label printing service
│   └── backup/                # GoBackup config + scripts
├── apps/
│   └── frostbyte/             # Freezer management app
│       ├── client/            # Elm SPA frontend
│       └── database/          # SQL schemas, migrations, seed data
│           ├── migrations/    # Data schema migrations (persistent)
│           ├── logic.sql      # frostbyte_logic schema (idempotent)
│           ├── api.sql        # frostbyte_api schema (idempotent)
│           ├── seed.sql       # Seed data as events
│           ├── migrate.sh     # Auto-migration (runs in db_migrator container)
│           └── deploy.sh      # Manual redeploy from host
├── docker-compose.yml         # Base config (common + app services)
├── docker-compose.dev.yml     # Dev overlay (Vite HMR)
├── docker-compose.prod.yml    # Prod overrides (pre-built images)
└── docker-compose.secrets.yml # SOPS secrets mapping
```

**App-specific docs:** See `apps/frostbyte/CLAUDE.md` for FrostByte architecture, database schemas, Elm client structure, and API reference.

### Adding a New App

1. Create `apps/<appname>/database/` with migrations, logic, and api SQL files
2. Use schema prefix `<appname>_data`, `<appname>_logic`, `<appname>_api`
3. Add app-specific services to `docker-compose.yml` under the app section
4. Add `<appname>_api` to PostgREST's `PGRST_DB_SCHEMA` (comma-separated)
5. Create `apps/<appname>/CLAUDE.md` for app-specific docs

### Shared Database

- **Database**: `kitchen_db` (PostgreSQL 15)
- **User**: `kitchen_user`
- **Schema namespacing**: Each app prefixes its schemas (e.g., `frostbyte_data`, `frostbyte_logic`, `frostbyte_api`)
- **PostgREST**: Exposes `frostbyte_api` schema (add more with comma-separated `PGRST_DB_SCHEMA`)

## Production Environment

Runs on a Raspberry Pi Zero 2W (aarch64):
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
1. Make changes to Elm files in `apps/frostbyte/client/src/`
2. Run `docker compose up --build -d` to rebuild
3. Check `docker compose logs client_builder` for compilation errors
4. If successful, test at http://localhost/

### Development Mode with Hot Reloading

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
- `common/gateway/Caddyfile.dev` - Dev Caddyfile (proxies to Vite instead of static files)

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

### Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Caddy (:80)                                                      │
│   /          → Elm SPA (static files from client_dist volume)    │
│   /api/db/*  → PostgREST (:3000) → PostgreSQL                    │
│   /api/printer/* → Printer Service (:8000)                       │
└─────────────────────────────────────────────────────────────────┘
│ db_migrator (one-shot) → runs migrations on startup, then exits  │
│ GoBackup (:2703) → Web UI for backup management                  │
└─────────────────────────────────────────────────────────────────┘
```

**Startup order:** `postgres` (healthy) → `db_migrator` (runs + exits) → `postgrest` → `caddy`

### Printer Service

Python FastAPI service that receives pre-rendered PNG labels and prints them via brother_ql. Runs in dry-run mode by default (saves PNG to volume instead of printing).

**Key features:**
- Accepts base64-encoded PNG images
- Direct printing via brother_ql library (no PIL/image generation)
- Configurable via environment variables: `DRY_RUN`, `PRINTER_MODEL`, `PRINTER_TAPE`

**USB access requirements (production):**
- Container mounts `/dev/bus/usb` (not all of `/dev`) with `device_cgroup_rules: ['c 189:* rwm']` for USB device access — no `privileged: true` needed
- `/run/udev:/run/udev:ro` is mounted so `libusb` can discover USB devices after re-enumeration (e.g., printer standby/wake)
- Printing runs in a subprocess (`multiprocessing`) so each job gets fresh USB state

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
- `apps/frostbyte/client/Dockerfile` - Multi-stage: builder (Node+Elm) -> final (Alpine+static)
- `docker-compose.yml` - Base config (uses `target: builder`)
- `docker-compose.dev.yml` - Dev overlay (Vite HMR, hot reloading)
- `docker-compose.prod.yml` - Prod overrides (uses pre-built image)
- `common/gateway/Caddyfile` - Production Caddyfile (serves static files)
- `common/gateway/Caddyfile.dev` - Dev Caddyfile (proxies to Vite)
- `.github/workflows/build-client.yml` - Client CI pipeline
- `.github/workflows/build-printer.yml` - Printer service CI pipeline
- `docker-compose.secrets.yml` - Maps SOPS secrets to service environments

## Secrets Management

Uses [SOPS](https://github.com/getsops/sops) with GPG (dev) and age (Pi) for secrets management. Encrypted secrets are stored in `.env.prod` and committed to version control.

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

Uses [GoBackup](https://gobackup.github.io/) for automated PostgreSQL backups to Backblaze B2 with Healthchecks.io monitoring.

### Configuration
- **Schedule**: Daily at 3:00 AM
- **Retention**: 30 days (managed by B2 lifecycle rules)
- **Storage**: Backblaze B2 (S3-compatible)
- **Monitoring**: Healthchecks.io ping on success/failure

### Key Files
- `common/backup/gobackup.yml` - GoBackup configuration (uses env vars for secrets)
- `docker-compose.secrets.yml` - Maps SOPS secrets to gobackup environment

### Web UI
Access backup status at: `http://KitchenLabelPrinter.local:2703/`

### Manual Backup
```bash
docker exec frostbyte_gobackup gobackup perform frostbyte_db
```

### CSV Event Backup

In addition to PostgreSQL dumps, GoBackup also exports the event table as a CSV file via `psql COPY`. Since FrostByte uses event sourcing, all state can be rebuilt from the event table alone.

**How it works:**
- `common/backup/event-backup.sh` runs as a `before_script` in GoBackup
- Uses `psql` with `COPY TO STDOUT` to dump the `frostbyte_data.event` table as CSV
- Saves to `/data/json/events.csv` (reuses existing archive path)
- CSV is portable — no schema/role names embedded in the data

**Key files:**
- `common/backup/event-backup.sh` - CSV backup script (runs inside gobackup container)
- `common/backup/event-restore.sh` - CSV restore script (runs from dev machine or Pi)
- `common/backup/Dockerfile` - Custom gobackup image with psql and scripts baked in

### Restoring from CSV Event Backup

To restore data from a CSV event backup (e.g., after wiping the database):

```bash
# 1. Download and extract the backup archive from B2
# 2. Locate events.csv in data/json/

# 3. Restore to the Pi (from dev machine)
CONTAINER=frostbyte_postgres DB_USER=kitchen_user DB_NAME=kitchen_db \
  ./common/backup/event-restore.sh /path/to/backup/data/json/events.csv

# Or restore to local dev environment (uses defaults)
./common/backup/event-restore.sh /path/to/backup/data/json/events.csv
```

The restore script disables the event trigger, loads all events via `COPY`, resets the sequence, then calls `frostbyte_logic.replay_all_events()` to rebuild all projections.
### Migrating from Old (Pre-Event-Sourcing) Backup

```bash
./apps/frostbyte/database/migrate-from-json.py /path/to/old/backup/data/json > events.sql
docker exec -i frostbyte_postgres psql -U kitchen_user -d kitchen_db < events.sql
```

## Production Migration (from pre-monorepo)

For existing Pi deployment with old DB/user names:
```bash
# 1. Stop all services
docker compose ... down
# 2. Start only postgres
docker compose up -d postgres
# 3. Rename database and user (connect as postgres superuser)
docker exec frostbyte_postgres psql -U postgres -d postgres -c \
  "ALTER DATABASE frostbyte_db RENAME TO kitchen_db;"
docker exec frostbyte_postgres psql -U postgres -d kitchen_db -c \
  "ALTER ROLE frostbyte_user RENAME TO kitchen_user;"
# 4. Stop postgres, deploy with new config
docker compose down
```

## Language Notes

- UI is in Spanish (expiry label: "Caduca:", food categories like "Arroz", "Pollo", etc.)
