---
name: triage
description: Audit all tasks against the current codebase, detect stale/obsolete/partial tasks, suggest actions, create new tasks, and maintain .metis/tasks/project.md as the living project plan
argument-hint: [task-number|create "task title"] (optional - triage a specific task, create a new task, or leave blank for full backlog)
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, TaskOutput, WebSearch, WebFetch
---

# Triage — Codebase-Aware Task Auditor

You are executing the `/triage` command. This skill analyzes every task in `.metis/tasks/todo/` against the **current state of the codebase** and presents actionable suggestions. It can also create new tasks for the backlog.

## Bootstrap

<rules>
BEFORE DOING ANYTHING ELSE, check if `.metis/config.json` exists:
- **If it exists** → Read it, load capabilities from `.metis/capabilities/`, proceed
- **If `.metis/` does not exist** → STOP. Tell the user: "Run `/install` first to set up Metis for this project." Do NOT proceed. Do NOT fall back to any other directory structure. Do NOT attempt to work without `.metis/`. This is a hard requirement — the skill cannot function without it.
</rules>

Read `.metis/capabilities/manifest.json` (if exists) — capabilities inform how triage analyzes the codebase (e.g., knowing about Zustand means checking for store consistency).

## Philosophy

- **Suggest, don't ask.** Lead with a clear recommendation and reasoning. Only ask when you genuinely can't decide (e.g., a product direction choice).
- **Be codebase-aware.** Don't just read task specs — grep the actual code to see what exists, what changed, and what conflicts.
- **Respect the user's time.** Group findings into a scannable report. Don't make them read 50 questions.

---

## Commands

**All commands run Bootstrap first** — there are no exceptions.

### `/triage` (default — full backlog audit)

Run the full triage workflow below.

### `/triage [task-number]`

Deep-dive analysis of a single task. Read the spec, thoroughly search the codebase for everything related, present a detailed analysis with specific suggestions.

### `/triage create "task title"`

Create a new task in the backlog. See "Creating Tasks" section below.

---

## Full Triage Workflow

### Step 1: Gather Context

**Read the full picture before analyzing individual tasks:**

1. Read `.metis/tasks/project.md` if it exists (previous triage output)
2. Read `.metis/config.json` for project settings
3. List all files in `.metis/tasks/todo/`, `.metis/tasks/doing/`, `.metis/tasks/done/`
4. Read recent git history to understand what changed recently:
   ```bash
   git log --oneline -20
   ```
5. Get a sense of the current codebase shape by listing the directories in `src_dirs` from config (or common defaults like `src/`, `lib/`, `app/`)

### Step 2: Detect Untracked Work

Before analyzing tasks, scan for **code that was shipped without updating tasks**:

1. Read each task in `.metis/tasks/todo/` and `.metis/tasks/doing/`
2. For each, grep the codebase for the key features/components the task describes
3. If the feature already exists in code but the task is still in `todo/` → flag as **DONE (untracked)**
4. If the feature is partially in code but the task is still in `todo/` → flag as **PARTIAL (untracked)**
5. Also check `.metis/tasks/done/` tasks — if a "done" task's described feature doesn't actually exist in the code (was reverted, refactored away), flag as **REGRESSED**

Additionally, scan recent git log for significant features that have no corresponding task at all:
```bash
git log --oneline -30
```
Cross-reference commit messages against task titles. If there are commits for features/fixes that don't map to any task, note them as **untracked shipped work** in the report — this helps keep `project.md` accurate.

### Step 3: Analyze Each Task

**Small backlogs (< 10 tasks):** Analyze each task directly — you (Opus) read each spec, grep for key terms, check file existence, and assign status. No agents needed.

**Large backlogs (10+ tasks):** Use the two-phase approach described in "Spawning Strategy" below. Haiku agents gather raw evidence, then you (Opus) reason about the findings and assign status.

For each task, the analysis must determine:

