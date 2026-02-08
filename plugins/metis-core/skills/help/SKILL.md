---
name: help
description: Show available Metis skills, project status, and contextual guidance — the starting point for every user
argument-hint: [skill-name|status|workflow|getting-started] (optional)
allowed-tools: Read, Glob, Grep
---

# Metis Help — Front Door

You are executing the `/help` command. This skill is read-only and zero-cost — it reads project state and presents contextual information. Never modify any files.

## Step 1: Detect Context

Determine which environment you're running in. Check in this order:

1. **Metis repo** — `plugins/metis-core/capabilities/registry.json` exists in the working directory
2. **Consumer project (installed)** — `.metis/config.json` exists
3. **Consumer project (has other orchestrator)** — check for any of these files:
   - `.cursorrules` or `.cursor/rules` → Cursor
   - `.github/copilot-instructions.md` → GitHub Copilot
   - `.windsurfrules` or `.windsurf/rules` → Windsurf
   - `.aider.conf.yml` or `.aider/` → Aider
   - `.continue/` or `.continuerc.json` → Continue
   - `.roo/` or `.roomodes` → Roo Code
   - `.cline/` or `.clinerules` → Cline
4. **Fresh project** — none of the above

If context is **installed** or **metis repo**, read `.metis/config.json` and gather:
- Profile name and version
- Installed capabilities (from config or `.metis/capabilities/manifest.json`)
- Task counts: count files in `.metis/tasks/todo/`, `.metis/tasks/doing/`, `.metis/tasks/done/`
- `ask_mode` setting

## Step 2: Route by Argument

Parse `$ARGUMENTS`:

| Argument | Action |
|----------|--------|
| *(empty)* | Go to **Step 3** — Default Overview |
| A skill name (e.g., `task`, `swarm`, `install`) | Go to **Step 4** — Skill Detail |
| `status` | Go to **Step 5** — Status Dashboard |
| `workflow` | Go to **Step 6** — Workflow Explainer |
| `getting-started` | Go to **Step 7** — Getting Started Guide |
| Anything else | Treat as a possible skill name — go to **Step 4** and handle gracefully if not found |

---

## Step 3: Default Overview (no arguments)

This is the main experience. Output depends on the context tier detected in Step 1.

### Tier A: Installed Consumer Project

```
METIS
═══════════════════════════════════════════════════

Project: {project_name}
Profile: {profile} (v{profile_version})
Capabilities: {comma-separated list}
Tasks: {N} todo · {N} doing · {N} done
Ask Mode: {ask_mode}

Getting Started
  /install            Set up or update .metis/
  /migrate            Import from Cursor, Copilot, Windsurf, etc.

Daily Work
  /task [N]           Pick up and complete a task
  /task --super-ask   Thorough multi-round questioning first
  /swarm              Parallel task execution (dedicated session)
  /triage             Audit backlog, detect stale tasks
  /triage create "…"  Add a new task
  /ship               Create PR, wait for CI, merge

Improvement
  /learn              Analyze project, suggest improvements
  /add-metiskill      Create a custom project skill

More Help
  /help <skill>          Detailed help for any skill
  /help status           Project health dashboard
  /help workflow         Cost model and philosophy
  /help getting-started  Step-by-step onboarding

═══════════════════════════════════════════════════
```

End with **"What to do next"** — 2-3 concrete suggestions based on current state:
- Tasks in todo? → `You have {N} tasks in todo. Run /task to pick one up.`
- Tasks in doing? → `You have {N} tasks in progress. Run /task {number} to continue.`
- No tasks at all? → `No tasks yet. Run /triage create "task title" to add one.`
- Many tasks in todo? → `{N} tasks in backlog. Run /triage to audit before starting.`
- Capabilities look sparse? → `Run /learn to check for missing capabilities.`

### Tier B: Fresh Project (no .metis/, no other orchestrator)

```
METIS
═══════════════════════════════════════════════════

No .metis/ directory found — this project hasn't been set up yet.

Getting Started
  /install               Detect project type, choose capabilities, configure
  /migrate               Import setup from Cursor, Copilot, Windsurf, etc.
  /help getting-started  Step-by-step onboarding guide
  /help workflow         Learn about Metis's cost-efficient approach

All Skills
  /task    /swarm    /triage    /ship    /learn    /add-metiskill

═══════════════════════════════════════════════════

What to do next:
  → Run /install to set up Metis for this project.
```

