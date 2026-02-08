---
name: scaffold-skill
description: Create a new core skill in metis-core with proper frontmatter, architecture patterns, and agent prompt templates
argument-hint: [skill-name] ["description"]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Scaffold Skill — Core Skill Generator

You are executing the `/scaffold-skill` command. This skill creates a properly structured SKILL.md in `plugins/metis-core/skills/`. Run this **in the metis repo** (not in consumer projects).

## Step 1: Gather Details

**If arguments provided:**
- First word = skill name (lowercase, hyphens only)
- Remaining text = description

**If no arguments or incomplete:**
Use `AskUserQuestion` to gather:

1. **Skill name** (slug format, lowercase with hyphens)
2. **Description** (one line — what the skill does)
3. **Skill type** — determines the template structure:
   - **Consumer direct** (like `/task`, `/install`): Opus runs in session, interactive workflow with the user. Has a Bootstrap section that loads `.metis/` capabilities.
   - **Consumer dispatcher** (like `/swarm`, `/triage`): L0 dispatches mechanically, spawns Opus for thinking and Sonnet/Haiku for execution. Has `disable-model-invocation: true` and 3-layer architecture section.
   - **Repo management** (like `/add-capability`, `/validate`): Operates on `plugins/metis-core/` directly. No Bootstrap section, no capability loading.
4. **Additional options** (multi-select):
   - Needs web research? (adds `WebSearch`, `WebFetch` to allowed-tools)
   - Needs agent spawning? (adds `Task`, `TaskOutput` to allowed-tools)

## Step 2: Check for Conflicts

1. Verify `plugins/metis-core/skills/{name}/` doesn't already exist → abort if it does
2. Check that the name doesn't conflict with built-in Claude Code commands

## Step 3: Read Reference Skills

Based on the skill type, read 1-2 existing skills of the same type to match patterns:

- **Consumer direct** → read `/task` and/or `/install`
- **Consumer dispatcher** → read `/swarm` and/or `/triage`
- **Repo management** → read `/add-capability` and/or `/validate`

Identify the structural patterns: frontmatter fields, section ordering, rule patterns, agent prompt format.

## Step 4: Generate SKILL.md

Create `plugins/metis-core/skills/{name}/SKILL.md` with the following structure:

### For ALL skill types:

```markdown
---
name: {name}
description: {description}
argument-hint: {appropriate hint}
allowed-tools: {based on type + options}
---

# {Title} — {Subtitle}

You are executing the `/{name}` command. {Brief intro of what this skill does.}

## Step 1: {First step}

TODO: Define the first step of the workflow.

## Step 2: {Second step}

TODO: Define the second step.

{... additional steps as needed}

<rules>
- TODO: Add hard constraints for this skill
</rules>
```

### Additional sections by type:

**Consumer direct** — add before Step 1:

```markdown
## Bootstrap

Before starting, ensure `.metis/` exists with a valid config:

1. **If `.metis/config.json` exists** → Read it, load capabilities from `.metis/capabilities/`, proceed
2. **If `.metis/` doesn't exist** → Tell the user to run `/install` first for full interactive setup. If they want to proceed immediately, do a minimal bootstrap:
   - `mkdir -p .metis/capabilities .metis/skills .metis/tasks/todo .metis/tasks/doing .metis/tasks/done`
   - Create `.metis/.gitignore` (hybrid tracking)
   - Auto-detect project type and create minimal `.metis/config.json`

Read `.metis/capabilities/manifest.json` (if exists) and load capability instructions — these inform implementation.
```

**Consumer dispatcher** — add `disable-model-invocation: true` to frontmatter, and add after the intro:

```markdown
## Architecture: 3-Layer Dispatcher

The {name} runs as a dispatcher on L0 (your Claude Code session — any model).
It spawns Opus for thinking and Sonnet/Haiku for execution. The nesting constraint
(subagents can't spawn subagents) means L0 handles ALL spawning.

```
L0 (this skill, any model) — mechanical routing
  ↓ spawns (foreground, blocking)
L1 Opus — judgment, planning, evaluation
  ↓ returns structured decisions to L0
L0 reads decisions
  ↓ spawns (background)
L2 Sonnet/Haiku — implementation, execution
  ↓ returns results via TaskOutput
L0 processes results
Loop
```

**Key principle:** Opus THINKS. Agents DO. Opus DECIDES.
```

Also include an `<agent-prompt>` block template:

```markdown
<agent-prompt>
Task({
  description: "{name} — {work item description}",
  prompt: `You are a {role} agent.

## Project Context
Read the project's CLAUDE.md (if it exists) for codebase conventions.

## Project Capabilities (subset)
${relevantCapabilityInstructions}

## Research Hints
${researchHints}

## Rules
- Stay focused on YOUR scope
- Follow existing code patterns

## Your Work Item
${workItemDetails}`,
  subagent_type: "general-purpose",
  model: "sonnet",
  run_in_background: true,
  max_turns: 30
})
</agent-prompt>
```

**Repo management** — no Bootstrap, no architecture section. Add to rules:

```markdown
- This skill runs in the METIS REPO only (not in consumer projects)
```

### Allowed-tools by type:

| Type | Base Tools | With Web Research | With Agent Spawning |
|------|-----------|-------------------|---------------------|
| Consumer direct | `Bash, Read, Write, Edit, Glob, Grep` | + `WebSearch, WebFetch` | + `Task, TaskOutput` |
| Consumer dispatcher | `Bash, Read, Write, Edit, Glob, Grep` | + `WebSearch, WebFetch` | + `Task, TaskOutput` (always) |
| Repo management | `Bash, Read, Write, Edit, Glob, Grep` | + `WebSearch, WebFetch` | + `Task, TaskOutput` |

Consumer dispatcher skills always get `Task, TaskOutput` since they spawn agents by definition.

## Step 5: Confirm with User

Show the generated SKILL.md content and ask for approval before writing:

```
SCAFFOLD PREVIEW
═══════════════════════════════════════════════════

Skill: {name}
Type: {type}
File: plugins/metis-core/skills/{name}/SKILL.md
Allowed tools: {tools}

{Show the full generated content}

═══════════════════════════════════════════════════
```

Use `AskUserQuestion` to confirm:
- Write as shown
- Modify (ask what to change)
- Cancel

## Step 6: Write and Report

After user approval, create the directory and write the file.

```
SKILL SCAFFOLDED
═══════════════════════════════════════════════════

Created: plugins/metis-core/skills/{name}/SKILL.md
Type: {type}

Next steps:
  1. Edit the SKILL.md to fill in TODO placeholders
  2. Run /validate {name} to check convention compliance
  3. Update README.md and plugins/metis-core/README.md
  4. Run /release to tag a new version

═══════════════════════════════════════════════════
```

<rules>
- This skill runs in the METIS REPO only (not in consumer projects)
- Skill names MUST be lowercase with hyphens (e.g., `my-skill`, not `mySkill`)
- Never overwrite an existing skill — abort if the directory already exists
- Dispatcher skills MUST have `disable-model-invocation: true` in frontmatter
- Agent prompts MUST use `Task()` format with `model`, `subagent_type`, `run_in_background`
- Never reference "2-layer" — the architecture is always 3-layer
- The generated SKILL.md must pass `/validate` checks (correct frontmatter, rules block, structure)
</rules>
