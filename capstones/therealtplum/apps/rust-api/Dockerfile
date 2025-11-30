# -----------------------------
# Builder stage
# -----------------------------
FROM rust:latest AS builder

WORKDIR /app

# Copy the full crate (Cargo.toml + src + Cargo.lock if present)
COPY Cargo.toml .
COPY Cargo.lock .
COPY src ./src

# Build release binary
RUN cargo build --release

# -----------------------------
# Runtime stage
# -----------------------------
# Use debian:trixie-slim (testing) which has GLIBC 2.39+
# Or use the same rust image for consistency
FROM debian:trixie-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libc6 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the compiled binary from the builder
COPY --from=builder /app/target/release/fmhub-api /usr/local/bin/fmhub-api

EXPOSE 3000

# Run the server
CMD ["fmhub-api"]