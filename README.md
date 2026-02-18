# Kitchen Management Stack

A monorepo of kitchen management apps sharing a common infrastructure (PostgreSQL, PostgREST, Caddy, label printer).

## Apps

- **FrostByte** (`:80`) — Home freezer management: track frozen food portions, generate QR code labels, manage inventory with automatic expiry dates
- **LabelMaker** (`:8080`) — Label template designer & library

## Architecture

All apps use CQRS + Event Sourcing with a shared PostgreSQL instance (`kitchen_db`). Each app has isolated schemas (`<app>_data`, `<app>_logic`, `<app>_api`). PostgREST exposes the API schemas, and Caddy pins each app to its own schema via port-based routing.

## Quick Start

### Prerequisites

- Docker and Docker Compose

### Running

```bash
# Start all services
docker compose up --build -d

# Access apps
open http://localhost       # FrostByte
open http://localhost:8080  # LabelMaker
```

### Development

For local development with hot reloading:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

## Project Structure

```
FrostByte/
├── common/                        # Shared infrastructure
│   ├── gateway/                   # Caddy reverse proxy
│   │   ├── Caddyfile              # Production config
│   │   └── Caddyfile.dev          # Dev config (Vite proxy)
│   ├── printer_service/           # Python FastAPI label printer
│   └── backup/                    # GoBackup config + scripts
├── apps/
│   ├── frostbyte/                 # Freezer management app (:80)
│   │   ├── client/                # Elm PWA frontend
│   │   ├── database/              # SQL schemas, migrations, seed data
│   │   └── CLAUDE.md              # App-specific docs
│   └── labelmaker/                # Label template designer (:8080)
│       ├── client/                # Elm SPA frontend
│       ├── database/              # SQL schemas, migrations, seed data
│       └── CLAUDE.md              # App-specific docs
├── docker-compose.yml             # Base config
├── docker-compose.dev.yml         # Dev overlay (Vite HMR)
├── docker-compose.prod.yml        # Prod overrides (pre-built images)
├── docker-compose.secrets.yml     # SOPS secrets mapping
├── CLAUDE.md                      # Monorepo-level docs
└── README.md
```

## Shared Services

| Service | Container | Purpose |
|---------|-----------|---------|
| PostgreSQL | `kitchen_postgres` | Shared database (`kitchen_db`) |
| PostgREST | `kitchen_postgrest` | REST API from database schemas |
| Caddy | `kitchen_caddy` | Reverse proxy, static files |
| Printer | `kitchen_printer` | Brother QL label printing |
| GoBackup | `kitchen_gobackup` | Automated backups to B2 |

## API Endpoints

### PostgREST (via `/api/db/`)

- FrostByte: batch management, ingredient/recipe CRUD, portion tracking
- LabelMaker: label template management

### Printer Service (via `/api/printer/`)

- `GET /api/printer/health` — Health check
- `POST /api/printer/print` — Print a label (base64 PNG)

## License

MIT
