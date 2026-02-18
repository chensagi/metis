---
name: install
description: Set up or update .metis/ in the current project — detect project type, choose capabilities, configure commands. Idempotent — safe to run multiple times.
argument-hint: [--update] (optional - run in update mode to check for new capabilities)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Metis Install — Project Setup

You are executing the `/install` command. This skill bootstraps or updates `.metis/` in the current project. It's idempotent — running it again detects existing setup and offers upgrades.

## Locating Plugin Files

The metis-core plugin files (profiles, capabilities, registry) are located relative to this skill's base directory. The base directory is provided in the system prompt as "Base directory for this skill: ..." — use it to compute paths:

- **Plugin root:** `{base_directory}/../../` (two levels up from `skills/install/`)
- **Profiles:** `{plugin_root}/profiles/{name}.json`
- **Capabilities:** `{plugin_root}/capabilities/{name}/capability.md`
- **Registry:** `{plugin_root}/capabilities/registry.json`

<rules>
ALWAYS use these resolved paths to read plugin files directly. NEVER search the filesystem, spawn Explore agents, or glob broadly for plugin files. You know exactly where they are.
</rules>

## Detect Mode

Check if `.metis/` already exists:
- **No `.metis/`** → Fresh install (full flow)
- **`.metis/` exists** → Update mode (check for upgrades, new capabilities)

---

## Fresh Install Flow

### Step 1: Detect Project Type

#### Pre-check: Existing Orchestrator Detection

Before detecting project type, scan for known AI orchestrator configs:

| Files Found | Orchestrator |
|---|---|
| `.cursorrules` or `.cursor/rules` | Cursor |
| `.github/copilot-instructions.md` | GitHub Copilot |
| `.windsurfrules` or `.windsurf/rules` | Windsurf |
| `.aider.conf.yml` or `.aider/` | Aider |
| `.continue/` or `.continuerc.json` | Continue |
| `.roo/` or `.roomodes` | Roo Code |
| `.cline/` or `.clinerules` | Cline |

If any are found, show:

```
We noticed {orchestrator} configuration in this project.
Consider running /migrate first to import your existing
setup (rules, commands, conventions) into Metis.

Continue with fresh install anyway?
```

Use AskUserQuestion:
- "Run /migrate first" → tell user to run `/migrate`, then exit
- "Continue with fresh install" → proceed with normal install flow

#### Profile Detection

Scan the project root for signature files to determine the best profile:

| Files Found | Suggested Profile |
|---|---|
| `app.json` + `expo` in package.json | `react-native-expo` |
| `tsconfig.json` + `package.json` (no expo) | `typescript-node` |
| `pyproject.toml` or `setup.py` or `requirements.txt` | `python-fastapi` |
| `go.mod` | `go-service` |
| `Cargo.toml` | (no profile yet — use rust capability directly) |
| `plugins/metis-core/capabilities/registry.json` | `metis-dev` |
| None of the above | No profile — ask user to configure manually |

Read the profile JSON from `{plugin_root}/profiles/{profile_name}.json` to get default capabilities and settings.

### Step 2: Confirm Profile with User

Present the detected profile and ask for confirmation:

```
METIS INSTALL
═══════════════════════════════════════════════════

Detected: React Native + Expo project
Suggested profile: react-native-expo (v0.1.0)

Capabilities that will be installed:
  ✓ typescript      — Type checking and compilation
  ✓ react-native    — Native UI patterns and conventions
  ✓ expo            — Expo CLI, Metro, OTA updates
  ✓ ios-simulator   — Screenshots and simctl commands
  ✓ maestro         — E2E test automation
  ✓ zustand         — State management with MMKV persistence    (optional)

  All capabilities are ON by default. Toggle OFF what you don't need.

═══════════════════════════════════════════════════
```

Use `AskUserQuestion` to let the user:
- Confirm the profile
- Toggle OFF any optional capabilities they don't want (all are ON by default)
- Choose a different profile

### Step 3: Ask Project-Specific Questions

Based on the profile's `questions` array and the selected capabilities, ask relevant setup questions using `AskUserQuestion`:

**Always ask:**
- Project name (default: directory name)
- Source directories (default from profile)
- Custom verify/test/lint commands (show defaults, let user override)

