use axum::{routing::get, Router};
use std::{env, net::SocketAddr};
use tracing::{info, Level};
use tracing_subscriber::EnvFilter;

async fn hello_handler() -> &'static str {
    "Hello from the enclave HTTP server!"
}

fn resolve_addr() -> SocketAddr {
    let port = env::var("PORT")
        .ok()
        .and_then(|val| val.parse::<u16>().ok())
        .unwrap_or(3000);
    SocketAddr::from(([0, 0, 0, 0], port))
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .with_max_level(Level::INFO)
        .with_target(false)
        .finish();

    let app = Router::new().route("/api/hello", get(hello_handler));
    let addr = resolve_addr();
    info!(%addr, "Starting server");

    axum::serve(tokio::net::TcpListener::bind(addr).await.unwrap(), app)
        .await
        .unwrap();
}
