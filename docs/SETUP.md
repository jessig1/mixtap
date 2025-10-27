# Vinylhound Monorepo Setup Guide

## 🎯 **Dependencies Fixed!**

All backend services are now properly configured and building successfully. Here's how to get everything running:

## Prerequisites

- **Go 1.21+** - [Download here](https://golang.org/dl/)
- **Node.js 18+** - [Download here](https://nodejs.org/)
- **PostgreSQL 16+** - [Download here](https://www.postgresql.org/download/)
- **Docker & Docker Compose** (optional, for containerized setup)

## Quick Start

### 1. Database Setup

First, start PostgreSQL and create the database:

```sql
-- Connect to PostgreSQL and run:
CREATE DATABASE vinylhound;
CREATE USER vinylhound WITH PASSWORD 'localpassword';
GRANT ALL PRIVILEGES ON DATABASE vinylhound TO vinylhound;
```

### 2. Run Database Migrations

```bash
# Navigate to the project root
cd vinylhound

# Run the database schema
psql -h localhost -U vinylhound -d vinylhound -f Vinylhound-Infrastructure/db/schema.sql
```

### 3. Start All Services

#### Option A: Using PowerShell Script (Windows)
```powershell
# Run the start script
.\scripts\start-services.ps1
```

#### Option B: Using Bash Script (Linux/Mac)
```bash
# Make script executable and run
chmod +x scripts/start-services.sh
./scripts/start-services.sh
```

#### Option C: Manual Start
```bash
# Terminal 1 - User Service
cd Vinylhound-Backend/services/user-service
go run ./cmd/main.go

# Terminal 2 - Catalog Service  
cd Vinylhound-Backend/services/catalog-service
go run ./cmd/main.go

# Terminal 3 - Rating Service
cd Vinylhound-Backend/services/rating-service
go run ./cmd/main.go

# Terminal 4 - Web Frontend
cd vinylhound-frontend
npm install
npm run dev
```

### 4. Test Services

```powershell
# Test all services
.\scripts\test-services.ps1
```

## Service Endpoints

Once running, your services will be available at:

- **User Service**: http://localhost:8001
  - Health: `GET /health`
  - Auth: `POST /api/v1/auth/signup`, `POST /api/v1/auth/login`
  - Users: `GET /api/v1/users/profile`

- **Catalog Service**: http://localhost:8002
  - Health: `GET /health`
  - Albums: `GET /api/v1/albums`, `GET /api/v1/albums/{id}`
  - Artists: `GET /api/v1/artists`, `GET /api/v1/artists/{id}`
  - Songs: `GET /api/v1/songs`, `GET /api/v1/songs/{id}`

- **Rating Service**: http://localhost:8003
  - Health: `GET /health`
  - Ratings: `GET /api/v1/ratings`, `POST /api/v1/ratings`
  - Reviews: `GET /api/v1/reviews`, `POST /api/v1/reviews`
  - Preferences: `GET /api/v1/preferences`

- **Web Frontend**: http://localhost:3000
  - Svelte application with API integration

## Development Commands

### Build All Services
```bash
make build
```

### Run Tests
```bash
make test
```

### Clean Build Artifacts
```bash
make clean
```

### Database Operations
```bash
# Run migrations
make migrate-up

# Rollback migrations  
make migrate-down
```

## Docker Setup (Alternative)

If you prefer containerized development:

```bash
# Start infrastructure
docker-compose -f Vinylhound-Infrastructure/docker-compose.yml up -d postgres

# Wait for database to be ready, then run migrations
make migrate-up

# Start all services with Docker
docker-compose -f Vinylhound-Infrastructure/docker-compose.yml up
```

## Troubleshooting

### Common Issues

1. **Database Connection Errors**
   - Ensure PostgreSQL is running
   - Check database credentials in environment variables
   - Verify database exists and user has proper permissions

2. **Port Already in Use**
   - Check if services are already running: `netstat -an | findstr :8001`
   - Kill existing processes or change ports in service configs

3. **Go Module Issues**
   - Run `go mod tidy` in each service directory
   - Ensure shared library path is correct

4. **Node.js Issues**
   - Run `npm install` in the vinylhound-frontend directory
   - Check Node.js version compatibility

### Environment Variables

Set these environment variables if needed:

```bash
# Database
export DB_HOST=localhost
export DB_PORT=54320
export DB_USER=vinylhound
export DB_PASSWORD=localpassword
export DB_NAME=vinylhound
export DB_SSLMODE=disable

# Service Ports
export USER_SERVICE_PORT=8001
export CATALOG_SERVICE_PORT=8002
export RATING_SERVICE_PORT=8003
export FRONTEND_PORT=3000
```

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Service   │    │ Catalog Service │    │ Rating Service  │
│   Port: 8001     │    │   Port: 8002    │    │   Port: 8003    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Web Frontend   │
                    │   Port: 3000    │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │   PostgreSQL    │
                    │   Port: 5432    │
                    └─────────────────┘
```

## Next Steps

1. **Test the APIs** using the test script or Postman
2. **Explore the codebase** - each service is self-contained
3. **Add new features** following the established patterns
4. **Deploy to production** using the Docker setup

## Support

If you encounter any issues:

1. Check the service logs for error messages
2. Verify all dependencies are installed
3. Ensure database is accessible
4. Test individual services one by one

The monorepo is now fully functional and ready for development! 🚀
