# Foundry90 – Repo Template

This document describes the recommended repo layout for your capstone.

The starter kit in [`starter-kit/monorepo_template`](../starter-kit/monorepo_template) implements this structure with placeholder files.

---

## Folder layout

```text
apps/
  web/         # Next.js frontend
  rust-api/    # Rust backend (Axum)
  python-etl/  # Python ETL/pipelines

services/
  db/          # Migrations, seed scripts

infra/
  docker/      # Dockerfiles, infra notes

.env.example
docker-compose.yml
package.json   # pnpm workspace config
Cargo.toml     # Rust workspace config
```

**Goals of the structure**

- Keep frontend, backend, ETL, and DB logically isolated.
- Make it easy to run everything via `docker-compose up`.
- Support local dev and production with minimal differences.
- Establish predictable paths for collaborators and future contributors.

---

## Monorepo concepts

A monorepo groups all your services under one roof:

- shared CI workflows  
- consistent environment files  
- easier cross-service editing  
- no multi-repo dependency hell  

You can modify this structure later, but this is a strong default.

---

## Getting started with the template

1. Copy the template:

   ```bash
   cp -R starter-kit/monorepo_template ./my-capstone
   ```

2. Move it under your personal capstone folder:

   ```bash
   mkdir -p capstones/<your-name>
   mv my-capstone capstones/<your-name>/
   ```

3. Initialize real apps:
   - **apps/web** → create a Next.js app  
   - **apps/rust-api** → create a Rust Axum project  
   - **apps/python-etl** → set up a Python project  

4. Edit Dockerfiles, `.env`, scripts, and database setup to match your system.

This template provides scaffolding — your implementation is where the real Foundry90 work happens.

---

## Related Documentation

- **Starter Kit:** See [`../starter-kit/README.md`](../starter-kit/README.md) for detailed setup instructions
- **Monorepo Template:** See [`../starter-kit/monorepo_template/README.md`](../starter-kit/monorepo_template/README.md) for the full template guide
- **Weekly Exercises:** Week 5 in [`03_weekly_exercises.md`](./03_weekly_exercises.md) covers monorepo setup
- **Architecture:** See [`05_architecture.md`](./05_architecture.md) for how services communicate
