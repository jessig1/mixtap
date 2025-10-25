#!/usr/bin/env bash
#
# Database Setup Script for Vinylhound
#
# This script sets up the PostgreSQL database for local development.
# It can work with either a local PostgreSQL installation or Docker.
#
# Usage:
#   ./scripts/setup-db.sh [docker|local]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Database configuration
DB_USER="vinylhound"
DB_PASSWORD="${DB_PASSWORD:-localpassword}"
DB_NAME="vinylhound"
DB_PORT="${DB_PORT:-54320}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Detect mode (docker or local)
MODE="${1:-docker}"

setup_docker_db() {
    log_info "Setting up database using Docker..."

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi

    # Check if container exists and is running
    if docker ps -a --format '{{.Names}}' | grep -q "vinylhound-db"; then
        log_info "Database container already exists"

        if docker ps --format '{{.Names}}' | grep -q "vinylhound-db"; then
            log_info "Database is already running"
        else
            log_info "Starting existing database container..."
            docker start vinylhound-db
            sleep 2
        fi
    else
        log_info "Creating new database container..."
        docker run -d \
            --name vinylhound-db \
            -e POSTGRES_USER="$DB_USER" \
            -e POSTGRES_PASSWORD="$DB_PASSWORD" \
            -e POSTGRES_DB="$DB_NAME" \
            -p "$DB_PORT:5432" \
            postgres:16-alpine

        log_info "Waiting for database to be ready..."
        sleep 5
    fi

    # Wait for database to be ready
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker exec vinylhound-db pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
            log_success "Database is ready!"
            break
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    if [ $attempt -eq $max_attempts ]; then
        log_error "Database failed to become ready"
        exit 1
    fi

    print_connection_info "docker"
}

setup_local_db() {
    log_info "Setting up database using local PostgreSQL..."

    # Check if psql is available
    if ! command -v psql &> /dev/null; then
        log_error "PostgreSQL client (psql) is not installed."
        log_error "Please install postgresql-client or use Docker mode: $0 docker"
        exit 1
    fi

    # Check if we can connect as postgres user
    if ! sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1; then
        log_error "Cannot connect to PostgreSQL as postgres user."
        log_error "Make sure PostgreSQL is installed and running."
        exit 1
    fi

    log_info "Cleaning up existing database and user (if they exist)..."

    # Drop existing connections and database
    sudo -u postgres psql -c "
DO \$\$
BEGIN
    -- Terminate existing connections
    PERFORM pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();

    -- Drop database if exists
    DROP DATABASE IF EXISTS ${DB_NAME};

    -- Drop user if exists
    DROP USER IF EXISTS ${DB_USER};
END
\$\$;" >/dev/null 2>&1 || true

    log_success "Cleaned up existing resources"

    # Create user
    log_info "Creating user: $DB_USER"
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}' LOGIN;"

    # Create database
    log_info "Creating database: $DB_NAME"
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

    # Grant privileges
    log_info "Granting privileges..."
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"

    # Connect to database and grant schema privileges
    sudo -u postgres psql -d "${DB_NAME}" -c "
GRANT ALL ON SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_USER};"

    log_success "Database setup completed successfully!"

    print_connection_info "local"
}

print_connection_info() {
    local mode=$1
    local host
    local port

    if [ "$mode" = "docker" ]; then
        host="localhost"
        port="$DB_PORT"
    else
        host="localhost"
        port="5432"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_success "Database is ready for use!"
    echo ""
    log_info "Connection Details:"
    echo "  Host:     $host"
    echo "  Port:     $port"
    echo "  Database: $DB_NAME"
    echo "  Username: $DB_USER"
    echo "  Password: $DB_PASSWORD"
    echo ""
    log_info "Connection String:"
    echo "  postgresql://${DB_USER}:${DB_PASSWORD}@${host}:${port}/${DB_NAME}?sslmode=disable"
    echo ""
    log_info "Environment Variable:"
    echo "  DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@${host}:${port}/${DB_NAME}?sslmode=disable"
    echo ""
    log_info "Next Steps:"
    echo "  1. Run migrations:"
    echo "     make db-migrate"
    echo "     OR"
    echo "     ./scripts/vinylhound.sh db:migrate"
    echo ""
    echo "  2. Start the application:"
    echo "     make start"
    echo "     OR"
    echo "     ./scripts/vinylhound.sh start"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

reset_database() {
    log_warn "This will DESTROY ALL DATA in the database!"
    read -p "Are you sure? Type 'yes' to confirm: " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Reset cancelled"
        exit 0
    fi

    if [ "$MODE" = "docker" ]; then
        log_info "Removing Docker database container..."
        docker stop vinylhound-db >/dev/null 2>&1 || true
        docker rm vinylhound-db >/dev/null 2>&1 || true
        setup_docker_db
    else
        setup_local_db
    fi

    log_success "Database has been reset"
}

show_help() {
    cat << EOF
Vinylhound Database Setup Script

USAGE:
    $0 [mode] [command]

MODES:
    docker              Use Docker for PostgreSQL (default)
    local               Use local PostgreSQL installation

COMMANDS:
    setup               Setup database (default)
    reset               Reset database (DESTROYS ALL DATA)
    help                Show this help message

EXAMPLES:
    # Setup database using Docker
    $0 docker

    # Setup database using local PostgreSQL
    $0 local

    # Reset Docker database
    $0 docker reset

    # Show help
    $0 help

ENVIRONMENT VARIABLES:
    DB_PASSWORD         Database password (default: localpassword)
    DB_PORT             Database port for Docker (default: 54320)

EOF
}

# Main execution
case "${1:-docker}" in
    help|--help|-h)
        show_help
        ;;
    docker|local)
        MODE=$1
        COMMAND="${2:-setup}"

        case $COMMAND in
            setup)
                if [ "$MODE" = "docker" ]; then
                    setup_docker_db
                else
                    setup_local_db
                fi
                ;;
            reset)
                reset_database
                ;;
            *)
                log_error "Unknown command: $COMMAND"
                show_help
                exit 1
                ;;
        esac
        ;;
    reset)
        reset_database
        ;;
    *)
        log_error "Unknown mode: $1"
        show_help
        exit 1
        ;;
esac
