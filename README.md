# FrostByte

A home freezer management system for organizing frozen food portions, generating QR code labels, and managing inventory. Part of the Kitchen Management Stack monorepo.

## Features

- Track frozen food items with expiry dates
- Automatic expiry date calculation based on food category
- Generate and print QR code labels for Brother QL printers
- PWA support for mobile access
- Spanish language interface

## Architecture

FrostByte uses a microservices architecture with CQRS + Event Sourcing:

- **PostgreSQL**: Data persistence (shared `kitchen_db` instance)
- **PostgREST**: Automatic REST API from database schema
- **Printer Service**: Python FastAPI for label printing
- **Caddy**: Reverse proxy and static file server
- **Elm PWA**: Single-page application frontend

## Quick Start

### Prerequisites

- Docker and Docker Compose

### Running

```bash
# Start all services
docker compose up --build -d

# Access the application
open http://localhost
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
│   │   ├── app/main.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   └── backup/                    # GoBackup config + scripts
│       ├── gobackup.yml
│       ├── json-backup.sh
│       ├── json-restore.sh
│       └── Dockerfile
├── apps/
│   └── frostbyte/                 # Freezer management app
│       ├── client/                # Elm PWA frontend
│       │   ├── src/
│       │   │   ├── Main.elm
│       │   │   ├── main.js
│       │   │   └── main.css
│       │   ├── public/
│       │   │   └── manifest.json
│       │   ├── elm.json
│       │   ├── package.json
│       │   ├── vite.config.js
│       │   └── tailwind.config.js
│       ├── database/
│       │   ├── migrations/        # Persistent schema migrations
│       │   ├── logic.sql          # Business logic (idempotent)
│       │   ├── api.sql            # API views + RPCs (idempotent)
│       │   └── seed.sql           # Initial data
│       └── CLAUDE.md              # App-specific docs
├── docker-compose.yml
├── docker-compose.dev.yml
├── docker-compose.prod.yml
├── docker-compose.secrets.yml
├── CLAUDE.md                      # Monorepo-level docs
└── README.md
```

## API Endpoints

### PostgREST (via `/api/db/`)

- `GET /api/db/ingredient` - List all ingredients
- `GET /api/db/container_type` - List all container types
- `GET /api/db/batch_summary` - List inventory items
- `POST /api/db/rpc/create_batch` - Create new batch
- `POST /api/db/rpc/consume_portion` - Consume a portion

### Printer Service (via `/api/printer/`)

- `GET /api/printer/health` - Health check
- `POST /api/printer/print` - Print a label

## License

MIT
