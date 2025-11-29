# Foundry90

Foundry90 is a 90-day systems engineering curriculum for builders who want to become full-stack, platform-capable engineers.

The program combines:

- Next.js + TypeScript (frontend + full-stack web)
- Rust (backend services)
- Python (ETL, data pipelines)
- Postgres + Redis (data + caching)
- Docker + AWS + Vercel (deployment & ops)
- SwiftUI (optional native client)

The goal is **breadth + glue + engineering judgment**, not just "learn a language."

Everyone following Foundry90 builds **their own capstone project** – your implementation, your decisions.

---

## 🚀 Quick Start

### New to Foundry90?

1. **Check prerequisites** – Read [`curriculum/prerequisites.md`](./curriculum/prerequisites.md) to see if this is right for you
2. **Read the overview** – Start with [`curriculum/01_overview_and_syllabus.md`](./curriculum/01_overview_and_syllabus.md)
3. **Get the starter kit** – Follow the guide in [`starter-kit/README.md`](./starter-kit/README.md)
4. **Start building** – Work through [`curriculum/03_weekly_exercises.md`](./curriculum/03_weekly_exercises.md)

### Just want the curriculum?

Go to [`curriculum/`](./curriculum) and start with [`01_overview_and_syllabus.md`](./curriculum/01_overview_and_syllabus.md).

---

## 📂 Repository Structure

```
foundry90/
├── curriculum/           # Complete learning materials
│   ├── 01_overview_and_syllabus.md
│   ├── 02_readings.md
│   ├── 03_weekly_exercises.md
│   ├── 04_repo_template.md
│   ├── 05_architecture.md
│   ├── 06_rubric.md
│   ├── 07_capstone_guide.md
│   ├── prerequisites.md
│   └── glossary.md
│
├── starter-kit/          # Project templates
│   ├── monorepo_template/  # Ready-to-use monorepo structure
│   └── README.md
│
├── capstones/            # Student capstone projects
│   └── <student-name>/     # Individual implementations
│
├── reference/            # Code examples and patterns
│   └── README.md
│
├── docs/                 # Visual assets, diagrams, documentation
│   └── README.md
│
└── README.md            # This file
```

---

## 📚 Documentation Guide

### For Learning

- **[Curriculum](./curriculum/)** – Complete 90-day program with exercises, readings, and guides
- **[Prerequisites](./curriculum/prerequisites.md)** – Who this course is for and what you need
- **[Glossary](./curriculum/glossary.md)** – Plain-language explanations of technologies

### For Building

- **[Starter Kit](./starter-kit/README.md)** – Get started with the monorepo template
- **[Monorepo Template](./starter-kit/monorepo_template/README.md)** – Detailed guide to the template structure
- **[Repo Template Guide](./curriculum/04_repo_template.md)** – Architecture and structure decisions

### For Reference

- **[Reference Implementations](./reference/README.md)** – Code examples and patterns (growing collection)
- **[Documentation](./docs/README.md)** – Visual assets, diagrams, and supporting materials
- **[Example Capstones](./capstones/)** – See how others have implemented their projects

### For Contributing

- **[Contributing Guide](./CONTRIBUTING.md)** – How to contribute to Foundry90
- **[Code of Conduct](./CODE_OF_CONDUCT.md)** – Community guidelines

---

## 🎯 How to Use This Repo

### Option 1: Just Learn

If you want to follow the curriculum without building a capstone:

1. Read [`curriculum/01_overview_and_syllabus.md`](./curriculum/01_overview_and_syllabus.md)
2. Work through [`curriculum/03_weekly_exercises.md`](./curriculum/03_weekly_exercises.md)
3. Use the readings in [`curriculum/02_readings.md`](./curriculum/02_readings.md)

### Option 2: Build Your Capstone

If you want to build your own project:

1. Read the [Overview & Syllabus](./curriculum/01_overview_and_syllabus.md)
2. Check the [Starter Kit Guide](./starter-kit/README.md)
3. Copy the monorepo template:

   ```bash
   cp -R starter-kit/monorepo_template ./my-capstone
   mkdir -p capstones/<your-name>
   mv my-capstone capstones/<your-name>/
   ```

4. Follow the [weekly exercises](./curriculum/03_weekly_exercises.md)
5. Build your capstone following the [capstone guide](./curriculum/07_capstone_guide.md)

### Option 3: Study Examples

If you want to see working implementations:

1. Browse [`capstones/`](./capstones/) to see completed projects
2. Check [`reference/`](./reference/) for code examples and patterns
3. Review architecture in [`docs/`](./docs/) for diagrams and visual guides