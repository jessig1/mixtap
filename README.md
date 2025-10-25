# Vinylhound

A comprehensive music discovery and cataloging platform built with Go, React, and PostgreSQL.

## Quick Start

```bash
# 1. Clone the repository
git clone <repository-url>
cd vinylhound

# 2. Start all services
make start

# 3. Open your browser
# Frontend: http://localhost:5173
# Backend API: http://localhost:8080
```

That's it! The application stack (database, backend, frontend) is now running.

## Project Structure

```
vinylhound/
├── Vinylhound-Backend/        # Go backend API
│   ├── cmd/                   # Application entrypoints
│   ├── internal/              # Private application code
│   ├── migrations/            # Database migrations
│   ├── shared/                # Shared libraries
│   ├── docs/                  # Backend documentation
│   └── README.md
│
├── vinylhound-frontend/       # React frontend
│   ├── src/                   # Source code
│   ├── public/                # Static assets
│   └── package.json
│
├── Vinylhound-Infrastructure/ # Docker orchestration
│   ├── cmd/gateway/           # API Gateway
│   ├── shared/                # Shared Go libraries
│   ├── db/                    # Database schemas
│   ├── docker-compose.yml     # Service orchestration
│   └── README.md
│
├── scripts/                   # Development scripts
│   ├── vinylhound.sh         # Main development CLI
│   ├── setup-db.sh           # Database setup script
│   └── README.md             # Scripts documentation
│
├── Makefile                   # Build and development tasks
└── README.md                  # This file
```

## Tech Stack

### Backend
- **Language:** Go 1.23
- **Framework:** Standard library + custom HTTP handlers
- **Database:** PostgreSQL 16
- **Authentication:** Session-based with bcrypt
- **Logging:** Zerolog for structured logging

### Frontend
- **Framework:** React 18
- **Build Tool:** Vite
- **Language:** JavaScript/TypeScript
- **Styling:** CSS Modules / Tailwind (check package.json)

### Infrastructure
- **Containerization:** Docker & Docker Compose
- **Database:** PostgreSQL 16 (Alpine)
- **Reverse Proxy:** Custom Go-based API Gateway

## Features

- **User Management:** Registration, login, session management
- **Album Catalog:** Browse and search music albums
- **Ratings & Reviews:** Rate albums and write reviews
- **User Preferences:** Mark albums as favorites
- **Playlists:** Create and manage music playlists
- **RESTful API:** Well-structured API with versioning
- **Database Migrations:** Version-controlled schema changes
- **Structured Logging:** Production-ready observability
- **Health Checks:** Service health monitoring

## Development

### Prerequisites

