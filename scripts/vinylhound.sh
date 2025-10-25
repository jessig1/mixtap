#!/usr/bin/env bash
#
# Vinylhound Development CLI
#
# Comprehensive script for managing the entire Vinylhound application stack
# in local development mode.
#
# Usage: ./scripts/vinylhound.sh [command] [options]
#

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${ROOT_DIR}/Vinylhound-Backend"
FRONTEND_DIR="${ROOT_DIR}/vinylhound-frontend"
INFRA_DIR="${ROOT_DIR}/Vinylhound-Infrastructure"
RUNTIME_DIR="${ROOT_DIR}/.vinylhound-runtime"
PID_FILE="${RUNTIME_DIR}/pids"
LOG_DIR="${RUNTIME_DIR}/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

check_dependencies() {
    local missing_deps=()

    # Check for required commands
    command -v go >/dev/null 2>&1 || missing_deps+=("go")
    command -v node >/dev/null 2>&1 || missing_deps+=("node")
    command -v npm >/dev/null 2>&1 || missing_deps+=("npm")

    if ! docker compose version >/dev/null 2>&1 && ! docker-compose version >/dev/null 2>&1; then
        missing_deps+=("docker-compose")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install them before continuing."
        exit 1
    fi
}

check_directories() {
    for dir in "$BACKEND_DIR" "$FRONTEND_DIR" "$INFRA_DIR"; do
        if [ ! -d "$dir" ]; then
            log_error "Required directory not found: $dir"
            exit 1
        fi
    done
}

get_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif docker-compose version >/dev/null 2>&1; then
        echo "docker-compose"
    else
        log_error "Neither 'docker compose' nor 'docker-compose' found"
        exit 1
    fi
}

wait_for_db() {
    log_info "Waiting for database to be ready..."
    local max_attempts=60
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker ps | grep -q vinylhound-db; then
            # First check if container is running
            if docker exec vinylhound-db pg_isready -U vinylhound -d vinylhound >/dev/null 2>&1; then
                # Then try a basic query to ensure database is really ready
                if docker exec vinylhound-db psql -U vinylhound -d vinylhound -c "SELECT 1" >/dev/null 2>&1; then
                    log_success "Database is ready and accepting connections"
                    return 0
                fi
            fi
        else
            log_warn "Database container is not running"
        fi
        attempt=$((attempt + 1))
        sleep 1
        echo -n "." # Show progress
    done

    log_error "Database failed to become ready after ${max_attempts} seconds"
    return 1
}

wait_for_service() {
    local service_name=$1
    local url=$2
    local max_attempts=${3:-30}
    local attempt=0
    local delay=${4:-1}  # Delay between attempts in seconds

    log_info "Waiting for $service_name to be ready at $url..."

    while [ $attempt -lt $max_attempts ]; do
        local response
        response=$(curl -s -w "%{http_code}" "$url" 2>&1)
        local status=$?
        local http_code=${response: -3}  # Get last 3 characters (HTTP status code)
        
        if [ $status -eq 0 ] && [ "$http_code" = "200" ]; then
            log_success "$service_name is ready"
            return 0
        elif [ $status -ne 0 ]; then
            log_warn "$service_name connection failed (attempt $((attempt + 1))/$max_attempts)"
        else
            log_warn "$service_name returned HTTP $http_code (attempt $((attempt + 1))/$max_attempts)"
        fi
        
        attempt=$((attempt + 1))
        echo -n "." # Show progress
        sleep "$delay"
    done

    log_error "$service_name did not respond successfully after ${max_attempts} attempts"
    return 1
}

# ============================================================================
# PID MANAGEMENT
# ============================================================================

save_pid() {
    local service=$1
    local pid=$2
    echo "${service}_PID=$pid" >> "$PID_FILE"
}

read_pids() {
    if [ -f "$PID_FILE" ]; then
        # shellcheck disable=SC1090
        source "$PID_FILE"
    fi
}

