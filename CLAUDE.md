# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Monorepo Structure

This is the **Kitchen Management Stack** monorepo. Each app has its own database schemas within a shared PostgreSQL instance (`kitchen_db`).

```
KitchenStack/
├── common/                    # Shared infrastructure
│   ├── gateway/               # Caddy reverse proxy (Caddyfile, Caddyfile.dev)
│   ├── printer_service/       # Python FastAPI label printing service
│   ├── storage/               # VersityGW S3 migration scripts
│   └── backup/                # GoBackup config + scripts
├── apps/
│   ├── frostbyte/             # Freezer management app (:80)
│   │   ├── client/            # Elm SPA frontend
│   │   └── database/          # SQL schemas, migrations, seed data
│   │       ├── migrations/    # Data schema migrations (persistent)
│   │       ├── logic.sql      # frostbyte_logic schema (idempotent)
│   │       ├── api.sql        # frostbyte_api schema (idempotent)
│   │       ├── seed.sql       # Seed data as events
│   │       ├── migrate.sh     # Auto-migration (runs in frostbyte_db_migrator container)
│   │       └── deploy.sh      # Manual redeploy from host
│   └── labelmaker/            # Label template designer (:8080)
│       ├── client/            # Elm SPA frontend
│       └── database/          # SQL schemas, migrations, seed data
│           ├── migrations/    # Data schema migrations (persistent)
│           ├── logic.sql      # labelmaker_logic schema (idempotent)
│           ├── api.sql        # labelmaker_api schema (idempotent)
│           ├── seed.sql       # Seed data as events
│           ├── migrate.sh     # Auto-migration (runs in labelmaker_db_migrator container)
│           └── deploy.sh      # Manual redeploy from host
├── deploy/                    # Ansible deployment automation
│   ├── inventory.yml          # Single host: KitchenLabelPrinter.local
│   ├── ansible.cfg            # SSH user, inventory path
│   ├── bootstrap.yml          # Full Pi provisioning (run once on new hardware)
│   ├── deploy.yml             # App deployment (run on every update)
│   ├── restore.yml            # Disaster recovery (restore from CSV backup)
│   ├── secrets/
│   │   └── age-key.sops       # Age private key encrypted with SOPS (GPG-only)
│   └── templates/
│       └── kitchen.service.j2 # Systemd service unit (templated)
├── flake.nix                  # Nix dev shell (ansible, sops, go-task)
├── Taskfile.yml               # Task runner (bootstrap, deploy, restore)
├── docker-compose.yml         # Base config (common + app services)
├── docker-compose.dev.yml     # Dev overlay (Vite HMR)
├── docker-compose.prod.yml    # Prod overrides (pre-built images)
└── docker-compose.secrets.yml # SOPS secrets mapping
```

**App-specific docs:**
- `apps/frostbyte/CLAUDE.md` — FrostByte architecture, database schemas, Elm client, API reference
- `apps/labelmaker/CLAUDE.md` — LabelMaker architecture, database schemas, Elm client, API reference

### Adding a New App

1. Create `apps/<appname>/database/` with migrations, logic, and api SQL files
2. Use schema prefix `<appname>_data`, `<appname>_logic`, `<appname>_api`
3. Add app-specific services to `docker-compose.yml` under the app section
4. Add `<appname>_api` to PostgREST's `PGRST_DB_SCHEMA` (comma-separated)
5. Add a Caddy site block on a new port with `Accept-Profile` / `Content-Profile` headers pinned to `<appname>_api`
6. Create `apps/<appname>/CLAUDE.md` for app-specific docs

### Shared Database

- **Database**: `kitchen_db` (PostgreSQL 15)
- **User**: `kitchen_user`
- **Schema namespacing**: Each app prefixes its schemas (e.g., `frostbyte_data`, `frostbyte_logic`, `frostbyte_api`)
- **PostgREST**: Exposes `frostbyte_api,labelmaker_api` schemas (comma-separated `PGRST_DB_SCHEMA`)
- **Schema isolation**: Caddy injects `Accept-Profile` and `Content-Profile` headers per port, so each app is pinned to its own schema without clients needing to set headers
- **Persistent volumes**: `kitchen_postgres_data` and `kitchen_storage_data` are external Docker volumes — `docker compose down` cannot remove them. Must be created manually once or via the bootstrap/deploy playbooks

