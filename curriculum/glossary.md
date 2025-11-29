# Foundry90 – Glossary & Technology Guide (Beginner-Friendly)

Foundry90 uses a variety of technologies — each chosen because it’s practical, modern, and industry-relevant.

This glossary explains **what everything is**, **why it matters**, and **how to think about it** in plain English.

---

## Python – Automating things and moving data

**What it is:**  
A programming language that’s fantastic for:

- automating manual tasks
- working with data
- talking to APIs
- scripting and glue code

**Why Foundry90 uses it:**

- It’s great for ETL: Extract → Transform → Load.
- It’s widely used in data engineering, finance, and scripting.

**What it’s good at:**

- Fetching data from APIs or files.
- Cleaning and transforming data.
- Loading data into databases.
- Building quick internal tools.

**Starter hints:**

- Use `print()` liberally while learning.
- Learn `requests` or `httpx` for talking to HTTP APIs.
- Keep scripts short and focused.
- Remember the main data flow: **fetch → transform → load**.

---

## Rust – Fast, safe backend services

**What it is:**  
A modern systems language focused on performance and safety.

**Why Foundry90 uses it:**

- Great for backend APIs that need to be reliable and fast.
- Increasingly used in high-performance systems, including trading infrastructure.

**What it’s good at:**

- Long-running backend services.
- Concurrent workloads.
- High-performance APIs.
- Careful error handling.

**Starter hints:**

- Don’t panic about ownership/borrowing — it clicks over time.
- Start with small programs and build up.
- Use Axum as your web framework to avoid getting lost in the weeds.
- Let the compiler teach you; errors are guidance, not punishment.

---

## TypeScript – JavaScript with safety rails

**What it is:**  
JavaScript plus static types.

**Why Foundry90 uses it:**

- It makes frontend and full-stack web code more reliable.
- It gives you better autocomplete and catches bugs early.

**What it’s good at:**

- Writing safer React/Next.js components.
- Defining shapes of data (interfaces, types).
- Making large codebases reasonable to work with.

**Starter hints:**

- Think of interfaces as “contracts” for objects.
- Avoid `any` if you can.
- Let your editor guide you via autocomplete and error hints.

---

## Next.js – Your web application framework

**What it is:**  
A framework built on React for building full-stack web apps.

**Why Foundry90 uses it:**

- First-class support for React Server Components.
- File-based routing and layouts.
- Built-in data-fetching patterns.
- Easy deployment on Vercel.

**What it’s good at:**

- Dashboards and internal tools.
- Admin panels.
- Public websites with dynamic data.
- Anything where you want a modern web UI backed by APIs.

**Starter hints:**

- Server Components: great for fetching data on the server.
- Client Components: great for interactive bits (buttons, forms, toggles).
- Tailwind can simplify styling a lot.

---

## Postgres – Your main database

**What it is:**  
A relational database (think tables, rows, and columns).

**Why Foundry90 uses it:**

- Rock-solid.
- Very widely used.
- A great default for most web systems.

**What it’s good at:**

- Storing structured data.
- Supporting transactional workloads (lots of small reads/writes).
- Running complex queries and joins.

**Starter hints:**

- Think of tables as spreadsheets that can link to each other.
- Primary keys uniquely identify rows.
- Foreign keys link tables.
- Indexes make frequent queries fast.

---

## Redis – Fast in-memory cache

**What it is:**  
An in-memory key-value store (a super fast cache).

**Why Foundry90 uses it:**

- Great for caching hot API responses.
- Helps avoid hitting Postgres on every single request.

**What it’s good at:**

- Caching computed results.
- Rate limiting.
- Short-lived data like sessions or temporary tokens.
- Keeping small bits of data very close to your app, very fast.

**Starter hints:**

- Use it for things that can be recomputed if needed.
- Don’t treat it as your only source of truth.

---

## Docker – Packaging your services

**What it is:**  
A way to package code and its dependencies into containers that run anywhere.

**Why Foundry90 uses it:**

- Ensures your stack runs the same on your machine and in the cloud.
- Makes multi-service dev much easier to manage.

**What it’s good at:**

- Local development environments.
- Reproducible builds.
- Cloud deployments.

**Starter hints:**

- One Dockerfile per service.
- `docker-compose` to run everything at once.
- Early on, you’ll mostly copy known patterns.

---

## AWS – Where your system lives

**What it is:**  
A cloud provider – servers, databases, storage, logs, and much more.

**Why Foundry90 uses it:**

- Industry standard.
- Gives you experience with real cloud deployments.

**Core services you’ll touch:**

- ECS – runs containers.
- RDS – managed Postgres.
- CloudWatch – logs and metrics.
- IAM – permissions and access control.
- Secrets Manager – storing secrets safely.

You can use another cloud if you prefer, but the concepts carry over.

---

## ETL – Extract, Transform, Load

**What it is:**  
A classic data pipeline pattern:

- Extract: get data from somewhere (API, file, feed).
- Transform: change it into the shape you want.
- Load: store it into a target database or system.

**Why it matters:**

- Almost every serious system has data pipelines.
- Python is extremely good at them.

---

## API – Application Programming Interface

**What it is:**  
Simply: an interface your backend exposes:

- Requests in (usually HTTP, JSON).
- Responses out (usually JSON).

**Why it matters:**

- Your frontend, native client, and other services all talk to your system through APIs.

---

## Monorepo

**What it is:**  
A single repo that contains:

- frontend
- backend
- ETL
- infra

**Why it matters:**

- Easier coordination.
- Single source of truth for your system.

---

## Observability

**What it is:**

- Being able to answer: “What is my system doing?” and “Why did this break?”

Includes:

- logs
- metrics
- alerts
- health checks

---

## Environments

**What they are:**

- Different “places” your system runs:
  - local (your machine)
  - dev
  - staging
  - production

**Key idea:**

- Same code, different configuration (env vars, URLs, secrets).

---

## If this glossary made sense

You’re ready for Foundry90.

If it felt overwhelming, but curious-making: you can still do it – just move at your own pace and lean hard on Week 1 as "orientation week."

---

## Related Documentation

- **Prerequisites:** See [`prerequisites.md`](./prerequisites.md) to assess if you're ready
- **Readings:** Check [`02_readings.md`](./02_readings.md) for learning resources
- **Weekly Exercises:** Start building with [`03_weekly_exercises.md`](./03_weekly_exercises.md)