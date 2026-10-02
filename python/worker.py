"""The worker: one workflow, two tasks and a durable timer between them."""

import asyncio
import os
from datetime import timedelta

from orcher import TaskContext, Worker, WorkflowContext, task, workflow

SERVER_URL = os.environ.get("ORCHER_URL", "http://localhost:50051")
TASK_QUEUE = "quickstart-python"


@task(name="charge")
async def charge(ctx: TaskContext, order_id: str) -> str:
    # Tasks are where side effects go: call the payment API here.
    print(f"charged {order_id}", flush=True)
    return f"charged {order_id}"


@task(name="ship")
async def ship(ctx: TaskContext, order_id: str) -> str:
    print(f"shipped {order_id}", flush=True)
    return f"shipped {order_id}"


@workflow(name="order")
async def order(ctx: WorkflowContext, order_id: str) -> str:
    charged = await ctx.execute_task(charge, order_id=order_id)
    # A durable timer: the engine keeps it, so a worker restart doesn't reset it.
    await ctx.sleep(timedelta(seconds=10))
    shipped = await ctx.execute_task(ship, order_id=order_id)
    return f"{charged}, then {shipped}"


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