### Object Storage (VersityGW)

- **Service**: VersityGW (S3-compatible, POSIX backend) on port 7070 (internal)
- **Bucket isolation**: Each app has its own bucket (`frostbyte-assets`, `labelmaker-assets`)
- **Caddy routing**: `/api/assets/{key}` on each port rewrites to `/{app}-assets/{key}` — clients never see bucket names
- **Public access**: Buckets allow unauthenticated GET/PUT (no S3 auth needed from browser)
- **Persistent volume**: `kitchen_storage_data` stores all uploaded assets
- **Usage**: Images are uploaded via `PUT /api/assets/{uuid}` and referenced by URL path in the database
- **Env vars**: `ROOT_ACCESS_KEY_ID`, `ROOT_SECRET_ACCESS_KEY` (VersityGW root credentials); `VGW_PORT` (listen address)
- **Credentials**: Only used by `storage` (VersityGW itself) and `storage_init` (bucket creation via AWS CLI). After init, all object access is unauthenticated via public bucket policies. Hardcoded dev defaults work even in prod since VersityGW is not exposed outside the Docker network. Optional SOPS overrides exist in `docker-compose.secrets.yml` (`KITCHEN_STORAGE_ACCESS_KEY`, `KITCHEN_STORAGE_SECRET_KEY`) but are not required.
- **Bucket init**: `storage_init` one-shot container creates buckets and sets public read/write policies via AWS CLI
- **Migration**: `common/storage/migrate-images.sh` migrates legacy base64 event payloads to VersityGW (run once after upgrading from base64 image storage)

**Migrating existing base64 images:**
```bash
# Run from the repo root (requires running stack with storage service)
docker run --rm --network kitchenstack_kitchen_network \
  -e PGHOST=postgres -e PGUSER=kitchen_user \
  -e PGPASSWORD=kitchen_password -e PGDATABASE=kitchen_db \
  -e STORAGE_URL=http://storage:7070 \
  -v ./common/storage/migrate-images.sh:/migrate.sh:ro \
  alpine:latest sh -c "apk add --no-cache curl postgresql-client >/dev/null 2>&1 && sh /migrate.sh"
```

## Production Environment

Runs on a Raspberry Pi Zero 2W (aarch64):
- **Hostname**: `KitchenLabelPrinter.local`
- **IP**: `10.40.8.32`
- **User**: `nil`
- **Repo path**: `~/KitchenStack`
- **OS**: Debian 13 (trixie)
- **Systemd service**: `kitchen.service` (starts on boot, templated from `deploy/templates/kitchen.service.j2`)

### Deployment Automation (Ansible)

All deployment is automated via Ansible playbooks. Requires the Nix dev shell (`direnv allow` or `nix develop`).

```bash
# Deploy latest code to Pi (routine updates)
task deploy

# Provision a fresh Pi from scratch (requires yubikey for age key decryption)
task bootstrap

# Restore event data from CSV backup (after bootstrap)
task restore FROSTBYTE_CSV=/path/to/frostbyte_events.csv
task restore FROSTBYTE_CSV=/path/to/frostbyte.csv LABELMAKER_CSV=/path/to/labelmaker.csv

# Test SSH connectivity
cd deploy && ansible all -m ping
```

**How it works:**
- `task deploy` — runs `git pull`, `docker compose pull`, restarts `kitchen.service` on the Pi
- `task bootstrap` — installs packages, deploys age key (from SOPS-encrypted `deploy/secrets/age-key.sops`), clones repo, installs systemd service, starts stack
- `task restore FROSTBYTE_CSV=... [LABELMAKER_CSV=...]` — copies CSV event files to Pi, runs `event-restore.sh` for each app

