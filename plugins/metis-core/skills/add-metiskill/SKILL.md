---
name: add-metiskill
description: Add a custom project-specific skill to .metis/skills/. Creates a SKILL.md file that integrates with the metis orchestration system.
argument-hint: [skill-name] ["description"] (optional - will ask interactively if not provided)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Add Metis Skill — Custom Skill Creator

You are executing the `/add-metiskill` command. This skill scaffolds a new custom skill in `.metis/skills/` that becomes available as a slash command in this project.

## Prerequisites

`.metis/` must exist. If not, tell the user to run `/install` first.

## Flow

### Step 1: Gather Skill Details

**If arguments provided** (`$ARGUMENTS`):
- First word = skill name (e.g., `sim-interact`)
- Rest = description

**If no arguments**:
Use `AskUserQuestion` to ask:
1. Skill name (slug format: lowercase, hyphens, no spaces)
2. What should this skill do? (free text description)
3. Should agents know about this skill? (inject into agent prompts)

### Step 2: Analyze the Request

Based on the description, scan the codebase to understand what the skill needs:

1. Grep for related patterns, files, and tools
2. Check if any installed capability is related (read `.metis/capabilities/manifest.json`)
3. If the skill overlaps with a capability, suggest extending the capability instead

### Step 3: Scaffold the Skill

Create `.metis/skills/{skill-name}/SKILL.md` with proper frontmatter:

```markdown
---
name: {skill-name}
description: {user-provided description}
argument-hint: {detected or asked}
allowed-tools: {appropriate tools for this skill}
---

# {Skill Title}

You are executing the `/{skill-name}` command.

## What This Skill Does

{Expanded description based on codebase analysis}

## Workflow

### Step 1: {First step}
{Instructions}

### Step 2: {Second step}
{Instructions}

## Project Context

{Relevant codebase details discovered during analysis}

## Key Rules

<rules>
- {Constraints and guidelines}
</rules>
```

### Step 4: Pre-Populate from Capabilities

If the skill is related to an installed capability, pull relevant patterns:

- Skill about simulator interaction → pull patterns from `ios-simulator` capability
- Skill about test creation → pull patterns from `maestro` capability
- Skill about state management → pull patterns from `zustand` capability

### Step 5: Confirm with User

Show the generated skill file and ask for approval:

```
SKILL CREATED
═══════════════════════════════════════════════════

File: .metis/skills/{skill-name}/SKILL.md
Name: /{skill-name}
Description: {description}

Preview:
{first 20 lines of the SKILL.md}

═══════════════════════════════════════════════════
```

Use `AskUserQuestion`:
- Approve as-is
- Edit (open for manual editing)
- Regenerate with different approach

### Step 6: Register and Report

The skill is immediately available as `/{skill-name}` in this project (Claude Code discovers skills from `.metis/skills/` automatically when the plugin is installed).

Record the creation in `.metis/learnings.json`:
```json
{
  "type": "skill_added",
  "detail": "Created /{skill-name}: {description}",
  "date": "{ISO_date}",
  "applied": true,
  "source": "add-metiskill"
}
```

---

## Skill Templates

For common skill types, use these templates as starting points:

### Verification Skill

For skills that verify/check something:
```yaml
allowed-tools: Bash, Read, Glob, Grep
```
- Read-only pattern (never modify source)
- Run checks, produce a report
- Use Haiku agents for parallel checks if needed

### Interaction Skill

For skills that interact with external tools (simulators, databases, etc.):
```yaml
allowed-tools: Bash, Read, Write, Glob, Grep
```
- Before/after verification pattern
- Screenshot or output capture for confirmation
- Error handling for tool availability

### Generator Skill

For skills that create files from templates:
```yaml
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
```
- Scan codebase for conventions first
- Generate files following existing patterns
- Run verify_command after generation

---

## How Custom Skills Integrate with Swarm

When the swarm orchestrator spawns agents, it can inject custom skill knowledge:

1. Read `.metis/skills/` to discover custom skills
2. For each skill, check if its description is relevant to the current task
3. If relevant, append a brief note to the agent prompt:
   ```
   ## Custom Project Skills
   This project has a /{skill-name} skill: {description}
   Relevant patterns: {key instructions from the skill}
   ```

This way, agents benefit from custom skills even when working independently.

---

## Key Rules

<rules>
- Skill names must be lowercase with hyphens (e.g., `create-test`, `sim-interact`)
- Always scan the codebase before generating — the skill should reference real files and patterns
- Don't duplicate existing metis skills (swarm, task, triage, ship, install, learn)
- Don't duplicate installed capabilities — extend them instead
- The generated SKILL.md should be self-contained (an agent reading it should know exactly what to do)
- Custom skills are git-tracked (they're in `.metis/skills/`, not gitignored)
</rules>
