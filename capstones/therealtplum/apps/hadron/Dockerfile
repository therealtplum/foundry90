# -----------------------------
# Builder stage
# -----------------------------
FROM rust:latest AS builder

WORKDIR /app

# Copy the full crate (Cargo.toml + src + Cargo.lock if present)
COPY Cargo.toml .
COPY Cargo.lock* .
COPY src ./src

# Build release binary
RUN cargo build --release

# -----------------------------
# Runtime stage
# -----------------------------
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the compiled binary from the builder
COPY --from=builder /app/target/release/hadron /usr/local/bin/hadron

EXPOSE 3002

# Run the server
CMD ["hadron"]

