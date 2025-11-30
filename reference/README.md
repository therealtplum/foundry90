# Foundry90 Reference Implementations

This directory is intended to house **reference implementations** and **example code** that demonstrate best practices, patterns, and solutions for common problems encountered during the Foundry90 curriculum.

---

## What is a Reference Implementation?

A reference implementation is a **working example** that shows:

- How to structure code for a specific task
- Best practices for a particular technology or pattern
- Solutions to common problems you'll encounter
- Real-world patterns that go beyond tutorials

Reference implementations are **not** meant to be copied blindly, but rather:

- **Studied** to understand patterns and decisions
- **Referenced** when you're stuck on a similar problem
- **Adapted** to fit your own capstone project's needs

---

## Types of Reference Content

### Code Examples

Small, focused examples showing:

- How to structure a Rust Axum handler
- Next.js Server Component data fetching patterns
- Python ETL pipeline structure
- Database migration patterns
- Docker multi-stage builds
- Environment variable management

### Architecture Patterns

Examples of:

- Service communication patterns
- Error handling strategies
- Caching strategies
- Authentication/authorization flows
- Data pipeline architectures

### Configuration Examples

Working examples of:

- `docker-compose.yml` configurations
- Environment variable setups
- CI/CD pipeline configurations
- Database schema designs

---

## How to Use References

### 1. When You're Learning a New Concept

If you're working through Week 2 (Rust backend) and struggling with error handling, look for a reference implementation that shows a clean error handling pattern.

### 2. When You're Stuck

If you've been trying to solve something for a while and aren't making progress, check if there's a reference that solves a similar problem.

### 3. When You Want to See Best Practices

Before implementing something new, check references to see how others have approached similar problems.

### 4. When You're Reviewing Your Own Code

Compare your implementation to references to see if there are patterns you could adopt or improvements you could make.

---

## Contributing References

If you've built something during Foundry90 that you think would help others, consider contributing it as a reference:

1. **Keep it focused** – One reference per file/pattern
2. **Add comments** – Explain the "why" not just the "what"
3. **Include context** – What problem does this solve?
4. **Make it runnable** – If it's code, it should work
5. **Document dependencies** – What do you need to run this?

---

## Structure (Future)

As references are added, they might be organized like:

```
reference/
  rust/
    error_handling.rs
    middleware_patterns.rs
  nextjs/
    server_components.md
    api_routes.ts
  python/
    etl_patterns.py
    websocket_client.py
  docker/
    multi_stage_builds.md
    compose_examples.yml
  architecture/
    service_communication.md
    caching_strategies.md
```

---

## Current Status

This directory is currently a placeholder. As the Foundry90 community grows and capstones are completed, reference implementations will be added here.

If you're looking for working examples right now, check out the capstones in `capstones/` – they serve as real-world reference implementations of the full Foundry90 stack.

---

## Relationship to Other Directories

- **`curriculum/`** – The learning materials and exercises
- **`starter-kit/`** – The template to start your own project
- **`capstones/`** – Full project implementations (more complex than references)
- **`reference/`** – Focused examples and patterns (this directory)
- **`docs/`** – Documentation, diagrams, and visual assets