1. **Evidence of implementation** — grep for key function names, component names, check if target files exist
2. **Conflicts** — has the architecture changed in ways that make the task's approach outdated?
3. **Feasibility** — are the dependencies/libraries/APIs the task assumes still available?
4. **Cross-task dependencies** — does this task overlap with or depend on other tasks?
5. **Dependency consistency** — if the task has `Blocked by:` fields, verify those tasks exist and are in the expected state. Flag broken chains (referencing deleted/nonexistent tasks) or circular dependencies

**Status assessments** (assigned by Opus only — never by leaf agents):

| Assessment | Meaning |
|------------|---------|
| **DONE** | The codebase already does what this task describes. Task is obsolete. |
| **PARTIAL** | Some parts are implemented, others aren't. Task needs updating. |
| **STALE** | The approach described is outdated due to codebase changes. Needs rethinking. |
| **BLOCKED** | Depends on something that doesn't exist yet or has changed. |
| **READY** | Task is still relevant and actionable as-is. |
| **QUESTIONABLE** | Not sure this feature is still wanted given the current direction. |

### Step 4: Build the Triage Report

Present findings grouped by suggested action, most impactful first:

```
TRIAGE REPORT
=================================================

RECOMMEND: REMOVE (N tasks)

  Task XX: Title
  Status: DONE
  Evidence: Feature already exists in src/path/file.ts:45
  Added in commit: abc1234 "commit message"
  Suggestion: Delete this task — it's fully implemented.

-------------------------------------------------

UNTRACKED SHIPPED WORK (N items)

  These features were shipped but have no matching "done" task:

  1. Feature name (commit abc1234)
     Files: path/to/files
     Suggestion: Noted for project.md accuracy.

-------------------------------------------------

REGRESSIONS (N items)

  "Done" tasks whose features are missing from the codebase.

-------------------------------------------------

RECOMMEND: UPDATE (N tasks)

  Task XX: Title
  Status: PARTIAL
  Evidence: Some parts exist, others don't.
  What changed: Description of what changed.
  Suggestion: Update spec to reference current code.
  Changes I'd make: [specific edits to the task file]

-------------------------------------------------

RECOMMEND: KEEP AS-IS (N tasks)

  Task XX: Title — READY

-------------------------------------------------

RECOMMEND: RETHINK (N tasks)

  Task XX: Title
  Status: BLOCKED
  Evidence: Why it's blocked.
  Suggestion: Alternative approach.

=================================================

Summary:
- N tasks to remove
- N tasks to update
- N tasks ready to execute
- N tasks need rethinking

Would you like me to apply the suggested changes?
```

STOP here and wait for the user to approve, modify, or reject the suggestions. Do NOT apply any changes until the user explicitly approves.

### Step 5: Apply Changes (with user approval)

After the user approves:

**For REMOVE tasks:**
```bash
mv .metis/tasks/todo/${filename} .metis/tasks/done/${filename}
```
Add a note to the task file:
```markdown
## Completed
- **Date:** YYYY-MM-DD
- **Resolution:** Closed by triage — feature already implemented in [file/commit]
```

**For UPDATE tasks:**
Edit the task file with the specific changes suggested in the report.

**For RETHINK tasks:**
Rewrite the task file with the new approach (preserving the original summary/intent).

### Step 6: Generate/Update `.metis/tasks/project.md`

After triage decisions are applied, create or update `.metis/tasks/project.md`.

**Preservation rule:** If `project.md` already exists, preserve the **Vision** and **Architecture Notes** sections — these contain user-authored context. Regenerate all other sections from current task state.

