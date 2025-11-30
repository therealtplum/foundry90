# Foundry90 Starter Kit

The **Starter Kit** provides a ready-to-use template for beginning your Foundry90 capstone project. It includes the recommended monorepo structure, placeholder files, and basic configuration to get you started quickly.

---

## What's Included

### Monorepo Template

The `monorepo_template/` directory contains:

- **Pre-configured folder structure** following Foundry90 best practices
- **Placeholder directories** for web, backend, and ETL apps
- **Docker Compose setup** for local development
- **Workspace configurations** for pnpm (Node.js) and Cargo (Rust)
- **Basic README files** in each app directory with next steps

### Structure Overview

```
monorepo_template/
├── apps/
│   ├── web/              # Next.js frontend (to be initialized)
│   ├── rust-api/         # Rust backend (to be initialized)
│   └── python-etl/       # Python ETL scripts (to be initialized)
├── services/
│   └── db/               # Database migrations and schemas
├── infra/
│   └── docker/           # Docker-related documentation
├── docker-compose.yml    # Multi-service development setup
├── package.json          # pnpm workspace configuration
└── Cargo.toml            # Rust workspace configuration
```

---

## Quick Start

### 1. Copy the Template

```bash
# From the foundry90 root directory
cp -R starter-kit/monorepo_template ./my-capstone
```

### 2. Move to Your Capstone Directory

```bash
# Create your personal capstone directory
mkdir -p capstones/<your-name>

# Move the template there
mv my-capstone capstones/<your-name>/
cd capstones/<your-name>/
```

### 3. Initialize Your Apps

The template provides placeholders. You'll need to initialize each app:

#### Web App (Next.js)

```bash
cd apps/web
npx create-next-app@latest . --typescript --tailwind --app --no-src-dir
```

#### Rust API

```bash
cd apps/rust-api
cargo init --name fmhub-api
# Then add dependencies: axum, tokio, serde, etc.
```

#### Python ETL

```bash
cd apps/python-etl
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows
pip install httpx pandas psycopg2-binary
```

### 4. Configure Environment Variables

Create a `.env` file in the root of your monorepo:

```bash
# Database
DATABASE_URL=postgres://postgres:password@localhost:5432/foundry90

# Redis
REDIS_URL=redis://localhost:6379

# API
NEXT_PUBLIC_API_URL=http://localhost:3001
```

### 5. Start Your Stack

```bash
# Make sure Docker is running, then:
docker-compose up
```

This will start:
- Postgres database (port 5432)
- Redis cache (port 6379)
- Your web app (port 3000) - once initialized
- Your Rust API (port 3001) - once initialized
- Your Python ETL - once initialized

---

## What the Template Provides

### ✅ Pre-configured Structure

The folder layout follows Foundry90 best practices as outlined in [`curriculum/04_repo_template.md`](../curriculum/04_repo_template.md).

### ✅ Docker Compose Setup

A working `docker-compose.yml` that:
- Defines all services (web, rust-api, python-etl, db, redis)
- Sets up service dependencies
- Configures environment variables
- Exposes necessary ports

### ✅ Workspace Configurations

- **`package.json`** – Configured for pnpm workspaces
- **`Cargo.toml`** – Configured for Rust workspaces

### ✅ Placeholder READMEs

Each app directory has a README with:
- What that app is for
- Suggested next steps
- Links to relevant documentation

---

## What You Need to Add

### 1. Actual Application Code

The template is just structure – you'll build:
- Your Next.js pages and components
- Your Rust API handlers and business logic
- Your Python ETL scripts

### 2. Dockerfiles

Each app needs a `Dockerfile`:
- `apps/web/Dockerfile`
- `apps/rust-api/Dockerfile`
- `apps/python-etl/Dockerfile`

### 3. Database Schema

Create migrations in `services/db/`:
- Initial schema
- Seed data scripts
- Migration files

### 4. Environment Configuration

- `.env` file for local development
- `.env.example` as a template
- Production environment variables (stored securely, not in repo)

---

## Customization

### Changing Service Names

If you want different names (e.g., `backend` instead of `rust-api`):

1. Rename the directories
2. Update `docker-compose.yml` service names and build contexts
3. Update environment variable references
4. Update workspace configurations if needed

### Adding New Services

To add a new service (e.g., a worker service):

1. Create `apps/worker/` directory
2. Add service definition to `docker-compose.yml`
3. Add Dockerfile in the new directory
4. Update dependencies as needed

### Using Different Technologies

The template assumes:
- Next.js for frontend
- Rust + Axum for backend
- Python for ETL

You can swap these out, but you'll need to:
- Update the folder structure
- Modify `docker-compose.yml`
- Adjust workspace configurations
- Update documentation

---

## Next Steps

1. **Read the curriculum** – Start with [`curriculum/01_overview_and_syllabus.md`](../curriculum/01_overview_and_syllabus.md)
2. **Follow weekly exercises** – Work through [`curriculum/03_weekly_exercises.md`](../curriculum/03_weekly_exercises.md)
3. **Build your capstone** – Use this template as your starting point
4. **Reference examples** – Check `capstones/` for working implementations

---

## Troubleshooting

### Docker Compose Issues

- **Port conflicts**: Make sure ports 3000, 3001, 5432, 6379 aren't already in use
- **Build failures**: Ensure Dockerfiles exist in each app directory
- **Service won't start**: Check logs with `docker-compose logs <service-name>`

### Workspace Issues

- **pnpm not found**: Install pnpm: `npm install -g pnpm`
- **Cargo not found**: Install Rust: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`

### Environment Issues

- **Database connection fails**: Ensure Postgres container is running and environment variables are correct
- **API not reachable**: Check that services are started in the correct order (db → redis → rust-api → web)

---

## Getting Help

- Check the [curriculum documentation](../curriculum/)
- Review existing capstones in `capstones/`
- Look for reference implementations in `reference/` (as they're added)
- File an issue if you find a bug in the template itself

---

## Philosophy

The starter kit is intentionally **minimal**. It provides:

- Structure, not implementation
- Scaffolding, not solutions
- A starting point, not a finished product

The real learning in Foundry90 happens when you build your own implementation. Use this template as a foundation, then make it your own.

