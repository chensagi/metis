# metis-core

Self-evolving swarm orchestration for Claude Code. Ships with capability profiles that teach agents about your project's technology stack, plus learning that improves over time.

## Skills

### `/install` — Project Setup
Interactive, idempotent setup. Detects project type, suggests a profile, installs capabilities, configures commands. Safe to run multiple times — updates mode shows what's changed.

### `/swarm` — Parallel Task Orchestration
Spawns background agents to work on tasks in parallel. Capabilities are injected into agent prompts automatically.
- 4-agent cap, incremental TaskOutput, two-phase fix flow
- Budget tracking with `--budget N`, controlled mode with `--controlled`
- Integration testing with `/swarm integrate`, test swarm with `/swarm test`

### `/task` — Single-Task Workflow
Pick up one task, clarify requirements, implement (following installed capabilities), verify, and ship.

### `/triage` — Codebase-Aware Backlog Auditor
Analyzes tasks against the codebase. Detects DONE, PARTIAL, STALE, BLOCKED, READY, QUESTIONABLE tasks. Creates/updates `.metis/tasks/project.md`. Also supports `/triage create "task title"`.

### `/ship` — PR + Merge
Creates branch, commits, pushes, creates PR, waits for CI, merges.

### `/learn` — Analyze & Suggest
Haiku-powered analysis that finds missing capabilities, config improvements, and custom skill opportunities. Auto-triggers after swarm/task (configurable). `/learn --deep` for thorough analysis.

### `/add-metiskill` — Custom Skill Creator
Scaffolds project-specific skills in `.metis/skills/`. Scans codebase to pre-populate, pulls patterns from installed capabilities.

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

## Versioning

- **v0.1.0** — Initial release with 9 capabilities, 4 profiles, 7 skills
- Capabilities have independent semver in frontmatter
- Consumer projects pin versions in `.metis/capabilities/manifest.json`
- Metis repo uses git tags for stable snapshots