### Tier C: Has Other Orchestrator (no .metis/)

```
METIS
═══════════════════════════════════════════════════

No .metis/ directory found — but we noticed:
  ● {Orchestrator name} configuration ({file path})

Getting Started
  /migrate               Import your {orchestrator} setup into Metis (recommended)
  /install               Fresh install (ignores existing config)
  /help getting-started  Step-by-step onboarding guide

All Skills
  /task    /swarm    /triage    /ship    /learn    /add-metiskill

═══════════════════════════════════════════════════

What to do next:
  → Run /migrate to import your {orchestrator} configuration into Metis.
```

List all detected orchestrators if multiple are found.

### Tier D: Metis Repo

Show everything from Tier A (the metis repo has `.metis/` too), **plus** a Repo Management section:

```
Repo Management (metis-core development)
  /add-capability     Add a new capability to the registry
  /scaffold-skill     Create a new core skill
  /validate           Lint skills and capabilities
  /release            Bump version, tag, and publish
```

Insert this section after the "Improvement" section and before the "More Help" section.

---

## Step 4: Skill Detail (`/help <skill-name>`)

Read the target skill's SKILL.md file:

1. Try `plugins/metis-core/skills/{skill-name}/SKILL.md` (metis repo context)
2. Also try `.metis/skills/{skill-name}/SKILL.md` (custom project skills)
3. If not found in either location, show an error with suggestions (see "Unknown Skill" below)

Once found, synthesize a concise summary. Do NOT dump the raw SKILL.md — extract and present:

```
/skill-name — {description from frontmatter}
═══════════════════════════════════════════════════

{What it does — 1-2 sentences from the description}

Arguments:
  {argument-hint from frontmatter, expanded with explanations}

Workflow:
  1. {Step name} — {one-line summary}
  2. {Step name} — {one-line summary}
  ...

Key Rules:
  • {rule 1}
  • {rule 2}
  ...

Cost: {cost tier — derive from allowed-tools:
  - Has Task/TaskOutput → "Opus + Sonnet/Haiku (multi-agent)"
  - Has Bash + Write but no Task → "Opus only"
  - Only Read/Glob/Grep → "Free (read-only)"}

Example:
  /skill-name              {basic usage}
  /skill-name --flag       {flag usage, if applicable}

═══════════════════════════════════════════════════
```

### Unknown Skill Handling

If the skill name doesn't match any SKILL.md file:

1. List all available skill names (glob `plugins/metis-core/skills/*/SKILL.md` and `.metis/skills/*/SKILL.md`)
2. Check for close matches (e.g., user typed "tasks" but skill is "task", or "tri" could mean "triage")
3. Show:

```
Skill "{input}" not found.

Did you mean:
  /task    — Pick up and complete a task
  /triage  — Audit backlog, detect stale tasks

All available skills:
  /install  /migrate  /task  /swarm  /triage  /ship
  /learn  /add-metiskill  /help

Run /help <skill> for details on any skill.
```

---

## Step 5: Status Dashboard (`/help status`)

Read `.metis/config.json`, `.metis/capabilities/manifest.json`, `.metis/learnings.json`, and task directories. If `.metis/` doesn't exist, show a message suggesting `/install`.

```
METIS STATUS
═══════════════════════════════════════════════════

Profile: {profile} (v{profile_version})
Metis Version: {metis_version}

Capabilities ({count}):
  {name} v{version}    {name} v{version}    {name} v{version}

Task Board:
  Todo:  {N} tasks
  Doing: {N} tasks
  Done:  {N} tasks

Config:
  Ask Mode:      {ask_mode}
  Max Agents:    {max_agents}
  Src Dirs:      {src_dirs}
  Verify:        {verify_command or "not set"}
  Test:          {test_command or "not set"}
  Lint:          {lint_command or "not set"}

Learning:
  Auto-suggest:  {on/off}
  Last learned:  {date or "never"}
  Entries:       {count from learnings.json}

═══════════════════════════════════════════════════
```

End with "What to do next" based on what looks missing or stale.

---

## Step 6: Workflow Explainer (`/help workflow`)

Present the Metis philosophy and cost model. This is a teaching moment — be clear and educational.