```markdown
# {project_name} — Project Plan

*Last updated: YYYY-MM-DD*
*Tasks: X todo / Y doing / Z done*

## Vision

{High-level product intent. What the user is building and core design principles.
If this section exists from a previous run, PRESERVE IT — do not regenerate.
If this is the first run, summarize what you learned from the codebase and task specs.}

## Critical Path

The shortest dependency chain to the next shippable milestone:

1. **Task XX: Title** [complexity]
   Blocked by: none
2. **Task XX: Title** [complexity]
   Blocked by: Task XX
3. ...

{Follow the Blocked by: fields to build the critical path. The longest chain of
dependent tasks determines the minimum execution sequence.}

## Phases

{For projects with 10+ tasks, group into logical phases:}

### Phase 1: {theme}
| # | Task | Priority | Complexity | Blocked By | Blocks |
|---|------|----------|------------|------------|--------|

### Phase 2: {theme}
...

{For projects with < 10 tasks, omit this section — the All Tasks table is sufficient.}

## All Tasks

| # | Task | Status | Priority | Complexity | Blocked By | Blocks | Notes |
|---|------|--------|----------|------------|------------|--------|-------|
| XX | Title | todo | high | medium | — | 05, 07 | Notes |

## Dependency Graph

{ASCII art showing task dependency flow. Only include for projects with 5+ tasks
that have non-trivial dependencies:}

```
01 → 03 → 05
02 → 04 ──|
           |→ 06
03 ───────|
```

## Blocking Issues

{Issues preventing progress. Include both task-level blocks and external blockers
(missing infrastructure, pending decisions, etc.)}

## Architecture Notes

{Key decisions that affect task planning.
If this section exists from a previous run, PRESERVE IT — do not regenerate.
Add new notes discovered during triage, but never remove existing ones.}

## Recently Completed

| # | Task | Completed | Resolution |
|---|------|-----------|------------|
| XX | Title | YYYY-MM-DD | How it was resolved |

## Untracked Shipped Work

{Features shipped without corresponding tasks — discovered during triage.
Keeps the project plan accurate even when work happens outside the task board.}

| Feature | Key Files | Commits |
|---------|-----------|---------|
```

---

## Creating Tasks

When run with `/triage create "task title"` or when the triage report suggests new tasks:

### Task File Format

Create a new file in `.metis/tasks/todo/` with the next available number:

```markdown
# Task XX: {title}

**Status:** todo
**Priority:** {low|medium|high}
**Complexity:** {low|medium|high}
**Blocked by:** {task numbers, comma-separated, or "none"}
**Blocks:** {task numbers, comma-separated, or "none"}

## Summary

{What and why — 2-3 sentences.}

## Research Context

{What already exists in the codebase that is relevant.
- Existing files, utilities, patterns that touch this area
- Data formats or schemas already in use
Omit for greenfield tasks.}

## Requirements

- {Requirement 1}
- {Requirement 2}

## Design

{The approach. Algorithm, schema, state flow as needed.
Omit for trivial tasks.}

## Key Files

| File | Action | What Changes |
|------|--------|-------------|
| `src/path/file.ts` | Modify | Description |

## Scope Boundaries

**NOT in scope (do NOT implement):**
- {Explicit exclusions}

**Files NOT to modify:**
- {Files to leave alone}

## Acceptance Criteria

- [ ] {Criterion 1}
- [ ] {Criterion 2}

## Technical Details

{Implementation guidance, research hints for agents}
```

### Auto-Numbering

Find the highest task number across all directories (todo, doing, done) and increment by 1.

### Interactive Creation

When creating a task interactively:
1. Ask the user for the summary/requirements if not provided
2. Scan the codebase to pre-populate technical details (relevant files, existing patterns)
3. Suggest a complexity estimate based on the scope
4. Write the task file and confirm

---

## Single Task Mode

When run with a task number (e.g., `/triage 40`), only analyze that one task:

1. Read the task spec
2. Deep-dive into the codebase for everything related
3. Present a detailed analysis with specific suggestions
4. Offer to apply changes

This is useful for re-evaluating a specific task before starting work on it.

---

## Spawning Strategy (3-Layer Architecture)

Triage is a reasoning task — judgment (assigning DONE/PARTIAL/STALE status) stays with Opus (L1). Haiku agents (L2) only gather raw evidence, including web research for staleness detection. L0 dispatches between them.

**For small backlogs (< 10 tasks):** Opus analyzes directly. No agents needed.

**For larger backlogs (10+ tasks):** Two-phase approach:

### Phase 1: Data Gathering (Haiku Leaves)

Spawn up to 3 Haiku agents in parallel, each gathering raw evidence for a batch of tasks. These agents collect data — they do NOT assign status or make judgments.