- [Go 1.23+](https://golang.org/dl/)
- [Node.js 18+](https://nodejs.org/)
- [Docker](https://www.docker.com/get-started)
- [Make](https://www.gnu.org/software/make/) (optional, but recommended)

### First Time Setup

```bash
# 1. Install dependencies
make deps

# 2. Setup environment files
cd Vinylhound-Backend
cp .env.example .env
# Edit .env and set required variables

cd ../Vinylhound-Infrastructure
cp .env.example .env
# Edit .env and set required variables:
#   - POSTGRES_PASSWORD
#   - DB_PASSWORD
#   - JWT_SECRET (generate with: openssl rand -base64 32)

# 3. Start everything
cd ..
make start
```

### Common Commands

```bash
# Start all services
make start              # or: ./scripts/vinylhound.sh start

# Check service status
make status             # or: ./scripts/vinylhound.sh status

# View logs
make logs               # or: ./scripts/vinylhound.sh logs
make logs-backend       # Backend logs only
make logs-frontend      # Frontend logs only

# Stop all services
make stop               # or: ./scripts/vinylhound.sh stop

# Restart services
make restart            # or: ./scripts/vinylhound.sh restart

# Run tests
make test               # All tests
make test-backend       # Backend tests only
make test-frontend      # Frontend tests only

# Database operations
make db-migrate         # Run migrations
make db-reset           # Reset database (DESTROYS DATA!)
make shell-db           # Connect to PostgreSQL

# Code quality
make lint               # Run linters
make format             # Format code

# Build
make build              # Build all services
make build-backend      # Backend only
make build-frontend     # Frontend only

# Docker
make docker-build       # Build Docker images
make docker-up          # Start with Docker Compose
make docker-down        # Stop Docker services

# Cleanup
make clean              # Remove build artifacts
make clean-all          # Deep clean (includes node_modules)
```

For the complete list of commands:
```bash
make help
# or
./scripts/vinylhound.sh help
```

## Service URLs

| Service | URL | Description |
|---------|-----|-------------|
| Frontend | http://localhost:5173 | React frontend (Vite dev server) |
| Frontend (alt) | http://localhost:3000 | Alternative port (if 5173 fails) |
| Backend API | http://localhost:8080 | Go backend API |
| API Gateway | http://localhost:8080 | API Gateway (reverse proxy) |
| Database | localhost:54320 | PostgreSQL database |

## API Endpoints

### Public Endpoints (No Authentication)

- `GET /health` - Health check
- `POST /api/v1/auth/signup` - User registration
- `POST /api/v1/auth/login` - User login
- `GET /api/v1/albums` - Browse albums
- `GET /api/v1/artists` - Browse artists
- `GET /api/v1/songs` - Browse songs

### Protected Endpoints (Authentication Required)

- `GET /api/v1/users` - User management
- `GET /api/v1/me` - Current user profile
- `POST /api/v1/albums` - Create album
- `PUT /api/v1/albums/:id` - Update album
- `DELETE /api/v1/albums/:id` - Delete album
- `GET /api/v1/ratings` - Get ratings
- `POST /api/v1/ratings` - Create rating
- `GET /api/v1/reviews` - Get reviews
- `POST /api/v1/reviews` - Create review
- `GET /api/v1/preferences` - Get preferences
- `POST /api/v1/preferences` - Update preferences
- `GET /api/v1/playlists` - Get playlists
- `POST /api/v1/playlists` - Create playlist

For detailed API documentation, see [Vinylhound-Backend/README.md](Vinylhound-Backend/README.md).

## Database

### Connection String

```
postgresql://vinylhound:localpassword@localhost:54320/vinylhound?sslmode=disable
```

### Migrations

Migrations are stored in `Vinylhound-Backend/migrations/` and follow the naming convention:

```
NNNN_description.up.sql    # Apply migration
NNNN_description.down.sql  # Rollback migration
```

**Run migrations:**
```bash
make db-migrate
```

**Rollback migrations:**
```bash
make migrate-down
```

**Reset database (DESTROYS ALL DATA):**
```bash
make db-reset
```

### Schema

The database includes the following tables:

- `users` - User accounts
- `sessions` - Authentication sessions
- `user_content` - User content preferences
- `albums` - Album catalog
- `artists` - Artist information
- `songs` - Song catalog
- `user_album_preferences` - User ratings and favorites
- `ratings` - Album ratings
- `reviews` - Album reviews
- `playlists` - User playlists
- `playlist_items` - Playlist contents

## Configuration

### Environment Variables

Both Backend and Infrastructure require `.env` files. See `.env.example` in each directory.

**Required Variables:**
- `POSTGRES_PASSWORD` - Database password
- `DB_PASSWORD` - Database password (same as above)
- `JWT_SECRET` - Secret key for JWT signing (generate with `openssl rand -base64 32`)

**Optional Variables:**
- `PORT` - Service port (default varies by service)
- `LOG_LEVEL` - Logging level (debug, info, warn, error)
- `LOG_FORMAT` - Log format (json, text)
- `CORS_ALLOWED_ORIGINS` - Allowed CORS origins
- `DB_SSLMODE` - Database SSL mode (disable, require, verify-full)

See [.env.example](Vinylhound-Backend/.env.example) and [Infrastructure .env.example](Vinylhound-Infrastructure/.env.example) for complete lists.

## Testing

```bash
# Run all tests
make test

# Run with coverage
make test-coverage

# Run backend tests only
cd Vinylhound-Backend
go test ./...

# Run frontend tests only
cd vinylhound-frontend
npm test
```

## Deployment

### Docker Compose (Recommended for Production)

```bash
# Build images
make docker-build

# Start all services
cd Vinylhound-Infrastructure
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f

# Stop services
docker compose down
```

### Manual Deployment

See component-specific READMEs:
- [Backend Deployment](Vinylhound-Backend/README.md#deployment)
- [Infrastructure Deployment](Vinylhound-Infrastructure/README.md#deployment)

## Troubleshooting

### Services won't start

1. **Check dependencies:**
   ```bash
   go version
   node --version
   docker --version
   ```

2. **Check .env files exist:**
   ```bash
   ls Vinylhound-Backend/.env
   ls Vinylhound-Infrastructure/.env
   ```

3. **Check if ports are in use:**
   ```bash
   # On Linux/Mac
   lsof -i :8080
   lsof -i :5173
   lsof -i :54320

   # On Windows
   netstat -ano | findstr :8080
   ```

### Database connection errors

```bash
# Check if database is running
docker ps | grep vinylhound-db

# Check database logs
docker logs vinylhound-db

# Reset database
make db-reset
```

### Services running but not responding

```bash
# Check logs
make logs

# Check status
make status

# Restart services
make restart
```

### Frontend not hot-reloading

```bash
# Stop frontend
./scripts/vinylhound.sh frontend:stop

# Start frontend again
./scripts/vinylhound.sh frontend:start
```

For more troubleshooting, see [scripts/README.md](scripts/README.md#troubleshooting).

## Architecture

Vinylhound uses a **monolithic architecture** with a microservices-ready structure:

```
┌─────────────────────────────────────────────────────────────────┐
│                    FRONTEND (React + Vite)                      │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTP/REST
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│              API GATEWAY (Go Reverse Proxy)                     │
│  - Authentication validation                                    │
│  - CORS handling                                                │
│  - Request routing                                              │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   BACKEND API (Go)                              │
│  - User management                                              │
│  - Album catalog                                                │
│  - Ratings & reviews                                            │
│  - Playlists                                                    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                  DATABASE (PostgreSQL)                          │
│  - User data                                                    │
│  - Music catalog                                                │
│  - Ratings & preferences                                        │
└─────────────────────────────────────────────────────────────────┘
```

For detailed architecture documentation:
- [Backend Architecture](Vinylhound-Backend/docs/ARCHITECTURE.md)
- [Infrastructure Overview](Vinylhound-Infrastructure/README.md#architecture)

## Security

### Development

- Database password: `localpassword` (change in `.env`)
- JWT secret: Set in `.env` (generate with `openssl rand -base64 32`)
- SSL/TLS: Disabled by default for development

### Production

Before deploying to production:

1. **Change all credentials:**
   ```bash
   # Generate secure database password
   openssl rand -base64 32

   # Generate JWT secret
   openssl rand -base64 32
   ```

2. **Update environment variables:**
   - Set `ENV=production`
   - Set `DB_SSLMODE=require` or `verify-full`
   - Set `LOG_LEVEL=warn` or `error`
   - Update `CORS_ALLOWED_ORIGINS` to production domains

3. **Use secrets management:**
   - Kubernetes Secrets
   - Docker Secrets
   - AWS Secrets Manager / GCP Secret Manager / Azure Key Vault

See [Vinylhound-Infrastructure/README.md](Vinylhound-Infrastructure/README.md#security) for more details.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Format code (`make format`)
5. Run tests (`make test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Code Style

- **Go:** Follow standard Go conventions (`gofmt`, `golangci-lint`)
- **JavaScript/React:** Follow Airbnb style guide
- **Commit Messages:** Use conventional commits format

## Documentation

- [Main README](README.md) - This file
- [Backend README](Vinylhound-Backend/README.md) - Backend documentation
- [Infrastructure README](Vinylhound-Infrastructure/README.md) - Infrastructure docs
- [Scripts README](scripts/README.md) - Development scripts guide
- [Architecture](Vinylhound-Backend/docs/ARCHITECTURE.md) - System architecture
- [Migration Guide](Vinylhound-Backend/docs/MIGRATION_GUIDE.md) - Upgrade guide

## License

[Add license information]

## Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/vinylhound/issues)
- **Documentation:** See `/docs` in each component
- **Email:** support@yourdomain.com

## Roadmap

- [ ] Add Redis caching layer
- [ ] Implement search with Elasticsearch
- [ ] Add social features (follow users, share playlists)
- [ ] Mobile app (React Native)
- [ ] Spotify/Apple Music integration
- [ ] Machine learning recommendations
- [ ] GraphQL API
- [ ] WebSocket support for real-time updates
- [ ] Admin dashboard
- [ ] Analytics and metrics

---

**Built with ❤️ by the Vinylhound Team**

**Last Updated:** 2025-10-24
