//! The starter: start an order workflow and wait for its result.

use orcher_sdk::client::StartWorkflowOptions;
use orcher_sdk::prelude::*;

#[tokio::main]
async fn main() -> Result<()> {
    let server_url =
        std::env::var("ORCHER_URL").unwrap_or_else(|_| "http://localhost:50051".to_string());
    let order_id = std::env::args().nth(1).unwrap_or_else(|| {
        let id = uuid::Uuid::new_v4().simple().to_string();
        format!("order-{}", &id[..8])
    });

    let client = Client::connect(server_url).await?;
    let options = StartWorkflowOptions::new("quickstart-rust").with_workflow_id(&order_id);
    let handle = client
        .start_workflow_with_options("order", order_id.clone(), options)
        .await?;
    println!("started workflow {order_id}");

    let result: String = handle.result().await?;
    println!("result: {result}");
    Ok(())
}
