"""The starter: start an order workflow and wait for its result."""

import asyncio
import os
import sys
import uuid

from orcher import Client, ClientConfig

SERVER_URL = os.environ.get("ORCHER_URL", "http://localhost:50051")


async def main() -> None:
    order_id = sys.argv[1] if len(sys.argv) > 1 else f"order-{uuid.uuid4().hex[:8]}"

    async with Client(ClientConfig(server_url=SERVER_URL)) as client:
        handle = await client.start_workflow(
            "order",
            task_queue="quickstart-python",
            workflow_id=order_id,
            args=(order_id,),
        )
        print(f"started workflow {order_id}", flush=True)
        result = await handle.result(timeout=600)
        print(f"result: {result}", flush=True)


if __name__ == "__main__":
    asyncio.run(main())
