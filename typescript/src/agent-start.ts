// The agent starter: start an agent workflow on a ticket and wait for its result.
import { randomUUID } from 'node:crypto';
import { Client } from '@orcher/sdk';

const SERVER_URL = process.env.ORCHER_URL ?? 'http://localhost:50051';

async function main(): Promise<void> {
  const ticketId = process.argv[2] ?? `ticket-${randomUUID().slice(0, 8)}`;

  const client = new Client({ serverUrl: SERVER_URL, namespace: 'default' });
  await client.connect();

  const handle = await client.startWorkflow<string>({
    workflowType: 'agent',
    taskQueue: 'quickstart-typescript-agent',
    workflowId: ticketId,
    args: [ticketId],
  });
  console.log(`started workflow ${ticketId}`);
  console.log(`approve its reply with: npm run agent-approve -- ${ticketId}`);

  const result = await handle.result();
  console.log(`result: ${result}`);
  client.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
