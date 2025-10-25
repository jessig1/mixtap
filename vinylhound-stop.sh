#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/Vinylhound-Infrastructure"
RUNTIME_DIR="${SCRIPT_DIR}/.vinylhound-runtime"
PID_FILE="${RUNTIME_DIR}/pids"

if docker compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE=(docker compose)
elif docker-compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE=(docker-compose)
else
  DOCKER_COMPOSE=()
fi

stop_process() {
  local name="$1"
  local pid="$2"

  if [ -z "${pid:-}" ]; then
    return
  fi

  if ! kill -0 "$pid" >/dev/null 2>&1; then
    echo "$name (PID $pid) is not running."
    return
  fi

  echo "Stopping $name (PID $pid)..."
  kill "$pid" >/dev/null 2>&1 || true

  for _ in $(seq 1 20); do
    if kill -0 "$pid" >/dev/null 2>&1; then
      sleep 0.5
    else
      break
    fi
  done

  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "$name did not exit gracefully; sending SIGKILL."
    kill -9 "$pid" >/dev/null 2>&1 || true
  fi
}

collect_pids_for_pattern() {
  local pattern="$1"

  if command -v pgrep >/dev/null 2>&1; then
    pgrep -f -- "$pattern" 2>/dev/null || true
  else
    ps -eo pid=,command= | awk -v pat="$pattern" 'index($0, pat) {print $1}' || true
  fi
}

stop_additional_processes() {
  if ! command -v ps >/dev/null 2>&1; then
    echo "ps command not available; skipping additional process cleanup."
    return
  fi

  local -a patterns=(
    "$SCRIPT_DIR/Vinylhound-Backend"
    "$SCRIPT_DIR/vinylhound-frontend"
    "vinylhound-start.sh"
  )

  declare -A candidate_pids=()

  for pattern in "${patterns[@]}"; do
    while IFS= read -r pid; do
      if [ -n "${pid:-}" ]; then
        candidate_pids["$pid"]=1
      fi
    done < <(collect_pids_for_pattern "$pattern")
  done

  local current_pid="$$"
  local parent_pid="${PPID:-}"
  local -i killed_count=0

  for pid in "${!candidate_pids[@]}"; do
    if [ "$pid" = "$current_pid" ] || { [ -n "$parent_pid" ] && [ "$pid" = "$parent_pid" ]; }; then
      continue
    fi

    if ! kill -0 "$pid" >/dev/null 2>&1; then
      continue
    fi

    local description="process $pid"
    local cmd_output
    cmd_output="$(ps -p "$pid" -o command= 2>/dev/null | head -n1 | tr -d '\r')"
    if [ -n "$cmd_output" ]; then
      description="$cmd_output"
    fi

    stop_process "$description" "$pid"
    killed_count+=1
  done

  if [ "$killed_count" -eq 0 ]; then
    echo "No additional Vinylhound processes found."
  fi
}

if [ -f "$PID_FILE" ]; then
  # shellcheck disable=SC1090
  source "$PID_FILE"
  stop_process "backend" "${BACKEND_PID:-}"
  stop_process "frontend" "${FRONTEND_PID:-}"
  rm -f "$PID_FILE"
else
  echo "No PID file found at $PID_FILE; skipping backend/frontend process shutdown."
fi

stop_additional_processes

if [ -n "${DOCKER_COMPOSE[*]:-}" ] && [ -d "$INFRA_DIR" ]; then
  echo "Stopping infrastructure containers and removing database volume..."
  (
    cd "$INFRA_DIR"
    "${DOCKER_COMPOSE[@]}" down --volumes --remove-orphans
  )
else
  echo "Docker compose command not found or infrastructure directory missing; skipping container shutdown."
fi

if [ -d "$RUNTIME_DIR" ] && [ -z "$(ls -A "$RUNTIME_DIR")" ]; then
  rmdir "$RUNTIME_DIR"
fi

echo "Vinylhound services have been stopped."
