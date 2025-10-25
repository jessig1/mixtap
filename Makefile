# Vinylhound Monorepo Makefile
#
# This Makefile provides convenient shortcuts to the comprehensive
# vinylhound.sh script and additional development tools.
#
# For full functionality, use: ./scripts/vinylhound.sh <command>

.PHONY: help start stop restart status logs test build clean lint format docker-build docker-push

# ============================================================================
# PRIMARY COMMANDS (delegate to vinylhound.sh)
# ============================================================================

help:
	@./scripts/vinylhound.sh help

start:
	@./scripts/vinylhound.sh start

stop:
	@./scripts/vinylhound.sh stop

restart:
	@./scripts/vinylhound.sh restart

status:
	@./scripts/vinylhound.sh status

logs:
	@./scripts/vinylhound.sh logs

logs-backend:
	@./scripts/vinylhound.sh logs backend

logs-frontend:
	@./scripts/vinylhound.sh logs frontend

# ============================================================================
# DATABASE COMMANDS
# ============================================================================

db-migrate:
	@./scripts/vinylhound.sh db:migrate

db-reset:
	@./scripts/vinylhound.sh db:reset

migrate-up: db-migrate

migrate-down:
	@echo "Rolling back database migrations..."
	@cd Vinylhound-Backend && DATABASE_URL="postgresql://vinylhound:localpassword@localhost:54320/vinylhound?sslmode=disable" go run cmd/migrate/main.go down

# ============================================================================
# INFRASTRUCTURE COMMANDS
# ============================================================================

infra-start:
	@./scripts/vinylhound.sh infra:start

infra-stop:
	@./scripts/vinylhound.sh infra:stop

infra-up: infra-start

infra-down: infra-stop

# ============================================================================
# SERVICE COMMANDS
# ============================================================================

backend-start:
	@./scripts/vinylhound.sh backend:start

backend-stop:
	@./scripts/vinylhound.sh backend:stop

frontend-start:
	@./scripts/vinylhound.sh frontend:start

frontend-stop:
	@./scripts/vinylhound.sh frontend:stop

# ============================================================================
# BUILD COMMANDS
# ============================================================================

build:
	@echo "Building all services..."
	@cd Vinylhound-Backend && go build -o bin/vinylhound ./cmd/vinylhound
	@cd vinylhound-frontend && npm run build
	@echo "Build complete!"

build-backend:
	@echo "Building backend..."
	@cd Vinylhound-Backend && go build -o bin/vinylhound ./cmd/vinylhound
	@echo "Backend build complete!"

build-frontend:
	@echo "Building frontend..."
	@cd vinylhound-frontend && npm run build
	@echo "Frontend build complete!"

# ============================================================================
# TEST COMMANDS
# ============================================================================

test:
	@echo "Running all tests..."
	@cd Vinylhound-Backend && go test ./...
	@cd vinylhound-frontend && npm test
	@echo "All tests passed!"

test-backend:
	@echo "Running backend tests..."
	@cd Vinylhound-Backend && go test -v ./...

test-frontend:
	@echo "Running frontend tests..."
	@cd vinylhound-frontend && npm test

test-coverage:
	@echo "Running tests with coverage..."
	@cd Vinylhound-Backend && go test -coverprofile=coverage.out ./...
	@cd Vinylhound-Backend && go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: Vinylhound-Backend/coverage.html"

# ============================================================================
# CODE QUALITY COMMANDS
# ============================================================================

lint:
	@echo "Running linters..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		cd Vinylhound-Backend && golangci-lint run; \
	else \
		echo "golangci-lint not installed. Skipping Go linting."; \
	fi
	@cd vinylhound-frontend && npm run lint || echo "Frontend linting failed or not configured"

format:
	@echo "Formatting code..."
	@cd Vinylhound-Backend && go fmt ./...
	@cd vinylhound-frontend && npm run format || echo "Frontend formatting failed or not configured"

fmt: format

# ============================================================================
# DOCKER COMMANDS
# ============================================================================

docker-build:
	@echo "Building Docker images..."
	@cd Vinylhound-Infrastructure && docker compose build
	@echo "Docker images built successfully!"

