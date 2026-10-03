//! The agent worker: a support agent that drafts a reply with a model, waits
//! for a person to approve it, then sends it.

use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::time::Duration;

use orcher_sdk::error::TaskError;
use orcher_sdk::prelude::*;

const TASK_QUEUE: &str = "quickstart-rust-agent";

// How many times this process has called the model. Each worker counts its
// own calls, so the counts in two workers' logs add up to the total.
static MODEL_CALLS: AtomicU32 = AtomicU32::new(0);
// For the demo, the first request each worker makes is rate-limited, so the
// engine's retry shows in the log.
static RATE_LIMITED_ONCE: AtomicBool = AtomicBool::new(false);

/// A fake model, so the example runs with no network and no API key.
///
/// This is where a real LLM call goes: send the prompt to your provider and
/// return its answer. This one takes a moment, as a model does, and returns the
/// same canned reply every time.
async fn call_model(prompt: &str) -> Result<String> {
    if !RATE_LIMITED_ONCE.swap(true, Ordering::SeqCst) {
        println!("model rate-limited: {prompt}; the engine will retry");
        // A transient failure, such as an HTTP 429: worth retrying.
        return Err(TaskError::application("RateLimited", "rate limited, try again shortly").into());
    }
    let calls = MODEL_CALLS.fetch_add(1, Ordering::SeqCst) + 1;
    println!("model called (call #{calls} in this worker): {prompt}");
    tokio::time::sleep(Duration::from_secs(1)).await;
    Ok("Sorry about the damaged parcel. A replacement ships today, at no cost to you.".to_string())
}

// The engine retries the task when the model fails, up to five attempts in
// all, waiting a second before the first retry and twice as long each time.
#[task(retry = 5)]
async fn draft_reply(_ctx: TaskContext, ticket_id: String) -> Result<String> {
    call_model(&format!("draft a reply to {ticket_id}")).await
}

#[derive(Serialize, Deserialize)]
pub struct Email {
    pub ticket_id: String,
    pub reply: String,
}

// A tool with a side effect: send the email here.
#[task]
async fn send_reply(_ctx: TaskContext, email: Email) -> Result<String> {
    println!("email sent for {}: {}", email.ticket_id, email.reply);
    Ok(format!("sent the reply to {}", email.ticket_id))
}

#[workflow(name = "agent")]
async fn agent(ctx: WorkflowContext, ticket_id: String) -> Result<String> {
    let draft: String = ctx.execute_task(draft_reply, ticket_id.clone()).await?;
    // Wait for a person to approve the draft. The engine keeps the wait and its
    // 24-hour deadline (a durable timer), so no worker has to stay up for it.
    let reviewer: Option<String> = ctx
        .wait_for_event_with_timeout("approve", Duration::from_secs(24 * 60 * 60))
        .await?;
    let Some(reviewer) = reviewer else {
        return Ok(format!(
            "no approval for {ticket_id} within 24 hours; the reply was not sent"
        ));
    };
    let email = Email {
        ticket_id,
        reply: draft,
    };
    let sent: String = ctx.execute_task(send_reply, email).await?;
    Ok(format!("{sent}, approved by {reviewer}"))
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