stop_process() {
    local name=$1
    local pid=$2

    if [ -z "${pid:-}" ]; then
        return
    fi

    if ! kill -0 "$pid" >/dev/null 2>&1; then
        log_warn "$name (PID $pid) is not running"
        return
    fi

    log_info "Stopping $name (PID $pid)..."
    kill "$pid" >/dev/null 2>&1 || true

    # Wait up to 10 seconds for graceful shutdown
    for _ in $(seq 1 20); do
        if ! kill -0 "$pid" >/dev/null 2>&1; then
            log_success "$name stopped gracefully"
            return
        fi
        sleep 0.5
    done

    # Force kill if still running
    if kill -0 "$pid" >/dev/null 2>&1; then
        log_warn "$name did not exit gracefully; sending SIGKILL"
        kill -9 "$pid" >/dev/null 2>&1 || true
    fi
}

# ============================================================================
# INFRASTRUCTURE MANAGEMENT
# ============================================================================

start_infrastructure() {
    local compose_cmd
    compose_cmd=$(get_docker_compose)

    log_info "Starting infrastructure (PostgreSQL, services via Docker)..."

    cd "$INFRA_DIR"

    # Check if .env exists
    if [ ! -f .env ]; then
        log_warn "No .env file found in $INFRA_DIR"
        log_info "Creating .env from .env.example..."

        if [ -f .env.example ]; then
            cp .env.example .env
            log_warn "IMPORTANT: Edit $INFRA_DIR/.env and set required variables:"
            log_warn "  - POSTGRES_PASSWORD"
            log_warn "  - DB_PASSWORD"
            log_warn "  - JWT_SECRET"
            read -p "Press Enter after updating .env to continue..."
        else
            log_error ".env.example not found. Cannot proceed."
            exit 1
        fi
    fi

    # Start all services but in the correct order
    log_info "Starting PostgreSQL..."
    $compose_cmd up -d postgres
    wait_for_db || exit 1

    # Start all services (they have proper dependencies in compose)
    log_info "Starting backend services..."
    $compose_cmd up -d

    # Wait for each service in order
    log_info "Waiting for services to be ready..."

    # Wait for user service
    wait_attempts=30
    while [ $wait_attempts -gt 0 ]; do
        if curl -s -f "http://localhost:8001/health" >/dev/null 2>&1; then
            break
        fi
        wait_attempts=$((wait_attempts - 1))
        [ $wait_attempts -gt 0 ] && sleep 1
    done

    # Wait for API Gateway specifically since frontend depends on it
    log_info "Waiting for API Gateway..."
    gateway_ready=false
    for _ in $(seq 1 30); do
        if curl -s -f "http://localhost:8080/health" >/dev/null 2>&1; then
            gateway_ready=true
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""

    if [ "$gateway_ready" = true ]; then
        log_success "API Gateway is ready at http://localhost:8080"
    else
        log_error "API Gateway failed to start properly"
        log_error "Checking API Gateway logs..."
        docker logs vinylhound-api-gateway
        return 1
    fi

    # Additional verification
    log_info "Verifying API Gateway connectivity..."
    if ! curl -s -f "http://localhost:8080/health" >/dev/null 2>&1; then
        log_error "API Gateway is not responding correctly"
        log_error "Please check the Docker logs and configuration"
        return 1
    fi

    log_success "Infrastructure services started successfully"
}

stop_infrastructure() {
    local compose_cmd
    compose_cmd=$(get_docker_compose)
    local remove_volumes=${1:-false}

    log_info "Stopping infrastructure services..."

    cd "$INFRA_DIR"

    if [ "$remove_volumes" = "true" ]; then
        log_warn "Removing database volumes (ALL DATA WILL BE LOST)"
        $compose_cmd down --volumes --remove-orphans
    else
        $compose_cmd down --remove-orphans
    fi

    log_success "Infrastructure stopped"
}

# ============================================================================
# DATABASE MANAGEMENT
# ============================================================================

run_migrations() {
    log_info "Running database migrations..."

    cd "$BACKEND_DIR"

    # Check if migrations directory exists
    if [ ! -d migrations ]; then
        log_error "Migrations directory not found at $BACKEND_DIR/migrations"
        exit 1
    fi

    # Export environment for migrations
    export DATABASE_URL="postgresql://vinylhound:localpassword@localhost:54320/vinylhound?sslmode=disable"

    # Check if migration tool exists
    if [ -f tools/migrate/main.go ]; then
        go run tools/migrate/main.go up
    elif [ -f cmd/migrate/main.go ]; then
        go run cmd/migrate/main.go up
    else
        log_warn "No migration tool found. Please run migrations manually."
        log_info "You can apply migrations using psql or your preferred tool."
    fi

    log_success "Migrations completed"
}

