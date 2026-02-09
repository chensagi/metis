# Metis

Self-evolving swarm orchestration for Claude Code — making professional coding accessible to everyone.

Parallel task execution with capability profiles, budget tracking, and codebase-aware triage. The agent gets smarter with every repo it touches.

## Vision

**Everyone should be able to vibecode and code professionally.** Metis makes this possible by orchestrating AI agents that understand your codebase, ask the right questions, plan before they build, and learn from every task.

**Every token is currency.** Metis is designed from the ground up to minimize cost:

- Use the cheapest model that can do the job
- Inject only relevant capabilities into agent prompts (capability subsetting)
- Ask questions first, explore cheaply, plan the approach, then execute
- Track and reduce context exhaustion across sessions

**Self-learning.** After every task, Metis analyzes what happened and suggests improvements — missing capabilities, config tuning, custom skill opportunities. The system gets better over time.

## Quick Start

### Add this marketplace

```
/plugin marketplace add chensagi/metis
```

### Install the plugin

```
/plugin install metis@metis
```

### Set up your project

```
/install
```

This detects your project type, suggests a capability profile, and bootstraps `.metis/` with everything configured.

### Start working

```
/help            # See what's available and what to do next
/triage          # Audit your backlog
/task            # Pick up and complete a task
/task --super-ask  # Thorough multi-round questioning before implementation
/swarm           # Parallel task execution (run in a dedicated session)
/ship branch-name  # PR + merge
/learn           # Analyze project and suggest improvements
/migrate         # Import setup from Cursor, Copilot, Windsurf, etc.
/add-metiskill   # Add a custom skill
```

## How It Works

### Ask → Explore → Research → Plan → Execute

Metis follows a cost-conscious workflow for every task:

1. **Ask** — Clarify requirements before spending tokens. Ask the user questions to understand intent
2. **Explore** — Search the codebase cheaply (grep, glob, file reads) to understand what exists
3. **Research** — Search the web for relevant docs, best practices, and known issues
4. **Plan** — Design the implementation approach and present it for user approval
5. **Execute** — Only then spawn implementation agents with focused, minimal prompts

This prevents wasted tokens on wrong approaches and ensures alignment with user intent.

### Capability Profiles

Metis ships with predefined profiles for common project types:

| Profile | Capabilities | Auto-detected by |
|---------|-------------|-----------------|
| `react-native-expo` | TypeScript, React Native, Expo, iOS Simulator, Maestro | `app.json` + `expo` in package.json |
| `typescript-node` | TypeScript | `tsconfig.json` (no Expo) |
| `python-fastapi` | Python | `pyproject.toml` / `setup.py` |
| `go-service` | Go | `go.mod` |
| `metis-dev` | Metis Dev | `plugins/metis-core/capabilities/registry.json` |

Each capability is a markdown file with agent instructions that get injected into spawned agents. Install the `zustand` capability → all future agents automatically know Zustand patterns.

### Capability Subsetting

Not every agent needs every capability. When spawning work agents, Metis injects **only the capabilities relevant to that specific work item**:

- A backend API task skips react-native, ios-simulator, maestro instructions
- A type definitions task gets only the typescript capability
- A UI component task skips backend-specific capabilities

This reduces prompt size by 60-80% for focused tasks, saving tokens and keeping agents sharp.

## Skills

### Consumer Project Skills (run in your project)

| Skill | Description | Cost Tier |
|-------|-------------|-----------|
| `/help` | Show available skills, project status, and contextual guidance | Free (read-only) |
| `/install` | Set up or update `.metis/` — detect project type, choose capabilities | Opus only |
| `/migrate` | Migrate from another AI orchestrator (Cursor, Copilot, Windsurf, Aider, etc.) to Metis | Opus only |
| `/swarm` | Orchestrate parallel task execution with budget tracking | Opus + Sonnet/Haiku |
| `/task` | Pick up, plan, and complete a single task end-to-end. Use `--super-ask` for thorough multi-round questioning | Opus + Sonnet/Haiku |
| `/triage` | Audit tasks against the codebase, detect stale/obsolete work | Opus + Haiku |
| `/ship` | Create PR, wait for CI, merge to main | Opus only |
| `/learn` | Analyze project and suggest capability improvements | Opus + Haiku |
| `/create-tasks` | Interview-driven task generation — thorough questioning then backlog creation | Opus only |
| `/add-metiskill` | Add a custom project-specific skill | Opus only |

### Repo Management Skills (run in the metis repo)

| Skill | Description |
|-------|-------------|
| `/add-capability` | Add a new capability to the registry |
| `/scaffold-skill` | Create a new core skill with proper structure, frontmatter, and templates |
| `/validate` | Lint and validate SKILL.md and capability.md files for convention compliance |
| `/release` | Bump version, update registry, create git tag |

