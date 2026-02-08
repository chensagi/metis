# metis

Self-evolving swarm orchestration for Claude Code. Ships with capability profiles that teach agents about your project's technology stack, plus learning that improves over time.

**Core principle:** Deliver at the lowest cost possible. Every token is currency. Ask → Explore → Research → Plan → Execute.

## Architecture: 3-Layer

| Layer | Component | Role |
|-------|-----------|------|
| **L0 — Platform** | Claude Code (any model) | User session, dispatcher for complex skills |
| **L1 — Spine** | Opus (spawned when needed) | Thinking, judgment, research direction, evaluation |
| **L2 — Leaves** | Sonnet/Haiku/Ollama | Implementation, exploration, web research retrieval |

**Opus thinks. Agents do. Opus decides.** No nested spawning — L0 handles all agent spawning.

- **Dispatcher skills** (swarm, large triage): L0 alternates between Opus (judgment) and Sonnet/Haiku (work). User session can run on any model.
- **Direct skills** (task, install, learn): Opus runs in chat context for interactive work.

### Capability Subsetting

When spawning agents, inject ONLY capabilities relevant to the specific work item — not the full installed set. The orchestrator matches work item scope against capability `provides` tags:

- Backend task → skip ios-simulator, maestro, react-native
- UI task → skip backend-specific capabilities
- Type-only task → only typescript

This reduces prompt size by 60-80% for focused tasks.

## Skills

### `/help` — Front Door
Show available Metis skills, project status, and contextual guidance. Context-aware — detects whether you're in the Metis repo, an installed project, a project with another orchestrator, or a fresh project, and tailors output accordingly. Supports `/help <skill>` for detailed help, `/help status` for a project dashboard, `/help workflow` for the cost model, and `/help getting-started` for onboarding. **Cost: Free (read-only).**

### `/install` — Project Setup
Interactive, idempotent setup. Detects project type, suggests a profile, installs capabilities, configures commands. Safe to run multiple times — updates mode shows what's changed. Now detects existing AI orchestrator configs and suggests `/migrate` first. **Cost: Opus only.**

### `/migrate` — Orchestrator Migration
Migrate from another AI orchestrator (Cursor, Copilot, Windsurf, Aider, Continue, Roo Code, Cline) to Metis. Reads existing configs, runs a thorough multi-round interview, and converts everything to Metis format — profile, capabilities, commands, and optionally a custom capability for project-specific rules. Never deletes source files. **Cost: Opus only.**

### `/swarm` — Parallel Task Orchestration
Spawns background agents to work on tasks in parallel. Thinks before spawning — explores the codebase and designs work items before dispatching agents. Run in a dedicated session.
- 4-agent cap, incremental TaskOutput, two-phase fix flow
- Budget tracking with `--budget N`, controlled mode with `--controlled`
- Integration testing with `/swarm integrate`, test swarm with `/swarm test`
- Capability subsetting: each agent gets only relevant capabilities
- **Cost: Opus + Sonnet/Haiku.**

### `/task` — Single-Task Workflow
Pick up one task, clarify requirements, **plan the implementation approach** (explore codebase, design, get user approval), then implement following installed capabilities, verify, and ship. Use `--super-ask` for thorough multi-round questioning (requirements, edge cases, architecture, testing) before planning. Can be set as default via `"ask_mode": "super-ask"` in config. **Cost: Opus + Sonnet/Haiku.**

### `/triage` — Codebase-Aware Backlog Auditor
Analyzes tasks against the codebase. Detects DONE, PARTIAL, STALE, BLOCKED, READY, QUESTIONABLE tasks. Creates/updates `.metis/tasks/project.md`. Also supports `/triage create "task title"`. **Cost: Opus + Haiku.**

### `/ship` — PR + Merge
Creates branch, commits, pushes, creates PR, waits for CI, merges. **Cost: Opus only.**

### `/learn` — Analyze & Suggest
Haiku-powered analysis that finds missing capabilities, config improvements, and custom skill opportunities. Auto-triggers after swarm/task (configurable). `/learn --deep` for thorough analysis. **Cost: Opus + Haiku.**

### `/add-metiskill` — Custom Skill Creator
Scaffolds project-specific skills in `.metis/skills/`. Scans codebase to pre-populate, pulls patterns from installed capabilities. **Cost: Opus only.**

### `/scaffold-skill` — Core Skill Generator
Creates a new core skill in `plugins/metis-core/skills/` with proper frontmatter, architecture sections, and agent prompt templates. Asks for skill type (consumer direct, consumer dispatcher, repo management) and generates the appropriate structure. **Cost: Opus only. Repo management skill.**

### `/validate` — Convention Linter
Lint and validate SKILL.md and capability.md files for convention compliance. Checks frontmatter, structure, architecture rules, and cross-references against the registry. Run `/validate --all` or `/validate {name}`. **Cost: Opus only. Repo management skill.**

### `/add-capability` — Registry Management
Add a new capability to the metis-core registry. Creates the capability file, updates registry.json, and optionally adds it to profiles. **Cost: Opus only. Repo management skill.**

### `/pull-capability` — Community Import
Pull a community capability from a git repo URL or local path into the metis-core registry. Validates format and registers it. **Cost: Opus only. Repo management skill.**

### `/release` — Version & Tag
Create a new metis release — bump version, update registry, create git tag, and optionally push. **Cost: Opus only. Repo management skill.**

## Capabilities

Capabilities are markdown files with YAML frontmatter that teach agents about specific technologies:

| Capability | Description |
|-----------|-------------|
| `typescript` | Type checking, compilation, import conventions |
| `react-native` | Native primitives, StyleSheet, component patterns |
| `expo` | Expo CLI, Metro, OTA updates, Router |
| `ios-simulator` | Screenshots, simctl, visual verification |
| `maestro` | E2E test automation, YAML flows, testIDs |
| `zustand` | State management, MMKV persistence |
| `python` | Virtual environments, pytest, ruff |
| `go` | Modules, toolchain, testing |
| `rust` | Cargo, clippy, ownership patterns |
| `metis-dev` | Skill format, capability format, architecture patterns for Metis repo development |

### Adding Capabilities

Community capabilities: submit a PR adding a new `capabilities/{name}/capability.md`.

Format:
```markdown
---
name: capability-name
version: 0.1.0
description: What this capability provides
requires: [dependency-capabilities]
provides:
  - feature-tag-1
  - feature-tag-2
commands:
  verify: "command to verify"
---

# Capability Name

## Agent Instructions

[Instructions injected into agent prompts]
```

## Profiles

Profiles bundle capabilities with sensible defaults:

| Profile | Capabilities |
|---------|-------------|
| `react-native-expo` | typescript, react-native, expo, ios-simulator, maestro |
| `typescript-node` | typescript |
| `python-fastapi` | python |
| `go-service` | go |
| `metis-dev` | metis-dev |

## Versioning

- **v0.1.0** — Initial release with 10 capabilities, 5 profiles, 14 skills
- Capabilities have independent semver in frontmatter
- Consumer projects pin versions in `.metis/capabilities/manifest.json`
- Metis repo uses git tags for stable snapshots
