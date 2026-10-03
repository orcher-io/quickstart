"""The agent worker: a support agent that drafts a reply with a model, waits
for a person to approve it, then sends it."""

import asyncio
import os
from datetime import timedelta

from orcher import RetryPolicy, TaskContext, Worker, WorkflowContext, task, workflow

SERVER_URL = os.environ.get("ORCHER_URL", "http://localhost:50051")
TASK_QUEUE = "quickstart-python-agent"

# How many times this process has called the model. Each worker counts its
# own calls, so the counts in two workers' logs add up to the total.
model_calls = 0
# For the demo, the first request each worker makes is rate-limited, so the
# engine's retry shows in the log.
rate_limited_once = False


class RateLimited(Exception):
    """A transient model failure, such as an HTTP 429: worth retrying."""


async def call_model(prompt: str) -> str:
    """A fake model, so the example runs with no network and no API key.

    This is where a real LLM call goes: send the prompt to your provider and
    return its answer. This one takes a moment, as a model does, and returns
    the same canned reply every time.
    """
    global model_calls, rate_limited_once
    if not rate_limited_once:
        rate_limited_once = True
        print(f"model rate-limited: {prompt}; the engine will retry", flush=True)
        raise RateLimited("rate limited, try again shortly")
    model_calls += 1
    print(f"model called (call #{model_calls} in this worker): {prompt}", flush=True)
    await asyncio.sleep(1)
    return "Sorry about the damaged parcel. A replacement ships today, at no cost to you."


# The engine retries the task when the model fails, up to five attempts in
# all, waiting a second before the first retry and twice as long each time.
@task(name="draft_reply", retry_policy=RetryPolicy(max_attempts=5))
async def draft_reply(ctx: TaskContext, ticket_id: str) -> str:
    return await call_model(f"draft a reply to {ticket_id}")


# A tool with a side effect: send the email here.
@task(name="send_reply")
async def send_reply(ctx: TaskContext, ticket_id: str, reply: str) -> str:
    print(f"email sent for {ticket_id}: {reply}", flush=True)
    return f"sent the reply to {ticket_id}"


@workflow(name="agent")
async def agent(ctx: WorkflowContext, ticket_id: str) -> str:
    draft = await ctx.execute_task(draft_reply, ticket_id=ticket_id)
    # Wait for a person to approve the draft. The engine keeps the wait and its
    # 24-hour deadline (a durable timer), so no worker has to stay up for it.
    try:
        reviewer = await ctx.wait_for_event_with_timeout("approve", timedelta(hours=24))
    except TimeoutError:
        return f"no approval for {ticket_id} within 24 hours; the reply was not sent"
    sent = await ctx.execute_task(send_reply, ticket_id=ticket_id, reply=draft)
    return f"{sent}, approved by {reviewer}"


async def main() -> None:
    worker = (
        Worker.builder()
        .server_url(SERVER_URL)
        .namespace("default")
        .task_queue(TASK_QUEUE)
        .build()
    )
    print(f"worker polling {TASK_QUEUE} on {SERVER_URL}", flush=True)
    await worker.run()


if __name__ == "__main__":
    asyncio.run(main())
