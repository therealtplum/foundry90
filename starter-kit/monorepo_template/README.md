# Foundry90 Monorepo Template

This is a **starter template** for your Foundry90 capstone project. It provides the recommended folder structure, basic configuration files, and a Docker Compose setup to get you started quickly.

---

## 📁 Directory Structure

```
.
├── apps/
│   ├── web/              # Next.js frontend application
│   ├── rust-api/         # Rust backend API (Axum)
│   └── python-etl/       # Python ETL/data pipeline scripts
├── services/
│   └── db/               # Database migrations, schemas, seed data
├── infra/
│   └── docker/           # Docker-related documentation and configs
├── docker-compose.yml    # Multi-service development environment
├── package.json          # pnpm workspace root configuration
└── Cargo.toml            # Rust workspace root configuration
```

---

## 🚀 Getting Started

### Step 1: Initialize Each Application

This template provides the structure, but you need to initialize each app with real code.

#### Web App (Next.js)

```bash
cd apps/web
npx create-next-app@latest . --typescript --tailwind --app --no-src-dir
```

**What to configure:**
- Set `NEXT_PUBLIC_API_URL` in your `.env.local` to point to your Rust API
- Configure API routes or server actions to communicate with the backend
- Build your UI components and pages

**See:** `apps/web/README.md` for more details

#### Rust API

```bash
cd apps/rust-api
cargo init --name your-api-name
```

**Add dependencies to `Cargo.toml`:**
```toml
[dependencies]
axum = "0.7"
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
sqlx = { version = "0.7", features = ["runtime-tokio-native-tls", "postgres"] }
redis = { version = "0.24", features = ["tokio-comp"] }
tracing = "0.1"
tracing-subscriber = "0.3"
thiserror = "1"
```

**See:** `apps/rust-api/README.md` for more details

#### Python ETL

```bash
cd apps/python-etl
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

**Create `requirements.txt`:**
```txt
httpx>=0.25.0
pandas>=2.0.0
psycopg2-binary>=2.9.0
python-dotenv>=1.0.0
```

**See:** `apps/python-etl/README.md` for more details

### Step 2: Set Up Environment Variables

Create a `.env` file in the root of this monorepo:

```bash
# Database
DATABASE_URL=postgres://postgres:password@db:5432/foundry90
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
POSTGRES_DB=foundry90

# Redis
REDIS_URL=redis://redis:6379

# API Configuration
NEXT_PUBLIC_API_URL=http://localhost:3001
API_PORT=3001

# Python ETL
PYTHON_ETL_DB=postgres://postgres:password@db:5432/foundry90
```

**Important:** Also create a `.env.example` file (without sensitive values) to document required variables.

### Step 3: Create Dockerfiles

Each app needs a `Dockerfile`. Here are minimal examples:

#### `apps/web/Dockerfile`
```dockerfile
FROM node:20-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm install -g pnpm
RUN pnpm install

FROM base AS build
COPY . .
RUN pnpm build

FROM base AS runtime
COPY --from=build /app/.next ./.next
COPY --from=build /app/public ./public
COPY --from=build /app/package.json ./
EXPOSE 3000
CMD ["pnpm", "start"]
```

#### `apps/rust-api/Dockerfile`
```dockerfile
FROM rust:1.75 AS builder
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/your-api-name /usr/local/bin/api
EXPOSE 3001
CMD ["/usr/local/bin/api"]
```

#### `apps/python-etl/Dockerfile`
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "main.py"]
```

### Step 4: Set Up Database

Create your initial schema in `services/db/schema.sql`:

```sql
-- Example schema
CREATE TABLE IF NOT EXISTS instruments (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(50) UNIQUE NOT NULL,
    name TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_instruments_symbol ON instruments(symbol);
```

You can also create migration scripts or use a migration tool like `sqlx migrate` or `alembic`.

### Step 5: Start the Stack

```bash
# Make sure Docker is running
docker-compose up
```

This will:
1. Build images for each service (if Dockerfiles exist)
2. Start Postgres and Redis
3. Start your web, API, and ETL services
4. Set up networking between services

