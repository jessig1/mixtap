#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="${SCRIPT_DIR}/Vinylhound-Backend"
FRONTEND_DIR="${SCRIPT_DIR}/vinylhound-frontend"
INFRA_DIR="${SCRIPT_DIR}/Vinylhound-Infrastructure"
RUNTIME_DIR="${SCRIPT_DIR}/.vinylhound-runtime"
PID_FILE="${RUNTIME_DIR}/pids"
BACKEND_LOG="${RUNTIME_DIR}/backend.log"
FRONTEND_LOG="${RUNTIME_DIR}/frontend.log"

for dir in "$BACKEND_DIR" "$FRONTEND_DIR" "$INFRA_DIR"; do
  if [ ! -d "$dir" ]; then
    echo "Required directory not found: $dir" >&2
    exit 1
  fi
done

mkdir -p "$RUNTIME_DIR"

if [ -f "$PID_FILE" ]; then
  echo "A PID file already exists at $PID_FILE."
  echo "Run vinylhound-stop.sh before starting new processes."
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE=(docker compose)
elif docker-compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE=(docker-compose)
else
  echo "Neither 'docker compose' nor 'docker-compose' was found in PATH." >&2
  exit 1
fi

echo "Starting infrastructure (docker compose up -d)..."
(
  cd "$INFRA_DIR"
  "${DOCKER_COMPOSE[@]}" up -d
)

echo "Waiting for database to be ready..."
DB_READY=0
for _ in $(seq 1 30); do
  if docker exec vinylhound-db pg_isready -U vinylhound -d vinylhound >/dev/null 2>&1; then
    DB_READY=1
    break
  fi
  sleep 1
done

if [ "$DB_READY" -ne 1 ]; then
  echo "Database did not become ready in time." >&2
  exit 1
fi

echo "Starting backend API..."
pushd "$BACKEND_DIR" >/dev/null
nohup go run ./cmd/vinylhound >"$BACKEND_LOG" 2>&1 &
BACKEND_PID=$!
popd >/dev/null

echo "Starting frontend (npm run dev)..."
pushd "$FRONTEND_DIR" >/dev/null
if [ ! -d node_modules ]; then
  npm install
fi
nohup npm run dev -- --host >"$FRONTEND_LOG" 2>&1 &
FRONTEND_PID=$!
popd >/dev/null

cat >"$PID_FILE" <<EOF
BACKEND_PID=$BACKEND_PID
FRONTEND_PID=$FRONTEND_PID
EOF

echo "Vinylhound services are starting."
echo "  Backend log:    $BACKEND_LOG"
echo "  Frontend log:   $FRONTEND_LOG"
echo "  PID file:       $PID_FILE"
echo "Use vinylhound-stop.sh to stop all services."