**Capability-specific questions:**
- `ios-simulator` → App bundle ID
- `maestro` → Path to testID documentation (if exists)
- `zustand` → Store directory location

Group related questions together (max 4 per AskUserQuestion call).

### Step 4: Create `.metis/` Directory

```bash
mkdir -p .metis/capabilities .metis/skills .metis/tasks/todo .metis/tasks/doing .metis/tasks/done
```

### Step 5: Create `.metis/.gitignore` (Hybrid Tracking)

```gitignore
# Metis state (local only — not tracked in git)
agents.json
learnings.json
tasks/

# Everything else is tracked:
# - capabilities/ (team-shared agent knowledge)
# - skills/ (custom project skills)
# - config.json (project settings)
# - .gitignore (this file)
```

### Step 6: Create `.metis/config.json`

```json
{
  "metis_version": "0.1.0",
  "project_name": "{detected_or_user_provided}",
  "profile": "{profile_name}",
  "profile_version": "{profile_version}",
  "verify_command": "{from_profile_or_user}",
  "test_command": "{from_profile_or_user}",
  "lint_command": "{from_profile_or_user}",
  "src_dirs": ["{from_profile_or_user}"],
  "ask_mode": "normal",
  "max_agents": 4,
  "default_budget": null,
  "learning": {
    "auto_suggest": true,
    "last_learned": null
  },
  "custom_capabilities": []
}
```

### Step 7: Create `.metis/capabilities/manifest.json`

```json
{
  "metis_version": "0.1.0",
  "profile": "{profile_name}",
  "installed_at": "{ISO_timestamp}",
  "capabilities": {
    "typescript": { "version": "0.1.0", "installed_at": "{ISO_timestamp}" },
    "react-native": { "version": "0.1.0", "installed_at": "{ISO_timestamp}" }
  }
}
```

### Step 8: Copy Capability Files

For each selected capability, read its file from `{plugin_root}/capabilities/{name}/capability.md` and write it to `.metis/capabilities/{name}.md`:

```
.metis/capabilities/
├── manifest.json
├── typescript.md
├── react-native.md
├── expo.md
├── ios-simulator.md
└── maestro.md
```

Each capability source is at `{plugin_root}/capabilities/{name}/capability.md`.

### Step 9: Initialize State Files

```bash
echo '{ "agents": [], "completed": [], "needs_review": [] }' > .metis/agents.json
echo '{ "entries": [], "suggestions_applied": [] }' > .metis/learnings.json
```

### Step 9.5: Generate Makefile

If no `Makefile` exists in the project root, offer to generate one with profile-appropriate targets. **Never overwrite an existing Makefile.**

1. Check for `Makefile` in project root
2. If it exists → skip this step entirely (tell the user "Makefile already exists — skipping generation")
3. If not → read `makefile_targets` from the profile JSON and generate a Makefile

The profile's `makefile_targets` field defines which targets to include. Each target has a command, description, and optional dependencies.

**Makefile conventions (learned from production projects):**

```makefile
.PHONY: help
help: ## Show available commands
	@echo ""
	@echo "  Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

.DEFAULT_GOAL := help
```

- Every target has a `## description` comment for the self-documenting `make help`
- Use ANSI colors for readability
- Include a `check` meta-target that runs all quality gates (typecheck + lint + test)
- Include `clean` and `nuke` targets where appropriate

Present the generated Makefile to the user for approval before writing:

```
MAKEFILE
═══════════════════════════════════════════════════

Generated {N} targets for {profile_name}:

  make dev          — Start development server
  make check        — Run all quality gates
  make test         — Run test suite
  ...

Write Makefile to project root?
═══════════════════════════════════════════════════
```

Use AskUserQuestion:
- "Write it" → Write the Makefile
- "Skip" → Don't create a Makefile

### Step 10: Configure OpenTelemetry

Read the project's `.claude/settings.json` (create the file if it doesn't exist, create the `.claude/` directory if needed). Merge in the OTEL env vars — preserve any existing keys, only add/update the `env` keys below:

```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "prometheus",
    "OTEL_METRIC_EXPORT_INTERVAL": "10000"
  }
}
```

This makes Claude Code serve metrics at `http://localhost:8888/metrics`. The user needs to restart Claude Code once for the env vars to take effect.

Tell the user:

```
OTEL cost tracking enabled — restart Claude Code to activate.
After restart, Metis will show real costs in /swarm status.
```