```
METIS WORKFLOW
═══════════════════════════════════════════════════

Ask → Explore → Research → Plan → Execute

Every task follows this cost-conscious workflow:

  1. ASK — Clarify requirements before spending tokens.
     Model: Opus (direct conversation)
     Why: A 30-second question saves a $0.50 wrong implementation.

  2. EXPLORE — Search the codebase cheaply.
     Model: Haiku ($0.05) or grep/glob (free)
     Why: Understanding what exists prevents duplicate work.

  3. RESEARCH — Search the web for docs, patterns, known issues.
     Model: Haiku executes searches, Opus evaluates results
     Why: Real developers constantly check docs. Agents should too.

  4. PLAN — Design the approach, present for approval.
     Model: Opus (reasoning)
     Why: Getting alignment before implementation prevents rework.

  5. EXECUTE — Implement with focused, minimal prompts.
     Model: Sonnet ($0.50/task)
     Why: Sonnet is the best cost/quality balance for code writing.

Cost Model:
  ┌──────────┬──────────────────────────────────┬──────────────┐
  │ Model    │ Use Case                         │ Est. Cost    │
  ├──────────┼──────────────────────────────────┼──────────────┤
  │ Haiku    │ Exploration, diagnostics, data   │ ~$0.05/task  │
  │ Sonnet   │ Implementation, code writing     │ ~$0.50/task  │
  │ Opus     │ Orchestration, judgment (spine)   │ ~$0.30/iter  │
  └──────────┴──────────────────────────────────┴──────────────┘

Capability Subsetting:
  Not every agent needs every capability. When spawning work agents,
  Metis injects ONLY capabilities relevant to that specific work item.
  A backend API task skips react-native, ios-simulator, maestro —
  reducing prompt size by 60-80%.

When to use /task vs /swarm:
  /task   — One task at a time. Interactive. Good for complex or
            ambiguous work that needs back-and-forth.
  /swarm  — Multiple tasks in parallel. Autonomous. Best for a batch
            of well-defined, independent tasks. Run in a dedicated
            session.

═══════════════════════════════════════════════════

What to do next:
  → Run /help getting-started for a step-by-step onboarding guide.
  → Run /task to try the workflow on a real task.
```

---

## Step 7: Getting Started Guide (`/help getting-started`)

Step-by-step onboarding for new users.

```
GETTING STARTED WITH METIS
═══════════════════════════════════════════════════

Step 1: Set Up Your Project

  /install
    Detects your project type (TypeScript, Python, Go, etc.),
    suggests a capability profile, and creates .metis/ with
    everything configured.

  Coming from Cursor, Copilot, or Windsurf?
    /migrate
    Imports your existing rules and configuration into Metis.

Step 2: Add Tasks to Your Backlog

  /triage create "Add user authentication"
  /triage create "Fix checkout flow bug"
  /triage create "Refactor API error handling"

  Tasks are stored in .metis/tasks/todo/ as markdown files.
  You can also create them manually.

Step 3: Work on Tasks

  /task             Pick up the highest-priority task
  /task 01          Work on a specific task
  /task --super-ask Thorough questioning before implementation

  For parallel execution of multiple tasks:
  /swarm            Run in a dedicated session

Step 4: Improve Over Time

  /learn            Analyze project, find missing capabilities
  /learn --deep     Thorough analysis with web research
  /add-metiskill    Create custom skills for repetitive workflows

Tips for Cost Efficiency:
  • Use /task for complex work (interactive, catches mistakes early)
  • Use /swarm for batches of well-defined tasks
  • Set ask_mode to "super-ask" in .metis/config.json for thorough
    requirements gathering on every task
  • Run /learn periodically to keep capabilities up to date
  • Run /triage before /swarm to clean up stale tasks first

═══════════════════════════════════════════════════
```

End with "What to do next" based on detected context:
- Not installed? → `Run /install to get started.`
- Installed but no tasks? → `Run /triage create "..." to add your first task.`
- Has tasks? → `Run /task to pick one up.`

---

## Rules

<rules>
- NEVER modify any files — this skill is strictly read-only
- ALWAYS end every output mode with "What to do next" suggestions (2-3 concrete, runnable commands based on current state)
- Handle unknown skill names gracefully — suggest the closest match or list all skills
- If .metis/ doesn't exist and the user asks for /help status, say so and suggest /install
- Keep output scannable — use the template formats above, don't add extra prose
- Include both core skills AND custom project skills (from .metis/skills/) when listing
- In the metis repo context, show repo management skills in addition to consumer skills
- When deriving cost tier for a skill, use allowed-tools as the signal (Task tool = multi-agent, Bash only = Opus only, Read/Glob/Grep only = free)
</rules>
