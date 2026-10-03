# shellcheck shell=bash
# shellcheck disable=SC2034 # set here, used by the scripts that source this file
# Shared helpers for run-example.sh, kill-and-resume.sh and
# agent-kill-and-resume.sh. Sourced, not run.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ORCHER_URL="${ORCHER_URL:-http://localhost:${ORCHER_GRPC_PORT:-50051}}"

LANG_NAME="${1:-}"
case "$LANG_NAME" in
  python)
    DIR="$ROOT/python"
    PY="${PYTHON:-python3}"
    WORKER=("$PY" worker.py)
    STARTER=("$PY" start.py)
    AGENT_WORKER=("$PY" agent_worker.py)
    AGENT_STARTER=("$PY" agent_start.py)
    AGENT_APPROVER=("$PY" agent_approve.py)
    ;;
  typescript)
    DIR="$ROOT/typescript"
    WORKER=(node dist/worker.js)
    STARTER=(node dist/start.js)
    AGENT_WORKER=(node dist/agent-worker.js)
    AGENT_STARTER=(node dist/agent-start.js)
    AGENT_APPROVER=(node dist/agent-approve.js)
    ;;
  rust)
    # The binaries themselves, not `cargo run`: killing cargo would leave the
    # worker it started running.
    DIR="$ROOT/rust"
    WORKER=(target/debug/worker)
    STARTER=(target/debug/start)
    AGENT_WORKER=(target/debug/agent-worker)
    AGENT_STARTER=(target/debug/agent-start)
    AGENT_APPROVER=(target/debug/agent-approve)
    ;;
  *)
    echo "usage: $0 python|typescript|rust" >&2
    exit 2
    ;;
esac

LOGS="$(mktemp -d)"
PIDS=()

cleanup() {
  for pid in "${PIDS[@]:-}"; do
    [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT

# start_bg <log file> <command...>: run a command in $DIR in the background.
# Sets BG_PID to its pid. (Not printed, because a process started inside $(...)
# is not this shell's child, and its exit status could not be collected.)
start_bg() {
  local log="$1"
  shift
  (cd "$DIR" && exec "$@") >"$log" 2>&1 &
  BG_PID=$!
  PIDS+=("$BG_PID")
}

# wait_for <log file> <text> <seconds>: wait until the log contains the text.
wait_for() {
  local log="$1" text="$2" deadline=$((SECONDS + $3))
  until grep -qF -- "$text" "$log" 2>/dev/null; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      echo "FAIL: '$text' did not appear in $(basename "$log") within $3s" >&2
      dump_logs
      exit 1
    fi
    sleep 0.2
  done
}

# wait_exit <pid> <seconds>: wait for a process to exit and return its status.
wait_exit() {
  local pid="$1" deadline=$((SECONDS + $2))
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      echo "FAIL: process $pid still running after $2s" >&2
      dump_logs
      exit 1
    fi
    sleep 0.2
  done
  local status=0
  wait "$pid" || status=$?
  return "$status"
}

dump_logs() {
  for f in "$LOGS"/*.log; do
    echo "----- $(basename "$f")" >&2
    cat "$f" >&2
  done
}

# count <text> <files...>: how many lines in the files contain the text.
count() {
  local text="$1"
  shift
  cat "$@" 2>/dev/null | grep -cF -- "$text" || true
}

order_id() {
  echo "order-$LANG_NAME-$(date +%s)-$RANDOM"
}

ticket_id() {
  echo "ticket-$LANG_NAME-$(date +%s)-$RANDOM"
}
