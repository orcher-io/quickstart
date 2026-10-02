// The starter: start an order workflow and wait for its result.
import { randomUUID } from 'node:crypto';
import { Client } from '@orcher/sdk';

const SERVER_URL = process.env.ORCHER_URL ?? 'http://localhost:50051';

async function main(): Promise<void> {
  const orderId = process.argv[2] ?? `order-${randomUUID().slice(0, 8)}`;

  const client = new Client({ serverUrl: SERVER_URL, namespace: 'default' });
  await client.connect();

  const handle = await client.startWorkflow<string>({
    workflowType: 'order',
    taskQueue: 'quickstart-typescript',
    workflowId: orderId,
    args: [orderId],
  });
  console.log(`started workflow ${orderId}`);

  const result = await handle.result();
  console.log(`result: ${result}`);
  client.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