reset_database() {
    log_warn "This will DESTROY ALL DATA in the database!"
    read -p "Are you sure? Type 'yes' to confirm: " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Database reset cancelled"
        return
    fi

    stop_infrastructure true
    start_infrastructure
    run_migrations

    log_success "Database reset complete"
}

# ============================================================================
# SERVICE MANAGEMENT
# ============================================================================

start_backend() {
    log_info "Starting backend API server..."

    mkdir -p "$LOG_DIR"

    cd "$BACKEND_DIR"

    # Check if .env exists
    if [ ! -f .env ]; then
        log_warn "No .env file found in $BACKEND_DIR"
        if [ -f .env.example ]; then
            cp .env.example .env
            log_info "Created .env from .env.example"
        fi
    fi

    # Start backend
    local backend_log="$LOG_DIR/backend.log"
    nohup go run ./cmd/vinylhound >"$backend_log" 2>&1 &
    local backend_pid=$!

    save_pid "BACKEND" "$backend_pid"

    log_info "Backend started (PID: $backend_pid)"
    log_info "Backend log: $backend_log"

    # Wait for backend to be ready
    wait_for_service "Backend API" "http://localhost:8080/health" 30 || true
}

start_frontend() {
    log_info "Starting frontend development server..."

    mkdir -p "$LOG_DIR"

    cd "$FRONTEND_DIR"

    # Ensure package.json exists
    if [ ! -f package.json ]; then
        log_error "package.json not found in $FRONTEND_DIR"
        exit 1
    fi

    # Install dependencies if needed
    if [ ! -d node_modules ]; then
        log_info "Installing frontend dependencies..."
        npm install
    fi

    # Kill any existing Vite dev servers
    pkill -f "vite.*--host" >/dev/null 2>&1 || true

    npm run dev > "$LOG_DIR/frontend.log" 2>&1 &
    local frontend_pid=$!

    # Wait for frontend to be ready
    log_info "Waiting for frontend to be ready..."
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:5173 >/dev/null 2>&1; then
            log_success "Frontend is ready at http://localhost:5173"
            return 0
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 1
    done

    log_error "Frontend did not respond after ${max_attempts} seconds"
    log_error "You may need to start it manually:"
    log_error "  cd $FRONTEND_DIR && npm run dev -- --host"
    return 1
}


stop_backend() {
    read_pids
    stop_process "Backend" "${BACKEND_PID:-}"
}

stop_frontend() {
    log_info "Stopping frontend services..."

    # Kill any Vite processes
    if pgrep -f "vite.*--host" >/dev/null; then
        log_info "Stopping Vite development server..."
        pkill -f "vite.*--host"
        sleep 2
        if pgrep -f "vite.*--host" >/dev/null; then
            log_warn "Vite server still running, forcing shutdown..."
            pkill -9 -f "vite.*--host"
        fi
    else
        log_info "No Vite development server found running"
    fi

    # Kill any npm run dev processes
    if pgrep -f "npm.*run.*dev" >/dev/null; then
        log_info "Stopping npm processes..."
        pkill -f "npm.*run.*dev"
        sleep 2
        if pgrep -f "npm.*run.*dev" >/dev/null; then
            log_warn "npm processes still running, forcing shutdown..."
            pkill -9 -f "npm.*run.*dev"
        fi
    fi

    # Check if any processes are still listening on port 5173
    if lsof -i :5173 >/dev/null 2>&1; then
        log_warn "Port 5173 still in use, attempting to free it..."
        fuser -k 5173/tcp >/dev/null 2>&1 || true
    fi

    log_success "Frontend stopped"
    return 0
}


# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================

