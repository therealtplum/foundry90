# --- Builder stage ---
FROM rust:latest AS builder

WORKDIR /app

# Cache deps
COPY Cargo.toml .
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release || true

# Now copy real source
COPY src ./src
RUN cargo build --release

# --- Runtime stage ---
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/fmhub-api /usr/local/bin/fmhub-api

ENV RUST_LOG=info

EXPOSE 3000

CMD ["fmhub-api"]