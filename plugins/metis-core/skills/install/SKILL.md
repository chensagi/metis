---
name: install
description: Set up or update .metis/ in the current project — detect project type, choose capabilities, configure commands. Idempotent — safe to run multiple times.
argument-hint: [--update] (optional - run in update mode to check for new capabilities)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Metis Install — Project Setup

You are executing the `/install` command. This skill bootstraps or updates `.metis/` in the current project. It's idempotent — running it again detects existing setup and offers upgrades.

## Detect Mode

Check if `.metis/` already exists:
- **No `.metis/`** → Fresh install (full flow)
- **`.metis/` exists** → Update mode (check for upgrades, new capabilities)

---

## Fresh Install Flow

### Step 1: Detect Project Type

Scan the project root for signature files to determine the best profile:

| Files Found | Suggested Profile |
|---|---|
| `app.json` + `expo` in package.json | `react-native-expo` |
| `tsconfig.json` + `package.json` (no expo) | `typescript-node` |
| `pyproject.toml` or `setup.py` or `requirements.txt` | `python-fastapi` |
| `go.mod` | `go-service` |
| `Cargo.toml` | (no profile yet — use rust capability directly) |
| None of the above | No profile — ask user to configure manually |

Read the profile JSON from the metis-core `profiles/` directory to get default capabilities and settings.

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
  ✓ skia            — React Native Skia canvas                  (optional)

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

For each selected capability, copy its `capability.md` from the metis-core registry into `.metis/capabilities/`:

```
.metis/capabilities/
├── manifest.json
├── typescript.md
├── react-native.md
├── expo.md
├── ios-simulator.md
└── maestro.md
```

Read each capability file from the metis-core `capabilities/{name}/capability.md` directory and write it to `.metis/capabilities/{name}.md`.

### Step 9: Initialize State Files

```bash
echo '{ "agents": [], "completed": [], "needs_review": [] }' > .metis/agents.json
echo '{ "entries": [], "suggestions_applied": [] }' > .metis/learnings.json
```

### Step 10: Report Success

```
METIS INSTALLED
═══════════════════════════════════════════════════

Profile: react-native-expo (v0.1.0)
Capabilities: typescript, react-native, expo, ios-simulator, maestro
Config: .metis/config.json

Next steps:
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

Compare installed capability versions against the metis-core registry:

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
