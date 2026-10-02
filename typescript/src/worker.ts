// The worker: one workflow, two tasks and a durable timer between them.
import {
  Duration, Task, Tasks, Worker, Workflow, createTaskRefs,
  type TaskContext, type WorkflowContext,
} from '@orcher/sdk';

const SERVER_URL = process.env.ORCHER_URL ?? 'http://localhost:50051';
const TASK_QUEUE = 'quickstart-typescript';

@Tasks()
export class OrderTasks {
  // Tasks are where side effects go: call the payment API here.
  @Task()
  async charge(_ctx: TaskContext, orderId: string): Promise<string> {
    console.log(`charged ${orderId}`);
    return `charged ${orderId}`;
  }

  @Task()
  async ship(_ctx: TaskContext, orderId: string): Promise<string> {
    console.log(`shipped ${orderId}`);
    return `shipped ${orderId}`;
  }
}

export const orderTasks = createTaskRefs(OrderTasks);

@Workflow({ name: 'order' })
export class Order {
  async run(ctx: WorkflowContext, orderId: string): Promise<string> {
    const charged = await ctx.executeTask(orderTasks.charge, orderId);
    // A durable timer: the engine keeps it, so a worker restart doesn't reset it.
    await ctx.sleep(Duration.fromSeconds(10));
    const shipped = await ctx.executeTask(orderTasks.ship, orderId);
    return `${charged}, then ${shipped}`;
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
