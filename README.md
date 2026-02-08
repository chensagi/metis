# Metis

Self-evolving swarm orchestration for Claude Code. Parallel task execution with capability profiles, budget tracking, and codebase-aware triage — across any project.

**Core principle:** Deliver at the lowest cost possible. Haiku for diagnostics, Sonnet for work, Opus only as orchestrator. The agent gets better with every repo it touches.

## Quick Start

### Add this marketplace

```
/plugin marketplace add <owner>/metis
```

### Install the plugin

```
/plugin install metis-core@metis
```

### Set up your project

```
/install
```

This detects your project type, suggests a capability profile, and bootstraps `.metis/` with everything configured.

### Start working

```
/triage          # Audit your backlog
/task            # Pick up and complete a task
/swarm           # Parallel task execution
/ship branch-name  # PR + merge
/learn           # Analyze project and suggest improvements
/add-metiskill   # Add a custom skill
```

## How It Works

### Capability Profiles

Metis ships with predefined profiles for common project types:

| Profile | Capabilities | Auto-detected by |
|---------|-------------|-----------------|
| `react-native-expo` | TypeScript, React Native, Expo, iOS Simulator, Maestro | `app.json` + `expo` in package.json |
| `typescript-node` | TypeScript | `tsconfig.json` (no Expo) |
| `python-fastapi` | Python | `pyproject.toml` / `setup.py` |
| `go-service` | Go | `go.mod` |

Each capability is a markdown file with agent instructions that get injected into spawned agents. Install `zustand` capability → all future agents automatically know Zustand patterns.

### Self-Learning

After each `/swarm` or `/task` completion, Metis can analyze what happened and suggest improvements:
- Missing capabilities (you use a library but haven't installed its capability)
- Config tuning (test command could be better)
- Custom skill opportunities (repetitive manual work that could be automated)

Run `/learn --deep` for a thorough analysis, or let it auto-suggest after tasks.

### The `.metis/` Directory

All state lives in `.metis/` inside your project. Hybrid git tracking:

```
.metis/
├── .gitignore              # Selective tracking
├── config.json             # Project settings (tracked)
├── capabilities/           # Installed capabilities (tracked)
│   ├── manifest.json
│   ├── typescript.md
│   └── react-native.md
├── skills/                 # Custom project skills (tracked)
│   └── sim-interact/
│       └── SKILL.md
├── agents.json             # Swarm state (local only)
├── learnings.json          # Learning history (local only)
└── tasks/                  # Task board (local only)
    ├── todo/
    ├── doing/
    └── done/
```

## Skills

### Consumer Project Skills (run in your project)

| Skill | Description |
|-------|-------------|
| `/install` | Set up or update `.metis/` — detect project type, choose capabilities |
| `/swarm` | Orchestrate parallel task execution with budget tracking |
| `/task` | Pick up and complete a single task end-to-end |
| `/triage` | Audit tasks against the codebase, detect stale/obsolete work |
| `/ship` | Create PR, wait for CI, merge to main |
| `/learn` | Analyze project and suggest capability improvements |
| `/add-metiskill` | Add a custom project-specific skill |

### Repo Management Skills (run in the metis repo)

| Skill | Description |
|-------|-------------|
| `/add-capability` | Add a new capability to the registry |
| `/pull-capability` | Import a community capability from URL or local path |
| `/release` | Bump version, update registry, create git tag |

### 2-Layer Leaf-Spine Architecture

All metis skills use a strict 2-layer architecture. Skills run in the chat context (Opus — the spine), spawning Task agents (Sonnet/Haiku — the leaves). Claude Code does not support nested agent spawning, so this IS the maximum depth — and it's all you need.

| Layer | Model | Role |
|-------|-------|------|
| **Spine** (Layer 1) | Opus | Orchestration, decomposition, judgment, synthesis, commits |
| **Leaf** (Layer 2) | Sonnet | Implementation — code writing, fix agents (max 30 turns) |
| **Leaf** (Layer 2) | Haiku | Exploration — diagnostics, data gathering, test checks (max 10-15 turns) |

**Key principle:** Haiku gathers raw data. Opus reasons about it. Sonnet implements solutions. Opus verifies and commits. The spine never delegates judgment to leaves.

## Versioning

Three levels:
- **Metis repo**: Git tags (`v0.1.0`) — stable snapshots of all capabilities and skills
- **Capabilities**: Semver in frontmatter — individual component versions
- **Consumer manifest**: Pinned versions in `.metis/capabilities/manifest.json`

## Structure

```
metis/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   └── metis-core/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── capabilities/         # Capability registry
│       │   ├── registry.json
│       │   ├── typescript/
│       │   ├── react-native/
│       │   ├── expo/
│       │   ├── ios-simulator/
│       │   ├── maestro/
│       │   ├── zustand/
│       │   ├── python/
│       │   ├── go/
│       │   └── rust/
│       ├── profiles/             # Predefined profiles
│       │   ├── react-native-expo.json
│       │   ├── typescript-node.json
│       │   ├── python-fastapi.json
│       │   └── go-service.json
│       ├── skills/               # All skills
│       │   ├── install/          # Project setup
│       │   ├── swarm/            # Parallel orchestration
│       │   ├── task/             # Single-task workflow
│       │   ├── triage/           # Backlog auditor
│       │   ├── ship/             # PR + merge
│       │   ├── learn/            # Analyze & suggest
│       │   ├── add-metiskill/    # Custom skill creator
│       │   ├── add-capability/   # Registry management
│       │   ├── pull-capability/  # Community import
│       │   └── release/          # Version + tag
│       ├── hooks/
│       │   └── hooks.json
│       └── README.md
└── README.md
```
