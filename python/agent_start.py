"""The agent starter: start an agent workflow on a ticket and wait for its result."""

import asyncio
import os
import sys
import uuid

from orcher import Client, ClientConfig

SERVER_URL = os.environ.get("ORCHER_URL", "http://localhost:50051")


async def main() -> None:
    ticket_id = sys.argv[1] if len(sys.argv) > 1 else f"ticket-{uuid.uuid4().hex[:8]}"

    async with Client(ClientConfig(server_url=SERVER_URL)) as client:
        handle = await client.start_workflow(
            "agent",
            task_queue="quickstart-python-agent",
            workflow_id=ticket_id,
            args=(ticket_id,),
        )
        print(f"started workflow {ticket_id}", flush=True)
        print(f"approve its reply with: python agent_approve.py {ticket_id}", flush=True)
        result = await handle.result(timeout=600)
        print(f"result: {result}", flush=True)


if __name__ == "__main__":
    asyncio.run(main())
