//! The approver: send the `approve` event to a waiting agent workflow.

use orcher_sdk::prelude::*;

#[tokio::main]
async fn main() -> Result<()> {
    let server_url =
        std::env::var("ORCHER_URL").unwrap_or_else(|_| "http://localhost:50051".to_string());
    let Some(ticket_id) = std::env::args().nth(1) else {
        eprintln!("usage: cargo run --bin agent-approve -- <ticket-id> [reviewer]");
        std::process::exit(2);
    };
    let reviewer = std::env::args()
        .nth(2)
        .unwrap_or_else(|| "reviewer".to_string());

    let client = Client::connect(server_url).await?;
    let handle = client.get_workflow_handle(ticket_id.clone()).await?;
    // The event's data is who approved; the workflow puts it in its result.
    handle.send_event("approve", reviewer.clone()).await?;
    println!("approved {ticket_id} as {reviewer}");
    Ok(())
}