docker-build-all:
	@echo "Building all Docker images from scratch..."
	@docker build -t vinylhound/backend:latest -f Vinylhound-Backend/Dockerfile Vinylhound-Backend
	@docker build -t vinylhound/frontend:latest vinylhound-frontend/
	@docker build -t vinylhound/gateway:latest -f Vinylhound-Infrastructure/Dockerfile.gateway Vinylhound-Infrastructure
	@echo "All Docker images built!"

docker-push:
	@echo "Pushing Docker images to registry..."
	@docker push vinylhound/backend:latest
	@docker push vinylhound/frontend:latest
	@docker push vinylhound/gateway:latest
	@echo "Images pushed successfully!"

docker-up:
	@echo "Starting all services with Docker Compose..."
	@cd Vinylhound-Infrastructure && docker compose up -d
	@echo "Services started! Check with: make status"

docker-down:
	@echo "Stopping Docker Compose services..."
	@cd Vinylhound-Infrastructure && docker compose down
	@echo "Services stopped!"

docker-logs:
	@cd Vinylhound-Infrastructure && docker compose logs -f

# ============================================================================
# CLEANUP COMMANDS
# ============================================================================

clean:
	@echo "Cleaning build artifacts and temporary files..."
	@rm -rf Vinylhound-Backend/bin/
	@rm -rf Vinylhound-Backend/coverage.out
	@rm -rf Vinylhound-Backend/coverage.html
	@rm -rf vinylhound-frontend/dist/
	@rm -rf vinylhound-frontend/.next/
	@rm -rf .vinylhound-runtime/
	@echo "Clean complete!"

clean-all: clean
	@echo "Removing node_modules and Go module cache..."
	@rm -rf vinylhound-frontend/node_modules/
	@go clean -modcache
	@echo "Deep clean complete!"

# ============================================================================
# DEPENDENCY MANAGEMENT
# ============================================================================

deps:
	@echo "Installing dependencies..."
	@cd Vinylhound-Backend && go mod download
	@cd vinylhound-frontend && npm install
	@echo "Dependencies installed!"

deps-update:
	@echo "Updating dependencies..."
	@cd Vinylhound-Backend && go get -u ./... && go mod tidy
	@cd vinylhound-frontend && npm update
	@echo "Dependencies updated!"

# ============================================================================
# DEVELOPMENT UTILITIES
# ============================================================================

dev: start

dev-quick:
	@echo "Starting development environment (quick mode - no migrations)..."
	@./scripts/vinylhound.sh infra:start
	@./scripts/vinylhound.sh backend:start
	@./scripts/vinylhound.sh frontend:start

shell-db:
	@echo "Connecting to PostgreSQL database..."
	@docker exec -it vinylhound-db psql -U vinylhound -d vinylhound

check:
	@echo "Running health checks..."
	@curl -sf http://localhost:8080/health && echo "✓ Backend is healthy" || echo "✗ Backend is not responding"
	@curl -sf http://localhost:5173 >/dev/null 2>&1 && echo "✓ Frontend is healthy (port 5173)" || \
		curl -sf http://localhost:3000 >/dev/null 2>&1 && echo "✓ Frontend is healthy (port 3000)" || \
		echo "✗ Frontend is not responding"

watch-logs:
	@tail -f .vinylhound-runtime/logs/*.log

# ============================================================================
# SHORTCUTS AND ALIASES
# ============================================================================

up: start
down: stop
ps: status
log: logs

# ============================================================================
# DOCUMENTATION
# ============================================================================

docs:
	@echo "Vinylhound Documentation"
	@echo ""
	@echo "Project Structure:"
	@echo "  Vinylhound-Backend/       - Go backend API"
	@echo "  vinylhound-frontend/      - React frontend"
	@echo "  Vinylhound-Infrastructure/- Docker orchestration"
	@echo "  scripts/                  - Development scripts"
	@echo ""
	@echo "Quick Start:"
	@echo "  make start                - Start all services"
	@echo "  make stop                 - Stop all services"
	@echo "  make logs                 - View logs"
	@echo "  make status               - Check service status"
	@echo ""
	@echo "For detailed help:"
	@echo "  make help                 - Show all commands"
	@echo "  ./scripts/vinylhound.sh help - Show script help"
	@echo ""
	@echo "Documentation files:"
	@echo "  README.md                 - Main project README"
	@echo "  Vinylhound-Backend/README.md"
	@echo "  Vinylhound-Infrastructure/README.md"

.DEFAULT_GOAL := help
