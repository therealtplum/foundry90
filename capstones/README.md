# Foundry90 Capstones

This folder contains **capstone projects** — the final deliverable of the Foundry90 program.

A capstone is a **fully built, end-to-end system** that demonstrates your mastery across:

- frontend  
- backend  
- data pipelines  
- databases  
- infrastructure  
- documentation  
- architectural reasoning  

Every participant builds *their own unique system*.

---

## 📂 Structure

Each capstone lives in its own folder:

```
capstones/
  <your-name>/
    apps/
    services/
    infra/
    docs/
    README.md
```

The structure mirrors the template in `starter-kit/monorepo_template`.

---

## 🧩 How to Add Your Own Capstone

1. Create a new folder:

   ```bash
   mkdir -p capstones/<your-name>
   ```

2. Copy the starter monorepo template:

   ```bash
   cp -R starter-kit/monorepo_template/* capstones/<your-name>/
   ```

3. Begin implementing your system:
   - Build out your `apps/web`
   - Build your Rust API in `apps/rust-api`
   - Build your ETL in `apps/python-etl`
   - Add migrations under `services/db`

4. Write a `README.md` inside your capstone folder that explains:
   - what you built  
   - architecture  
   - how to run it  
   - design decisions  

5. (Optional) Open a PR to contribute your capstone to the main repo.

---

## 🤝 Community Capstones

Anyone is welcome to fork Foundry90, complete the curriculum, and open a PR to add their capstone under:

```
capstones/<your-name>/
```

Please only submit **original work** that follows the repo structure.
