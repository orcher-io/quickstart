// The approver: send the `approve` event to a waiting agent workflow.
import { Client } from '@orcher/sdk';

const SERVER_URL = process.env.ORCHER_URL ?? 'http://localhost:50051';

async function main(): Promise<void> {
  const ticketId = process.argv[2];
  if (!ticketId) {
    console.error('usage: npm run agent-approve -- <ticket-id> [reviewer]');
    process.exit(2);
  }
  const reviewer = process.argv[3] ?? 'reviewer';

  const client = new Client({ serverUrl: SERVER_URL, namespace: 'default' });
  await client.connect();

  const handle = client.getWorkflowHandle({ workflowId: ticketId });
  // The event's data is who approved; the workflow puts it in its result.
  await handle.sendEvent('approve', reviewer);
  console.log(`approved ${ticketId} as ${reviewer}`);
  client.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