**One-time setup (age key):**
```bash
# Encrypt the Pi's age key with SOPS (uses yubikey GPG)
sops -e ~/.config/sops/age/keys.txt > deploy/secrets/age-key.sops
```

### Manual Service Management (on Pi)

```bash
sudo systemctl status kitchen
sudo systemctl restart kitchen
sudo systemctl stop kitchen
```

## Build and Run Commands

```bash
# Start all services (full stack, runs in background)
docker compose up --build -d

# Rebuild from scratch (clears database)
docker compose down -v && docker compose up --build -d

# Check Elm compilation status (after making client changes)
docker compose logs frostbyte_client_builder

# View logs for a specific service
docker compose logs -f [service_name]  # postgres, postgrest, printer_service, caddy, frostbyte_client_builder

# Stop all services
docker compose down
```

**Testing changes (rebuild mode):**
1. Make changes to Elm files in `apps/frostbyte/client/src/`
2. Run `docker compose up --build -d` to rebuild
3. Check `docker compose logs frostbyte_client_builder` for compilation errors
4. If successful, test at http://localhost/

### Development Mode with Hot Reloading

```bash
# Start dev mode (Vite HMR - no rebuild needed for changes)
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Watch Vite dev server logs
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f frostbyte_client_dev

# Stop dev mode
docker compose -f docker-compose.yml -f docker-compose.dev.yml down
```

**How it works:**
- `frostbyte_client_dev` service runs Vite dev server on port 5173
- Caddy proxies non-API requests to Vite (instead of serving static files)
- Source code is mounted, so edits trigger automatic browser refresh
- API routing (`/api/db/*`, `/api/printer/*`) works identically to production

**Request flow (dev mode):**
```
Browser :80   → Caddy → frostbyte_client_dev:5173 (FrostByte Vite HMR)
Browser :8080 → Caddy → labelmaker_client_dev:5173 (LabelMaker Vite HMR)
Browser :80/:8080 → Caddy → postgrest:3000 (/api/db/*)
Browser :80/:8080 → Caddy → storage:7070 (/api/assets/* → /{app}-assets/*)
Browser :80/:8080 → Caddy → printer_service:8000 (/api/printer/*)
```

**Key files:**
- `docker-compose.dev.yml` - Dev overlay (adds `frostbyte_client_dev` service, swaps Caddyfile)
- `common/gateway/Caddyfile.dev` - Dev Caddyfile (proxies to Vite instead of static files)

**Available routes to test:**

*FrostByte (:80):*
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

*LabelMaker (:8080):*
- http://localhost:8080/ - Template list (create, select, delete templates)
- http://localhost:8080/template/{uuid} - Template editor (label canvas)
- http://localhost:8080/labels - Label list (create from template, view, delete)
- http://localhost:8080/label/{uuid} - Label editor (edit values, preview, print)
- http://localhost:8080/sets - LabelSet list (create from template, batch labels)
- http://localhost:8080/set/{uuid} - LabelSet editor (spreadsheet, preview, batch print)