check_environment_files() {
    local missing_files=()
    local env_files=(
        "${INFRA_DIR}/.env"
        "${BACKEND_DIR}/.env"
    )

    for file in "${env_files[@]}"; do
        if [ ! -f "$file" ]; then
            if [ -f "${file}.example" ]; then
                log_warn "Missing $file, creating from example..."
                cp "${file}.example" "$file"
                log_warn "Please review and update $file with your settings"
            else
                missing_files+=("$file")
            fi
        fi
    done

    if [ ${#missing_files[@]} -ne 0 ]; then
        log_error "Missing required environment files: ${missing_files[*]}"
        log_error "Please create these files before starting the services"
        exit 1
    fi
}

# ============================================================================
# COMBINED OPERATIONS
# ============================================================================

start_all() {
    log_info "Starting complete Vinylhound stack..."
    check_environment_files

    check_dependencies
    check_directories

    mkdir -p "$RUNTIME_DIR" "$LOG_DIR"

    # Check if already running
    if [ -f "$PID_FILE" ]; then
        log_error "Services are already running (PID file exists: $PID_FILE)"
        log_error "Run '$0 stop' first, or '$0 restart' to restart services"
        exit 1
    fi

    # Create empty PID file
    > "$PID_FILE"

    # Start infrastructure
    start_infrastructure

    # Run migrations
    run_migrations

    # Start services
    start_backend
    start_frontend

    log_success "All services started successfully!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "Service URLs:"
    echo "  Frontend:     http://localhost:5173 (or http://localhost:3000)"
    echo "  Backend API:  http://localhost:8080"
    echo "  Database:     postgresql://vinylhound@localhost:54320/vinylhound"
    echo ""
    log_info "Logs:"
    echo "  Backend:      $LOG_DIR/backend.log"
    echo "  Frontend:     $LOG_DIR/frontend.log"
    echo ""
    log_info "Commands:"
    echo "  View logs:    $0 logs [backend|frontend|all]"
    echo "  Stop all:     $0 stop"
    echo "  Restart:      $0 restart"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

stop_all() {
    log_info "Stopping all Vinylhound services..."
    local had_errors=false

    # First stop the frontend and backend (they depend on infrastructure)
    if [ -f "$PID_FILE" ]; then
        read_pids
        
        # Stop frontend first as it depends on the backend
        log_info "Stopping frontend services..."
        if stop_frontend; then
            log_success "Frontend stopped successfully"
        else
            log_warn "Frontend stop had issues"
            had_errors=true
        fi
        
        # Then stop backend
        log_info "Stopping backend services..."
        if stop_backend; then
            log_success "Backend stopped successfully"
        else
            log_warn "Backend stop had issues"
            had_errors=true
        fi
        
        rm -f "$PID_FILE"
    else
        log_info "No PID file found; assuming no local services are running"
    fi

    # Stop infrastructure services in reverse dependency order
    log_info "Stopping infrastructure services..."
    if ! stop_infrastructure false; then
        log_warn "Infrastructure stop had issues"
        had_errors=true
    fi

    # Cleanup runtime directory if empty
    if [ -d "$RUNTIME_DIR" ]; then
        if [ -z "$(ls -A "$RUNTIME_DIR" 2>/dev/null)" ]; then
            rmdir "$RUNTIME_DIR"
            log_info "Removed empty runtime directory"
        else
            log_info "Runtime directory not empty, leaving in place"
        fi
    fi

    if [ "$had_errors" = true ]; then
        log_warn "Some services may need manual cleanup"
        return 1
    else
        log_success "All services stopped successfully"
        return 0
    fi
}

restart_all() {
    log_info "Restarting all services..."
    stop_all
    sleep 2
    start_all
}

# ============================================================================
# LOG VIEWING
# ============================================================================

view_logs() {
    local service=${1:-all}

    if [ ! -d "$LOG_DIR" ]; then
        log_error "No logs directory found. Are services running?"
        exit 1
    fi

    case $service in
        backend)
            if [ -f "$LOG_DIR/backend.log" ]; then
                tail -f "$LOG_DIR/backend.log"
            else
                log_error "Backend log not found"
                exit 1
            fi
            ;;
        frontend)
            if [ -f "$LOG_DIR/frontend.log" ]; then
                tail -f "$LOG_DIR/frontend.log"
            else
                log_error "Frontend log not found"
                exit 1
            fi
            ;;
        all)
            if [ -f "$LOG_DIR/backend.log" ] && [ -f "$LOG_DIR/frontend.log" ]; then
                tail -f "$LOG_DIR/backend.log" "$LOG_DIR/frontend.log"
            else
                log_error "Log files not found"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown service: $service"
            log_error "Valid options: backend, frontend, all"
            exit 1
            ;;
    esac
}

