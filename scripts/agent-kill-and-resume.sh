#!/usr/bin/env bash
# The AI agent demo: kill the agent's worker while it waits for approval,
# start a new one, approve, and check that the agent finishes without calling
# the model a second time, and sends the email once.
#
#   scripts/agent-kill-and-resume.sh python|typescript|rust
#
# Expects the engine to be up (docker compose up -d --wait) and the example's
# dependencies installed (see its README section).

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

TICKET="$(ticket_id)"
echo "==> $LANG_NAME: agent workflow $TICKET"

# model_calls <log file>: how many times the model was called for this ticket.
model_calls() {
  grep -F "model called" "$1" 2>/dev/null | grep -cF -- "$TICKET" || true
}

# 1. A worker, and an agent for it to run.
start_bg "$LOGS/worker-1.log" "${AGENT_WORKER[@]}"
FIRST_PID="$BG_PID"
wait_for "$LOGS/worker-1.log" "worker polling" 60

start_bg "$LOGS/starter.log" "${AGENT_STARTER[@]}" "$TICKET"
STARTER_PID="$BG_PID"

# 2. Once the model has drafted the reply, the agent waits for approval. Kill
#    the worker during that wait, as a crash would: no clean shutdown. The
#    model takes a second to answer after it prints "model called", and the
#    worker then reports the draft to the engine; until it has, the draft isn't
#    recorded, and the engine would rightly call the model again.
wait_for "$LOGS/worker-1.log" "model called" 60
sleep 3
kill -9 "$FIRST_PID"
wait "$FIRST_PID" 2>/dev/null || true
echo "==> killed the worker (pid $FIRST_PID) while the agent waited for approval"

# 3. With no worker running, and no approval, the agent can't finish.
sleep 3
if ! kill -0 "$STARTER_PID" 2>/dev/null; then
  echo "FAIL: the agent finished with no worker running and no approval" >&2
  dump_logs
  exit 1
fi

# 4. A new worker, then the approval. The new worker picks the agent up, and
#    sends the reply the model drafted before the crash.
start_bg "$LOGS/worker-2.log" "${AGENT_WORKER[@]}"
SECOND_PID="$BG_PID"
wait_for "$LOGS/worker-2.log" "worker polling" 60
echo "==> started a new worker (pid $SECOND_PID)"

if ! (cd "$DIR" && exec "${AGENT_APPROVER[@]}" "$TICKET") >"$LOGS/approver.log" 2>&1; then
  echo "FAIL: the approver exited with an error" >&2
  dump_logs
  exit 1
fi
echo "==> approved $TICKET"

if ! wait_exit "$STARTER_PID" 120; then
  echo "FAIL: the starter exited with an error" >&2
  dump_logs
  exit 1
fi

EXPECTED="result: sent the reply to $TICKET, approved by reviewer"
if ! grep -qxF -- "$EXPECTED" "$LOGS/starter.log"; then
  echo "FAIL: expected '$EXPECTED'" >&2
  dump_logs
  exit 1
fi

MODEL_1="$(model_calls "$LOGS/worker-1.log")"
MODEL_2="$(model_calls "$LOGS/worker-2.log")"
LIMITED="$(count "model rate-limited: draft a reply to $TICKET" "$LOGS/worker-1.log" "$LOGS/worker-2.log")"
SENT_1="$(count "email sent for $TICKET" "$LOGS/worker-1.log")"
SENT_2="$(count "email sent for $TICKET" "$LOGS/worker-2.log")"
echo "    first worker:  model called $MODEL_1 time(s), email sent $SENT_1 time(s)"
echo "    second worker: model called $MODEL_2 time(s), email sent $SENT_2 time(s)"
echo "    rate-limited attempts retried by the engine: $LIMITED"

if [ "$MODEL_1" -ne 1 ] || [ "$MODEL_2" -ne 0 ]; then
  echo "FAIL: the model must be called exactly once, by the first worker" >&2
  dump_logs
  exit 1
fi
if [ "$LIMITED" -ne 1 ]; then
  echo "FAIL: exactly one rate-limited attempt must be retried" >&2
  dump_logs
  exit 1
fi
if [ "$SENT_1" -ne 0 ] || [ "$SENT_2" -ne 1 ]; then
  echo "FAIL: the email must be sent exactly once, by the second worker" >&2
  dump_logs
  exit 1
fi

cat "$LOGS/starter.log"
echo "==> $LANG_NAME: resumed after the crash; model called once, email sent once"
