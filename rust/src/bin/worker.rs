//! The worker: one workflow, two tasks and a durable timer between them.

use std::time::Duration;

use orcher_sdk::prelude::*;

const TASK_QUEUE: &str = "quickstart-rust";

// Tasks are where side effects go: call the payment API here.
#[task]
async fn charge(_ctx: TaskContext, order_id: String) -> Result<String> {
    println!("charged {order_id}");
    Ok(format!("charged {order_id}"))
}

#[task]
async fn ship(_ctx: TaskContext, order_id: String) -> Result<String> {
    println!("shipped {order_id}");
    Ok(format!("shipped {order_id}"))
}

#[workflow(name = "order")]
async fn order(ctx: WorkflowContext, order_id: String) -> Result<String> {
    let charged: String = ctx.execute_task(charge, order_id.clone()).await?;
    // A durable timer: the engine keeps it, so a worker restart doesn't reset it.
    ctx.sleep(Duration::from_secs(10)).await?;
    let shipped: String = ctx.execute_task(ship, order_id).await?;
    Ok(format!("{charged}, then {shipped}"))
}

#[tokio::main]
async fn main() -> Result<()> {
    let server_url =
        std::env::var("ORCHER_URL").unwrap_or_else(|_| "http://localhost:50051".to_string());

    let worker = Worker::builder()
        .server_url(&server_url)
        .namespace("default")
        .task_queue(TASK_QUEUE)
        .build()
        .await?;

    println!("worker polling {TASK_QUEUE} on {server_url}");
    worker.run().await
}
