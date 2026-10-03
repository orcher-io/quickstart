"""The approver: send the `approve` event to a waiting agent workflow."""

import asyncio
import os
import sys

from orcher import Client, ClientConfig

SERVER_URL = os.environ.get("ORCHER_URL", "http://localhost:50051")


async def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("usage: python agent_approve.py <ticket-id> [reviewer]")
    ticket_id = sys.argv[1]
    reviewer = sys.argv[2] if len(sys.argv) > 2 else "reviewer"

    async with Client(ClientConfig(server_url=SERVER_URL)) as client:
        handle = await client.get_workflow(ticket_id)
        # The event's data is who approved; the workflow puts it in its result.
        await handle.send_event("approve", reviewer)
        print(f"approved {ticket_id} as {reviewer}", flush=True)


if __name__ == "__main__":
    asyncio.run(main())