## Cost Efficiency

Metis is built to deliver results at the lowest cost possible.

### Model Hierarchy

| Model | Use Case | Max Turns | Estimated Cost |
|-------|----------|-----------|----------------|
| Haiku | Exploration, diagnostics, data gathering | 10-15 | ~$0.05/task |
| Sonnet | Implementation, code writing, fixes | 30 | ~$0.50/task |
| Opus | Orchestration, judgment, synthesis (spine only) | Per session | ~$0.30/iteration |

**Key principle:** Haiku gathers raw data. Opus reasons about it. Sonnet implements solutions. Opus verifies and commits.

### Context Budget

- **Capability subsetting** — inject only relevant capabilities per agent, not the full set
- **Focused prompts** — each agent gets only the context it needs for its specific work item
- **Incremental processing** — swarm processes agent results one at a time to prevent context overflow
- **Budget tracking** — `/swarm --budget N` stops spawning when estimated cost approaches the limit

## Self-Learning

After each `/swarm` or `/task` completion, Metis can analyze what happened and suggest improvements:
- Missing capabilities (you use a library but haven't installed its capability)
- Config tuning (test command could be better)
- Custom skill opportunities (repetitive manual work that could be automated)

Run `/learn --deep` for a thorough analysis, or let it auto-suggest after tasks.

## The `.metis/` Directory

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

## Architecture

### 3-Layer Architecture

| Layer | What | Role |
|-------|------|------|
| **L0 — Platform** | Claude Code (your session) | Dispatches work. Can run on any model |
| **L1 — Spine** | Opus (spawned when needed) | Thinking, judgment, planning, evaluation |
| **L2 — Leaves** | Sonnet / Haiku / Ollama | Implementation, exploration, web research |

**Opus thinks. Agents do. Opus decides.**

For complex skills like `/swarm`, your Claude Code session acts as a lightweight
dispatcher — spawning Opus for decisions and Sonnet/Haiku for execution. You don't
need to run on Opus directly; the system spawns it only when judgment is needed.

For interactive skills like `/task`, Opus runs directly for a fluid conversation.

### Swarm Isolation

The `/swarm` command is designed to run in a **dedicated session**:
- Start it in a separate conversation and let it loop continuously
- It processes tasks autonomously: decompose → spawn → wait → verify → commit → next
- Stop it with `/swarm stop` or by closing the session
- State persists in `.metis/agents.json` — safe to restart anytime

### Think Before Implementing

The orchestrator always explores and plans before spawning work agents:
- Reads the full task spec and understands requirements
- Explores the relevant codebase area (cheap grep/glob)
- Designs focused work items with clear boundaries
- Only then spawns agents with minimal, targeted prompts

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
│       │   ├── rust/
│       │   └── metis-dev/
│       ├── profiles/             # Predefined profiles
│       │   ├── react-native-expo.json
│       │   ├── typescript-node.json
│       │   ├── python-fastapi.json
│       │   ├── go-service.json
│       │   └── metis-dev.json
│       ├── skills/               # All skills
│       │   ├── help/             # Contextual help & guidance
│       │   ├── install/          # Project setup
│       │   ├── migrate/          # Orchestrator migration
│       │   ├── swarm/            # Parallel orchestration
│       │   ├── task/             # Single-task workflow
│       │   ├── triage/           # Backlog auditor
│       │   ├── ship/             # PR + merge
│       │   ├── learn/            # Analyze & suggest
│       │   ├── create-tasks/     # Interview-driven task generation
│       │   ├── add-metiskill/    # Custom skill creator
│       │   ├── add-capability/   # Registry management
│       │   ├── scaffold-skill/   # Core skill generator
│       │   ├── validate/         # Convention linter
│       │   └── release/          # Version + tag
│       ├── hooks/
│       │   └── hooks.json
│       └── README.md
├── CLAUDE.md
└── README.md
```

## Roadmap

- **Ollama Integration** — Local 7B/13B models for zero-cost mundane tasks (file analysis, boilerplate generation, documentation drafting). A preprocessing layer that handles the boring work before escalating to Claude
- **More Capabilities** — Community-contributed capabilities for popular frameworks and tools
- **Smarter Learning** — Cross-project learning patterns, capability recommendations based on similar projects
- **Cost Dashboard** — Real-time cost tracking and budget visualization

## Contributing

See [CLAUDE.md](CLAUDE.md) for development conventions, architecture principles, and testing guidance.

Community capabilities welcome — submit a PR adding a new `capabilities/{name}/capability.md` to the registry.