**Access your services:**
- Web: http://localhost:3000
- API: http://localhost:3001
- Postgres: localhost:5432
- Redis: localhost:6379

---

## 🏗️ Understanding the Structure

### Apps Directory

Each app is a **separate service** that can:
- Be developed independently
- Have its own dependencies
- Be deployed separately (if needed)
- Communicate with other services via APIs or shared databases

### Services Directory

Infrastructure services that support your apps:
- **`db/`** – Database schemas, migrations, seed scripts
- Future: Could include Redis configs, message queue configs, etc.

### Infra Directory

Infrastructure-as-code and deployment-related files:
- **`docker/`** – Docker-specific documentation
- Future: Could include Terraform, CloudFormation, Kubernetes configs

### Root Files

- **`docker-compose.yml`** – Defines all services and their relationships
- **`package.json`** – pnpm workspace configuration for Node.js apps
- **`Cargo.toml`** – Rust workspace configuration for Rust apps

---

## 🔧 Development Workflow

### Running Services Individually

You don't always need to run everything:

```bash
# Just database and Redis
docker-compose up db redis

# Then run apps locally for faster iteration
cd apps/web && pnpm dev
cd apps/rust-api && cargo run
```

### Viewing Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f rust-api
```

### Rebuilding After Changes

```bash
# Rebuild a specific service
docker-compose build rust-api
docker-compose up rust-api

# Rebuild everything
docker-compose build
docker-compose up
```

### Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (⚠️ deletes data)
docker-compose down -v
```

---

## 📝 Next Steps

1. **Initialize your apps** – Follow the steps above for web, rust-api, and python-etl
2. **Build your first feature** – Start with a simple health check endpoint
3. **Connect services** – Make your web app call your API
4. **Set up your ETL** – Create a script that loads data into Postgres
5. **Follow the curriculum** – Work through [`curriculum/03_weekly_exercises.md`](../../curriculum/03_weekly_exercises.md)

---

## 🎯 Foundry90 Alignment

This template aligns with the Foundry90 curriculum:

- **Week 1-4**: You'll build out each app individually
- **Week 5**: You'll refine this monorepo structure
- **Week 6**: You'll improve the Docker setup
- **Week 7**: You'll deploy these services
- **Week 8-12**: You'll integrate everything into your capstone

---

## 🐛 Troubleshooting

### Port Already in Use

If you get "port already in use" errors:
- Check what's using the port: `lsof -i :3000` (macOS/Linux) or `netstat -ano | findstr :3000` (Windows)
- Change the port in `docker-compose.yml` or stop the conflicting service

### Services Can't Connect

- Ensure services are started in the correct order (db → redis → rust-api → web)
- Check that environment variables match between services
- Verify network names in `docker-compose.yml` (services can reference each other by service name)

### Build Failures

- Make sure Dockerfiles exist in each app directory
- Check that dependencies are properly specified (package.json, Cargo.toml, requirements.txt)
- Review build logs: `docker-compose build --no-cache <service>`

### Database Connection Issues

- Ensure Postgres container is running: `docker-compose ps`
- Check connection string format: `postgres://user:password@host:port/dbname`
- Verify environment variables are set correctly

---

## 📚 Additional Resources

- **Curriculum**: [`../../curriculum/`](../../curriculum/) – Full learning materials
- **Repo Template Guide**: [`../../curriculum/04_repo_template.md`](../../curriculum/04_repo_template.md) – Detailed structure explanation
- **Starter Kit Guide**: [`../README.md`](../README.md) – Overview of the starter kit
- **Example Capstones**: [`../../capstones/`](../../capstones/) – See how others structured their projects

---

## 💡 Tips

- **Start simple**: Get one service working end-to-end before adding complexity
- **Use local development**: Run apps locally (not in Docker) during active development for faster iteration
- **Commit often**: This is your capstone – treat it like a real project
- **Read the curriculum**: The weekly exercises will guide you through building each piece
- **Ask questions**: Check existing capstones or file issues if you're stuck

---

**Remember**: This is a template, not a finished product. The real learning happens when you build your own implementation. Use this as a foundation, then make it your own! 🚀