### Service Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│ Caddy                                                                     │
│   :80  (FrostByte)                                                        │
│     /              → Elm SPA (static files from frostbyte_client_dist)    │
│     /api/db/*      → PostgREST (:3000) [Accept-Profile: frostbyte_api]   │
│     /api/assets/*  → VersityGW (:7070) [→ /frostbyte-assets/*]           │
│     /api/printer/* → Printer Service (:8000)                              │
│   :8080 (LabelMaker)                                                      │
│     /              → Elm SPA (static files from labelmaker_client_dist)   │
│     /api/db/*      → PostgREST (:3000) [Accept-Profile: labelmaker_api]  │
│     /api/assets/*  → VersityGW (:7070) [→ /labelmaker-assets/*]          │
│     /api/printer/* → Printer Service (:8000)                              │
└──────────────────────────────────────────────────────────────────────────┘
│ VersityGW (:7070) → S3-compatible object storage (POSIX backend)          │
│ storage_init (one-shot) → Creates buckets and sets public policies        │
│ frostbyte_db_migrator (one-shot) → FrostByte migrations, then exits       │
│ labelmaker_db_migrator (one-shot) → LabelMaker migrations, then exits     │
│ GoBackup (:2703) → Web UI for backup management                           │
└──────────────────────────────────────────────────────────────────────────┘
```

**Startup order:** `postgres` (healthy) → `frostbyte_db_migrator` + `labelmaker_db_migrator` (run + exit) → `postgrest`; `storage` (healthy) → `storage_init` (run + exit) → `caddy`

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

Both modes use named volumes (`frostbyte_client_node_modules`, `labelmaker_client_node_modules`) for faster dependency handling.

### Production Workflow (Raspberry Pi)
- Pi pulls pre-built image from `ghcr.io/nilp0inter/frostbyte-client:latest`
- `docker-compose.prod.yml` overrides command to `cp -r /dist/* /output/`
- **Pi never runs Elm** - just copies pre-built static files to volume
- Caddy serves static files from shared volume

### Key Files
- `apps/frostbyte/client/Dockerfile` - FrostByte multi-stage: builder (Node+Elm) -> final (Alpine+static)
- `apps/labelmaker/client/Dockerfile` - LabelMaker multi-stage: builder (Node+Elm) -> final (Alpine+static)
- `docker-compose.yml` - Base config (uses `target: builder`)
- `docker-compose.dev.yml` - Dev overlay (Vite HMR, hot reloading)
- `docker-compose.prod.yml` - Prod overrides (uses pre-built images)
- `common/gateway/Caddyfile` - Production Caddyfile (serves static files on :80 and :8080)
- `common/gateway/Caddyfile.dev` - Dev Caddyfile (proxies to Vite on :80 and :8080)
- `.github/workflows/build-client.yml` - FrostByte client CI pipeline
- `.github/workflows/build-labelmaker-client.yml` - LabelMaker client CI pipeline
- `.github/workflows/build-printer.yml` - Printer service CI pipeline
- `docker-compose.secrets.yml` - Maps SOPS secrets to service environments
- `common/storage/migrate-images.sh` - One-time migration: base64 event payloads → VersityGW
- `deploy/bootstrap.yml` - Ansible playbook: provision fresh Pi
- `deploy/deploy.yml` - Ansible playbook: routine deployment
- `deploy/restore.yml` - Ansible playbook: disaster recovery data restore
- `deploy/templates/kitchen.service.j2` - Systemd service unit template
- `Taskfile.yml` - Task runner entry points (bootstrap, deploy, restore)
- `flake.nix` - Nix dev shell (ansible, sops, go-task)

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

Deployment is automated via Ansible. From the dev machine:
```bash
task deploy
```

The systemd service (`kitchen.service`) handles SOPS decryption and docker compose orchestration automatically. For manual deployment (if needed):
```bash
cd ~/KitchenStack
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
2. Add new variable: `KITCHEN_NEW_SECRET=value`
3. Update `docker-compose.secrets.yml` to use `${KITCHEN_NEW_SECRET}`
4. Commit both files

### Current Secrets
- `KITCHEN_POSTGRES_PASSWORD` - PostgreSQL password
- `KITCHEN_B2_BUCKET` - Backblaze B2 bucket name
- `KITCHEN_B2_REGION` - B2 region (e.g., `us-west-002`)
- `KITCHEN_B2_ENDPOINT` - B2 S3-compatible endpoint (e.g., `https://s3.us-west-002.backblazeb2.com`)
- `KITCHEN_B2_KEY_ID` - B2 application key ID
- `KITCHEN_B2_APP_KEY` - B2 application key
- `KITCHEN_HEALTHCHECKS_URL` - Healthchecks.io ping URL
- `KITCHEN_STORAGE_ACCESS_KEY` - VersityGW admin access key
- `KITCHEN_STORAGE_SECRET_KEY` - VersityGW admin secret key

## Database Backups

Uses [GoBackup](https://gobackup.github.io/) for automated PostgreSQL backups to Backblaze B2 with Healthchecks.io monitoring.

### Configuration
- **Schedule**: Daily at 3:00 AM
- **Retention**: 30 days (managed by B2 lifecycle rules)
- **Storage**: Backblaze B2 (S3-compatible)
- **Includes**: PostgreSQL dump, CSV event exports, VersityGW asset files (frostbyte-assets, labelmaker-assets)
- **Monitoring**: Healthchecks.io ping on success/failure

### Key Files
- `common/backup/gobackup.yml` - GoBackup configuration (uses env vars for secrets)
- `docker-compose.secrets.yml` - Maps SOPS secrets to gobackup environment

### Web UI
Access backup status at: `http://KitchenLabelPrinter.local:2703/`

### Manual Backup
```bash
docker exec kitchen_gobackup gobackup perform kitchen_db
```

### CSV Event Backup

In addition to PostgreSQL dumps, GoBackup exports event tables from all apps as CSV files via `psql COPY`. Since all apps use event sourcing, state can be rebuilt from the event tables alone.

**How it works:**
- `common/backup/event-backup.sh` runs as a `before_script` in GoBackup
- Loops over all apps (frostbyte, labelmaker), dumping each `<app>_data.event` table as CSV
- Saves to `/data/json/frostbyte_events.csv` and `/data/json/labelmaker_events.csv`
- CSV is portable — no schema/role names embedded in the data

**Key files:**
- `common/backup/event-backup.sh` - CSV backup script (runs inside gobackup container)
- `common/backup/event-restore.sh` - CSV restore script (runs from dev machine or Pi)
- `common/backup/Dockerfile` - Custom gobackup image with psql and scripts baked in

### Backup Archive Structure

GoBackup produces a `.tar.gz` archive (e.g., `kitchen_2026.02.19.21.46.38.tar.gz`) with a nested structure:

```
kitchen_<timestamp>.tar.gz
└── kitchen_db/
    ├── postgresql/
    │   └── postgresql/
    │       └── kitchen_db.sql        # Full PostgreSQL dump
    └── archive.tar                   # Nested tar with CSV exports + assets
        └── data/
            ├── json/
            │   ├── frostbyte_events.csv
            │   └── labelmaker_events.csv
            └── storage/
                ├── frostbyte-assets/  # Uploaded images (FrostByte)
                └── labelmaker-assets/ # Uploaded images (LabelMaker)
```

To extract the CSV files:
```bash
tar xzf kitchen_*.tar.gz
tar xf kitchen_db/archive.tar
# CSVs are now at data/json/frostbyte_events.csv and data/json/labelmaker_events.csv
```

### Restoring from CSV Event Backup

To restore data from a CSV event backup (e.g., after wiping the database):

```bash
# Using Ansible (from dev machine, handles SCP + restore on Pi):
task restore FROSTBYTE_CSV=/path/to/frostbyte_events.csv
task restore FROSTBYTE_CSV=/path/to/frostbyte.csv LABELMAKER_CSV=/path/to/labelmaker.csv

# Manual (must run on same machine as containers):
./common/backup/event-restore.sh frostbyte /path/to/backup/data/json/frostbyte_events.csv
./common/backup/event-restore.sh labelmaker /path/to/backup/data/json/labelmaker_events.csv
```

The manual restore script uses `docker exec` so it must run on the same machine as the containers. For remote restore, use `task restore` or SCP the CSV to the Pi first.

### Migrating from Old (Pre-Event-Sourcing) Backup

```bash
./apps/frostbyte/database/migrate-from-json.py /path/to/old/backup/data/json > events.sql
docker exec -i kitchen_postgres psql -U kitchen_user -d kitchen_db < events.sql
```

## Language Notes

- UI is in Spanish (expiry label: "Caduca:", food categories like "Arroz", "Pollo", etc.)
