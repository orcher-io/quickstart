#!/usr/bin/env bash
# Run one language's example end to end: start the worker, start an order
# workflow, and check its result.
#
#   scripts/run-example.sh python|typescript|rust
#
# Expects the engine to be up (docker compose up -d --wait) and the example's
# dependencies installed (see its README section).

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

ORDER="$(order_id)"
echo "==> $LANG_NAME: running order workflow $ORDER"

start_bg "$LOGS/worker.log" "${WORKER[@]}"
wait_for "$LOGS/worker.log" "worker polling" 60

start_bg "$LOGS/starter.log" "${STARTER[@]}" "$ORDER"
STARTER_PID="$BG_PID"
if ! wait_exit "$STARTER_PID" 90; then
  echo "FAIL: the starter exited with an error" >&2
  dump_logs
  exit 1
fi

EXPECTED="result: charged $ORDER, then shipped $ORDER"
if ! grep -qxF -- "$EXPECTED" "$LOGS/starter.log"; then
  echo "FAIL: expected '$EXPECTED'" >&2
  dump_logs
  exit 1
fi

cat "$LOGS/starter.log"
echo "==> $LANG_NAME: OK"
