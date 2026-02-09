---
name: metis-dev
version: 0.1.0
description: Conventions for developing the Metis plugin — skill format, capability format, architecture patterns
requires: []
provides:
  - metis-skill-authoring
  - metis-capability-authoring
  - metis-architecture
commands: {}
---

# Metis Dev Capability

## Agent Instructions

### Skill Format

Every skill lives at `plugins/metis-core/skills/{name}/SKILL.md` and must have:

- **YAML frontmatter** with: `name` (matches directory), `description`, `argument-hint`, `allowed-tools`
- **Title line** as `# Skill Title`
- **Intro line**: `You are executing the /{name} command.`
- **`<rules>` block** with hard constraints for the skill
- **Dispatcher skills** must include `disable-model-invocation: true` in frontmatter and a `## Architecture: 3-Layer Dispatcher` section explaining L0/L1/L2 roles
- **Consumer skills** (run in user projects) need a `## Bootstrap` section that checks for `.metis/` and loads capabilities
- **`<agent-prompt>` blocks** for agent spawning templates — use `Task()` format with `model`, `subagent_type`, `run_in_background` parameters
- Step numbering matters — cross-references must stay consistent when inserting/removing steps

### Capability Format

Every capability lives at `plugins/metis-core/capabilities/{name}/capability.md`:

- **YAML frontmatter** with: `name` (matches directory), `version` (semver), `description`, `requires` (array), `provides` (array of tags), `commands` (object)
- **`## Agent Instructions`** section is mandatory — this is what agents actually read when the capability is injected
- Keep instructions concise and actionable — every token costs money
- Version independently with semver starting at `0.1.0`
- Register in `plugins/metis-core/capabilities/registry.json` with matching metadata

### Architecture Rules

- Always reference the **3-layer architecture**: L0 (Platform), L1 (Spine/Opus), L2 (Leaves/Sonnet/Haiku)
- Never use "2-layer" — the architecture is always 3-layer
- `Task()` agent spawning format must include `model`, `subagent_type`, and `run_in_background`
- Max 4 background agents at any time
- Opus never delegates judgment — it THINKS and DECIDES, agents DO
- No nested spawning — L0 handles all agent spawning

### Repo Structure

```
plugins/metis-core/
├── capabilities/         # registry.json + {name}/capability.md
├── profiles/             # {name}.json — capability bundles
├── skills/               # {name}/SKILL.md — slash commands
└── hooks/hooks.json      # Lifecycle hooks
```

### Git Conventions

- Stage specific files — never `git add -A`
- Commit messages: imperative mood, concise
