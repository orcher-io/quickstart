// The agent worker: a support agent that drafts a reply with a model, waits
// for a person to approve it, then sends it.
import {
  Duration, Task, Tasks, Worker, Workflow, createTaskRefs,
  type TaskContext, type WorkflowContext,
} from '@orcher/sdk';

const SERVER_URL = process.env.ORCHER_URL ?? 'http://localhost:50051';
const TASK_QUEUE = 'quickstart-typescript-agent';

// How many times this process has called the model. Each worker counts its
// own calls, so the counts in two workers' logs add up to the total.
let modelCalls = 0;
// For the demo, the first request each worker makes is rate-limited, so the
// engine's retry shows in the log.
let rateLimitedOnce = false;

/** A transient model failure, such as an HTTP 429: worth retrying. */
class RateLimited extends Error {}

/**
 * A fake model, so the example runs with no network and no API key.
 *
 * This is where a real LLM call goes: send the prompt to your provider and
 * return its answer. This one takes a moment, as a model does, and returns the
 * same canned reply every time.
 */
async function callModel(prompt: string): Promise<string> {
  if (!rateLimitedOnce) {
    rateLimitedOnce = true;
    console.log(`model rate-limited: ${prompt}; the engine will retry`);
    throw new RateLimited('rate limited, try again shortly');
  }
  modelCalls += 1;
  console.log(`model called (call #${modelCalls} in this worker): ${prompt}`);
  await new Promise((resolve) => setTimeout(resolve, 1000));
  return 'Sorry about the damaged parcel. A replacement ships today, at no cost to you.';
}

@Tasks()
export class AgentTasks {
  // The engine retries the task when the model fails, up to five attempts in
  // all, waiting a second before the first retry and twice as long each time.
  @Task({ retryPolicy: { maxAttempts: 5, initialInterval: 1000, backoffCoefficient: 2 } })
  async draftReply(_ctx: TaskContext, ticketId: string): Promise<string> {
    return callModel(`draft a reply to ${ticketId}`);
  }

  // A tool with a side effect: send the email here.
  @Task()
  async sendReply(_ctx: TaskContext, email: { ticketId: string; reply: string }): Promise<string> {
    console.log(`email sent for ${email.ticketId}: ${email.reply}`);
    return `sent the reply to ${email.ticketId}`;
  }
}

export const agentTasks = createTaskRefs(AgentTasks);

@Workflow({ name: 'agent' })
export class Agent {
  async run(ctx: WorkflowContext, ticketId: string): Promise<string> {
    const draft = await ctx.executeTask(agentTasks.draftReply, ticketId);
    // Wait for a person to approve the draft. The engine keeps the wait and its
    // 24-hour deadline (a durable timer), so no worker has to stay up for it.
    const reviewer = await ctx.waitForEventWithTimeout<string>('approve', Duration.fromHours(24));
    if (reviewer === null) {
      return `no approval for ${ticketId} within 24 hours; the reply was not sent`;
    }
    const sent = await ctx.executeTask(agentTasks.sendReply, { ticketId, reply: draft });
    return `${sent}, approved by ${reviewer}`;
  }
}

async function main(): Promise<void> {
  const worker = await Worker.builder()
    .serverUrl(SERVER_URL)
    .namespace('default')
    .taskQueue(TASK_QUEUE)
    .build();

  console.log(`worker polling ${TASK_QUEUE} on ${SERVER_URL}`);
  await worker.run();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
