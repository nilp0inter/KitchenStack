# FrostByte

A home freezer management system for organizing frozen food portions, generating QR code labels, and managing inventory.

## Features

- Track frozen food items with expiry dates
- Automatic expiry date calculation based on food category
- Generate and print QR code labels for Brother QL printers
- PWA support for mobile access
- Spanish language interface

## Architecture

FrostByte uses a microservices architecture:

- **PostgreSQL**: Data persistence
- **PostgREST**: Automatic REST API from database schema
- **Printer Service**: Python FastAPI for label generation
- **Caddy**: Reverse proxy and static file server
- **Elm PWA**: Single-page application frontend

## Quick Start

### Prerequisites

- Docker and Docker Compose

### Running

```bash
# Start all services
docker-compose up --build

# Access the application
open http://localhost
```

### Development

For local development of the Elm client:

```bash
cd client
npm install
npm run dev
```

## Project Structure

```
FrostByte/
├── client/                 # Elm PWA frontend
│   ├── src/
│   │   ├── Main.elm       # Main Elm application
│   │   ├── main.js        # JavaScript entry point
│   │   └── main.css       # Tailwind CSS
│   ├── public/
│   │   └── manifest.json  # PWA manifest
│   ├── elm.json
│   ├── package.json
│   ├── vite.config.js
│   └── tailwind.config.js
├── database/
│   ├── schema.sql         # Database schema
│   └── seed.sql           # Initial data
├── gateway/
│   └── Caddyfile          # Caddy configuration
├── printer_service/
│   ├── app/
│   │   └── main.py        # FastAPI application
│   ├── requirements.txt
│   └── Dockerfile
├── docker-compose.yml
└── README.md
```

## API Endpoints

### PostgREST (via `/api/db/`)

- `GET /api/db/category` - List all categories
- `GET /api/db/container_type` - List all container types
- `GET /api/db/inventory_item` - List inventory items
- `POST /api/db/inventory_item` - Create new item
- `PATCH /api/db/inventory_item?id=eq.{uuid}` - Update item

### Printer Service (via `/api/printer/`)

- `GET /api/printer/health` - Health check
- `POST /api/printer/print` - Print a label

## Configuration

### Environment Variables

| Variable | Service | Default | Description |
|----------|---------|---------|-------------|
| `DRY_RUN` | printer_service | `true` | Save labels as PNG instead of printing |
| `APP_HOST` | printer_service | `localhost` | Hostname for QR code URLs |
| `PRINTER_MODEL` | printer_service | `QL-700` | Brother printer model |
| `PRINTER_TAPE` | printer_service | `62` | Label tape width in mm |

### Dry Run Mode

By default, the printer service runs in dry-run mode and saves label images to `/app/labels_output` instead of sending them to a physical printer.

To enable actual printing, set `DRY_RUN=false` in the docker-compose.yml.

## Data Model

### Categories

Food categories with freezer shelf life in days:

| Category | Safe Days |
|----------|-----------|
| Arroz | 120 |
| Pescado | 180 |
| Marisco | 180 |
| Ternera | 365 |
| Pollo | 365 |
| Cerdo | 365 |
| Guiso | 365 |
| Legumbres | 365 |
| Verdura | 365 |
| Salsa | 365 |
| Postre | 90 |

### Container Types

Various container options with their serving sizes.

## License

MIT
