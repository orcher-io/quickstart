//! The agent starter: start an agent workflow on a ticket and wait for its result.

use orcher_sdk::client::StartWorkflowOptions;
use orcher_sdk::prelude::*;

#[tokio::main]
async fn main() -> Result<()> {
    let server_url =
        std::env::var("ORCHER_URL").unwrap_or_else(|_| "http://localhost:50051".to_string());
    let ticket_id = std::env::args().nth(1).unwrap_or_else(|| {
        let id = uuid::Uuid::new_v4().simple().to_string();
        format!("ticket-{}", &id[..8])
    });

    let client = Client::connect(server_url).await?;
    let options = StartWorkflowOptions::new("quickstart-rust-agent").with_workflow_id(&ticket_id);
    let handle = client
        .start_workflow_with_options("agent", ticket_id.clone(), options)
        .await?;
    println!("started workflow {ticket_id}");
    println!("approve its reply with: cargo run --bin agent-approve -- {ticket_id}");

    let result: String = handle.result().await?;
    println!("result: {result}");
    Ok(())
}
