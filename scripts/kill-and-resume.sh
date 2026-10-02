#!/usr/bin/env bash
# The durability demo: kill the worker while the workflow sleeps, start a new
# one, and check that the workflow finishes where it left off, without
# charging the order a second time.
#
#   scripts/kill-and-resume.sh python|typescript|rust
#
# Expects the engine to be up (docker compose up -d --wait) and the example's
# dependencies installed (see its README section).

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

ORDER="$(order_id)"
echo "==> $LANG_NAME: order workflow $ORDER"

# 1. A worker, and a workflow for it to run.
start_bg "$LOGS/worker-1.log" "${WORKER[@]}"
FIRST_PID="$BG_PID"
wait_for "$LOGS/worker-1.log" "worker polling" 60

start_bg "$LOGS/starter.log" "${STARTER[@]}" "$ORDER"
STARTER_PID="$BG_PID"

# 2. Once the order is charged the workflow sleeps for 10 seconds. Kill the
#    worker in the middle of that sleep, as a crash would: no clean shutdown.
#    The task prints "charged" just before it returns, so give the worker a
#    moment to report the result to the engine; until it has, the charge
#    isn't recorded, and the engine would rightly run it again.
wait_for "$LOGS/worker-1.log" "charged $ORDER" 60
sleep 2
kill -9 "$FIRST_PID"
wait "$FIRST_PID" 2>/dev/null || true
echo "==> killed the worker (pid $FIRST_PID) during the timer"

# 3. With no worker running, the workflow can't finish.
sleep 3
if ! kill -0 "$STARTER_PID" 2>/dev/null; then
  echo "FAIL: the workflow finished with no worker running" >&2
  dump_logs
  exit 1
fi

# 4. A new worker picks the workflow up after the timer, and ships the order.
start_bg "$LOGS/worker-2.log" "${WORKER[@]}"
SECOND_PID="$BG_PID"
echo "==> started a new worker (pid $SECOND_PID)"

if ! wait_exit "$STARTER_PID" 120; then
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

CHARGED_1="$(count "charged $ORDER" "$LOGS/worker-1.log")"
CHARGED_2="$(count "charged $ORDER" "$LOGS/worker-2.log")"
SHIPPED_1="$(count "shipped $ORDER" "$LOGS/worker-1.log")"
SHIPPED_2="$(count "shipped $ORDER" "$LOGS/worker-2.log")"
echo "    first worker:  charged $CHARGED_1 time(s), shipped $SHIPPED_1 time(s)"
echo "    second worker: charged $CHARGED_2 time(s), shipped $SHIPPED_2 time(s)"

if [ "$CHARGED_1" -ne 1 ] || [ "$CHARGED_2" -ne 0 ]; then
  echo "FAIL: the order must be charged exactly once, by the first worker" >&2
  dump_logs
  exit 1
fi
if [ "$SHIPPED_1" -ne 0 ] || [ "$SHIPPED_2" -ne 1 ]; then
  echo "FAIL: the order must be shipped exactly once, by the second worker" >&2
  dump_logs
  exit 1
fi

cat "$LOGS/starter.log"
echo "==> $LANG_NAME: resumed after the crash; charged once, shipped once"