```
Task({
  description: "[Haiku] Gather evidence for tasks ${startNum}-${endNum}",
  prompt: `You are a data-gathering agent. Your job is to collect RAW EVIDENCE about each task — nothing more.

Read the project's CLAUDE.md (if it exists) for codebase conventions.

For each task in your batch, gather:
1. Read the task file — note what it wants to achieve and which files/components it targets
2. Grep for key function names, component names, module names from the task spec
3. Check if files the task wants to create already exist (use Glob)
4. Check git history for relevant commits: git log --oneline --all --grep="${keyword}" (try 2-3 keywords per task)
5. List dependencies/libraries the task assumes — check if they exist in package.json/pyproject.toml/go.mod
6. Note any code patterns that seem related to the task's goal
7. For tasks referencing specific libraries or APIs, use WebSearch to check:
   - Is the library still maintained? What's the latest version?
   - Has the API the task assumes changed in recent versions?
   - Are there known migration guides if versions have shifted?
   Report raw findings — do NOT judge staleness (that's Opus's job)

IMPORTANT: You are gathering RAW DATA only.
- DO NOT assign status (no DONE, PARTIAL, STALE, BLOCKED, READY, QUESTIONABLE)
- DO NOT make judgments about whether a task is complete or obsolete
- DO NOT recommend actions
- Just report what you found — files, code snippets, git commits, dependency presence

Tasks to analyze: ${taskFiles.join(', ')}

For each task, write a structured evidence block:

## Task ${num}: ${title}
### Files Found
- list of relevant files discovered with brief content notes
### Code Evidence
- grep matches with file:line references
### Git History
- relevant commits found
### Dependencies
- which assumed deps exist / don't exist
### Raw Notes
- anything else relevant

Write your findings to .metis/triage-batch-${batchNum}.md`,
  subagent_type: "Explore",
  model: "haiku",
  run_in_background: true,
  max_turns: 15
})
```

### Phase 2: Synthesis and Judgment (Opus Spine)

After all Haiku agents complete, YOU (the orchestrator, Opus) read all `.metis/triage-batch-*.md` files and:

1. **Assign status** for each task (DONE / PARTIAL / STALE / BLOCKED / READY / QUESTIONABLE) based on the raw evidence
2. **Cross-reference tasks** — identify dependencies and conflicts that individual agents couldn't see (e.g., Task 12 and Task 18 both want to create the same auth module)
3. **Detect untracked work** — cross-reference git history from all batches to find shipped features with no matching task
4. **Generate the triage report** with synthesized analysis (see Step 4 format)

This separation ensures consistent judgment. Individual Haiku agents can't see the full backlog, so they can't detect cross-task conflicts or make accurate status calls. Only the spine has the full picture.

5. **Clean up temporary files** — Delete the batch files after synthesis: `rm .metis/triage-batch-*.md`

---

## When to Run

- **Before starting a swarm** — Clean up the backlog so swarm only runs valid tasks
- **After a big feature lands** — Check if other tasks became obsolete
- **Weekly during active development** — Keep the backlog healthy
- **When the backlog feels stale** — "I haven't looked at these tasks in a while"

---

## Limitations

1. **Can't know product intent** — The skill can tell you a feature is already implemented, but can't know if you want to redo it differently. It will suggest DONE but you can override.
2. **Complexity estimates are rough** — Based on file count and scope, not actual implementation time.
3. **No runtime testing** — Analysis is static (grep, file existence, type checking). It can't verify features actually work correctly.

<rules>
- Status assessments (DONE/PARTIAL/STALE/BLOCKED/READY/QUESTIONABLE) are assigned by Opus ONLY — never by Haiku leaf agents
- NEVER apply triage changes without explicit user approval — always STOP and wait after presenting the report
- NEVER delete task files — move them to done/ with a resolution note
- When creating tasks, always check existing backlog for duplicates first
- Clean up temporary triage batch files (.metis/triage-batch-*.md) after synthesis
- ALL commands (/triage, /triage [number], /triage create) MUST run Bootstrap first
</rules>

After completing triage, suggest `/clear` to start a fresh conversation.