### Step 10.5: CLAUDE.md Guidance

Check if `CLAUDE.md` exists in the project root. This file is the single most impactful context for agent success — rich CLAUDE.md files dramatically improve agent output quality.

**If CLAUDE.md does not exist:**

Offer to create a starter template with profile-appropriate sections:

```
CLAUDE.md
═══════════════════════════════════════════════════

No CLAUDE.md found. This file is your project's instruction
manual for AI agents — it dramatically improves agent quality.

Recommended sections for {profile_name}:

  Core (all profiles):
    ✓ Project overview & mission
    ✓ Architecture overview
    ✓ Development workflow (build, test, deploy)
    ✓ Conventions (naming, file structure, patterns)
    ✓ Don't (common mistakes to avoid)

  Profile-specific ({profile_name}):
    {profile_specific_sections}

Create a starter CLAUDE.md?
═══════════════════════════════════════════════════
```

**Profile-specific sections:**

| Profile | Additional Sections |
|---------|-------------------|
| `react-native-expo` | View Hierarchy, Native Rebuild Rules, OTA Update Flow, Maestro Patterns, Data Formats |
| `typescript-node` | API Contract, Module Structure, Error Handling Conventions |
| `python-fastapi` | API Contract, Database Schema, Middleware Chain, Pydantic Models |
| `go-service` | Package Layout, Error Handling Conventions, Interface Patterns |

If the user approves, generate a skeleton `CLAUDE.md` with section headers and brief placeholder text explaining what to put in each section. Do NOT fill in content — the user knows their project best.

**If CLAUDE.md already exists:**

Scan for missing recommended sections and suggest additions:

1. Read the file
2. Check for each recommended section (case-insensitive heading match)
3. If any are missing, suggest them:

```
Your CLAUDE.md is missing these recommended sections:
  - "Don't" — common mistakes agents should avoid
  - "Data Formats" — TypeScript interfaces for key data structures

Add them? (will append section headers only)
```

Use AskUserQuestion:
- "Add missing sections" → Append section headers to CLAUDE.md
- "Skip" → Continue without changes

### Step 11: Report Success

```
METIS INSTALLED
═══════════════════════════════════════════════════

Profile: react-native-expo (v0.1.0)
Capabilities: typescript, react-native, expo, ios-simulator, maestro
Config: .metis/config.json

Next steps:
  /clear           — Start a fresh conversation (recommended before your first task)
  /triage          — Audit your backlog
  /task            — Pick up a task
  /swarm           — Run parallel task execution
  /learn           — Analyze project and suggest improvements
  /add-metiskill   — Add a custom skill

═══════════════════════════════════════════════════
```

---

## Update Mode

When `.metis/` already exists:

### Step 1: Read Current State

Read `.metis/config.json` and `.metis/capabilities/manifest.json` to understand what's installed.

### Step 2: Check for Updates

Compare installed capability versions against the registry at `{plugin_root}/capabilities/registry.json`:

```
METIS UPDATE CHECK
═══════════════════════════════════════════════════

Current: metis v0.1.0 | Profile: react-native-expo

Capability Updates Available:
  typescript      0.1.0 → 0.2.0  (updated type conventions)
  expo            0.1.0 → 0.1.1  (added Expo SDK 52 notes)

New Capabilities Available:
  reanimated      0.1.0  (React Native Reanimated animations)

No capability removals.

═══════════════════════════════════════════════════
```

### Step 3: Apply Updates

Use `AskUserQuestion` to let the user approve updates:
- Show a diff summary for each updated capability
- Let user select which updates to apply
- Apply selected updates by overwriting capability files
- Update manifest.json with new versions

### Step 4: Check Config

If the profile defaults have changed, suggest config updates:
- New commands available
- Updated src_dirs recommendations
- New profile questions

---

## Key Rules

<rules>
- NEVER delete existing `.metis/tasks/` content during updates
- NEVER overwrite `.metis/config.json` without asking — it has user customizations
- Capability files CAN be overwritten during updates (they come from the registry)
- Custom skills in `.metis/skills/` are NEVER modified by install
- The install skill is read-only for the metis-core repo — it only writes to `.metis/` in the consumer project
- Always resolve capability dependencies: if user selects `maestro`, auto-include `ios-simulator` and `react-native`
</rules>
