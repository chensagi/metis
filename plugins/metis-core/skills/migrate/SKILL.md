---
name: migrate
description: Migrate from another AI orchestrator (Cursor, Copilot, Windsurf, Aider, etc.) to Metis — reads existing configs, interviews the user, and sets up .metis/
argument-hint: [source-tool] (optional - auto-detects if not specified)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Migrate to Metis

You are executing the `/migrate` command. This skill takes over from other AI orchestrators by reading their configs, deeply interviewing the user, and converting everything to Metis format.

## Step 1: Detect Source Orchestrators

Scan the project root for known orchestrator config files:

| Tool | Detection Files |
|------|----------------|
| Cursor | `.cursor/rules`, `.cursorrules`, `.cursor/` directory |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Windsurf | `.windsurf/rules`, `.windsurfrules` |
| Aider | `.aider.conf.yml`, `.aiderignore`, `.aider/` directory |
| Continue | `.continue/config.json`, `.continuerc.json` |
| Roo Code | `.roo/`, `.roomodes` |
| Cline | `.cline/`, `.clinerules` |
| Claude Code | `CLAUDE.md` (note: Metis works alongside CLAUDE.md, doesn't replace it) |
| Generic | `.ai/`, `AI.md`, `AGENTS.md` |

If `$ARGUMENTS` specifies a tool name, skip detection and focus on that tool.

Report what was found. If nothing found, tell the user this works best when existing orchestrator configs are present — but can still set up Metis via deep interview alone.

<rules>
**Pre-check:** If `.metis/` already exists, STOP. Tell the user: "Run `/install --update` instead — .metis/ already exists." Do NOT proceed with migration.
</rules>

## Step 2: Read & Analyze Source Configuration

For each detected source, read all its config files and extract:

- **Project rules/instructions** — coding conventions, architecture constraints, style guides
- **Technology stack signals** — frameworks, libraries, patterns mentioned
- **Commands** — build, test, lint, verify commands (if configured)
- **File patterns** — included/excluded directories, file types of interest
- **Custom behaviors** — tool-specific automations, workflows, rules

Present a summary to the user:

```
MIGRATION ANALYSIS
═══════════════════════════════════════════════════

Source: Cursor (.cursorrules + .cursor/rules)

Extracted:
  Rules:      14 project conventions found
  Stack:      React, TypeScript, Tailwind CSS
  Commands:   "npm test", "npm run lint"
  Patterns:   src/, components/, excluded: node_modules, dist
  Custom:     3 Cursor-specific behavioral rules

═══════════════════════════════════════════════════
```

## Step 3: Deep Project Interview

This is the core of the migration — a thorough 3-4 round interview that builds on the extracted source data. Use what you already learned from source configs to ask smarter, more targeted questions.

**Round 1 — Project Identity & Stack Confirmation**
- Confirm the technology stack detected from source (or ask if nothing detected)
- Project maturity: greenfield, active development, maintenance mode?
- Team size: solo, small team, large team? (affects how much Metis state to git-track)
- Primary development focus right now: features, bug fixes, refactoring, migration?

**Round 2 — Workflow & Pain Points**
- What works well with your current orchestrator? (so Metis can preserve those patterns)
- What frustrates you? (so Metis can specifically improve on these)
- How do you manage tasks? (GitHub Issues, Linear, local files, mental model?)
- What's your testing strategy? (tells us verify/test/lint commands)

**Round 3 — Conventions & Architecture**
- Show extracted rules from source → ask: "Are these still accurate? Anything to add or change?"
- Ask about architecture patterns specific to their stack (e.g., component structure for React, module layout for Go)
- Ask about naming conventions, file organization, import patterns
- Ask about deployment: how does code get to production?

**Round 4 — Metis-Specific Setup**
- Show the Metis profile that best matches → confirm or adjust capabilities
- Ask about budget sensitivity (relevant for swarm agent model selection)
- Ask about autonomy preference: do they want Metis to ask a lot (super-ask default) or be more autonomous?
- Any immediate tasks they want to migrate into the task board?

Use AskUserQuestion for each round with **well-reasoned options** — each option should have a detailed `description` field explaining implications. Reference extracted source data in your questions; don't re-ask things the source configs already answered (confirm instead).

## Step 4: Map to Metis Model

Based on interviews + source analysis:

1. **Select profile** — match detected stack to existing profiles (`react-native-expo`, `typescript-node`, `python-fastapi`, `go-service`, `metis-dev`)
2. **Map rules → capabilities** — for each extracted rule:
   - If it matches an existing capability's domain → note it (the capability already covers it)
   - If it's project-specific → collect for custom capability creation (Step 6)
3. **Map commands → config** — extract verify/test/lint commands from source or interview
4. **Map file patterns → src_dirs** — convert source includes/excludes to Metis `src_dirs`
5. **Determine ask_mode** — based on user's autonomy preference answer from Round 4

## Locating Plugin Files

The metis-core plugin files (profiles, capabilities, registry) are located relative to this skill's base directory. The base directory is provided in the system prompt as "Base directory for this skill: ..." — use it to compute paths:

- **Plugin root:** `{base_directory}/../../` (two levels up from `skills/migrate/`)
- **Profiles:** `{plugin_root}/profiles/{name}.json`
- **Capabilities:** `{plugin_root}/capabilities/{name}/capability.md`
- **Registry:** `{plugin_root}/capabilities/registry.json`

<rules>
ALWAYS use these resolved paths to read plugin files directly. NEVER search the filesystem or glob broadly for plugin files.
</rules>

## Step 5: Create `.metis/` Directory

- Create directory structure: `mkdir -p .metis/capabilities .metis/skills .metis/tasks/todo .metis/tasks/doing .metis/tasks/done`
- Create `.metis/.gitignore` (hybrid tracking)
- Create `config.json` with migrated settings (including `ask_mode`)
- Create `capabilities/manifest.json`
- Copy capability files: read from `{plugin_root}/capabilities/{name}/capability.md`, write to `.metis/capabilities/{name}.md`
- Initialize state files (`agents.json`, `learnings.json`)

**Key difference from `/install`:** The `config.json` is pre-populated with answers from the interview, not just profile defaults.

## Step 6: Create Custom Capability (if needed)

If source configs contained project-specific rules that don't map to any existing Metis capability, create a custom capability:

- File: `.metis/capabilities/{project-name}-conventions.md`
- Convert the source rules into Metis capability format (YAML frontmatter + `## Agent Instructions` section)
- Add to `manifest.json`
- Add to `config.json`'s `custom_capabilities` array

Show the generated capability to the user for approval before writing.

## Step 7: Import Task Backlog (if found)

If the interview revealed tasks or the source had a task format:

1. Ask user to paste or point to their current backlog (could be GitHub Issues URL, a file, or manual entry)
2. Convert each task to `.metis/tasks/todo/XX-name.md` format:
   ```markdown
   # Task XX: Title

   ## Summary
   [converted from source]

   ## Requirements
   [extracted or asked]

   ## Status
   Status: todo
   ```
3. Ask user to confirm priority ordering

If no tasks to import, skip this step.

## Step 8: Report

```
MIGRATION COMPLETE
═══════════════════════════════════════════════════

Source:    Cursor (.cursorrules)
Profile:   typescript-node (v0.1.0)
Capabilities: typescript + {project}-conventions (custom)
Config:    .metis/config.json
Ask Mode:  super-ask (based on your preference)
Tasks:     5 imported to .metis/tasks/todo/

Migrated:
  ✓ 14 project rules → typescript capability + custom capability
  ✓ Build/test/lint commands → config.json
  ✓ Source directories → config.json src_dirs
  ✓ 5 tasks → .metis/tasks/todo/

Note: Your .cursorrules file was NOT deleted.
Metis works alongside existing configs — remove it when ready.

Next steps:
  /clear            — Start a fresh conversation (recommended — this one has heavy context)
  /task             — Pick up a task (try --super-ask for thorough planning)
  /swarm            — Run parallel task execution
  /triage           — Audit your imported backlog
  /learn            — Analyze project for more improvement suggestions

═══════════════════════════════════════════════════
```

---

<rules>
- NEVER delete source orchestrator files — the user decides when to remove them
- NEVER overwrite an existing .metis/ directory — if it exists, suggest /install --update instead
- CLAUDE.md is NOT a migration target — Metis works alongside CLAUDE.md. Read it for context but don't move or modify it
- Custom capabilities go in .metis/capabilities/ (consumer project), NOT in plugins/metis-core/capabilities/ (that's the registry)
- All interview rounds should provide well-reasoned AskUserQuestion options with detailed descriptions, not vague one-word choices
- If source analysis reveals sensitive information (API keys, secrets), warn the user and do NOT include them in any Metis files
- The migration interview should reference extracted source data — don't ask questions the source configs already answered (confirm instead)
</rules>