# ============================================================================
# STATUS CHECK
# ============================================================================

check_status() {
    log_info "Checking Vinylhound service status..."
    echo ""

    # Check if PID file exists
    if [ ! -f "$PID_FILE" ]; then
        log_warn "No PID file found. Services may not be running."
        echo ""
    else
        read_pids

        # Check backend
        if [ -n "${BACKEND_PID:-}" ] && kill -0 "$BACKEND_PID" 2>/dev/null; then
            echo -e "Backend:     ${GREEN}●${NC} Running (PID: $BACKEND_PID)"
        else
            echo -e "Backend:     ${RED}●${NC} Not running"
        fi

        # Check frontend
        if [ -n "${FRONTEND_PID:-}" ] && kill -0 "$FRONTEND_PID" 2>/dev/null; then
            echo -e "Frontend:    ${GREEN}●${NC} Running (PID: $FRONTEND_PID)"
        else
            echo -e "Frontend:    ${RED}●${NC} Not running"
        fi

        echo ""
    fi

    # Check Docker containers
    if docker ps --format '{{.Names}}' | grep -q vinylhound-db; then
        echo -e "Database:    ${GREEN}●${NC} Running (Docker)"
    else
        echo -e "Database:    ${RED}●${NC} Not running"
    fi

    echo ""

    # Check connectivity
    log_info "Checking service connectivity..."

    if curl -s -f http://localhost:8080/health >/dev/null 2>&1; then
        echo -e "Backend API: ${GREEN}✓${NC} Responding at http://localhost:8080"
    else
        echo -e "Backend API: ${RED}✗${NC} Not responding"
    fi

    if curl -s -f http://localhost:5173 >/dev/null 2>&1; then
        echo -e "Frontend:    ${GREEN}✓${NC} Responding at http://localhost:5173"
    elif curl -s -f http://localhost:3000 >/dev/null 2>&1; then
        echo -e "Frontend:    ${GREEN}✓${NC} Responding at http://localhost:3000"
    else
        echo -e "Frontend:    ${RED}✗${NC} Not responding"
    fi
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat << EOF
Vinylhound Development CLI

USAGE:
    $0 <command> [options]

COMMANDS:
    start               Start all services (infrastructure + backend + frontend)
    stop                Stop all services gracefully
    restart             Restart all services
    status              Show status of all services

    logs [service]      View logs (service: backend, frontend, or all)

    db:migrate          Run database migrations
    db:reset            Reset database (DESTROYS ALL DATA)

    infra:start         Start only infrastructure (Docker containers)
    infra:stop          Stop infrastructure

    backend:start       Start only backend service
    backend:stop        Stop backend service

    frontend:start      Start only frontend service
    frontend:stop       Stop frontend service

    help                Show this help message

EXAMPLES:
    # Start everything
    $0 start

    # View all logs
    $0 logs

    # View backend logs only
    $0 logs backend

    # Check status
    $0 status

    # Restart everything
    $0 restart

    # Reset database
    $0 db:reset

NOTES:
    - Logs are stored in: $LOG_DIR
    - PID file location: $PID_FILE
    - Ensure .env files exist in Backend and Infrastructure directories

For more information, see the README.md in each component directory.

EOF
}

# ============================================================================
# MAIN COMMAND ROUTER
# ============================================================================

main() {
    local command=${1:-help}

    case $command in
        start)
            start_all
            ;;
        stop)
            stop_all
            ;;
        restart)
            restart_all
            ;;
        status)
            check_status
            ;;
        logs)
            view_logs "${2:-all}"
            ;;
        db:migrate)
            run_migrations
            ;;
        db:reset)
            reset_database
            ;;
        infra:start)
            start_infrastructure
            ;;
        infra:stop)
            stop_infrastructure false
            ;;
        backend:start)
            start_backend
            ;;
        backend:stop)
            stop_backend
            ;;
        frontend:start)
            start_frontend
            ;;
        frontend:stop)
            stop_frontend
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
