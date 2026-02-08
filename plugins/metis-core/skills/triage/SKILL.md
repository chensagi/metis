---
name: triage
description: Audit all tasks against the current codebase, detect stale/obsolete/partial tasks, suggest actions, create new tasks, and maintain .metis/tasks/project.md as the living project plan
argument-hint: [task-number|create "task title"] (optional - triage a specific task, create a new task, or leave blank for full backlog)
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, TaskOutput
---

# Triage — Codebase-Aware Task Auditor

You are executing the `/triage` command. This skill analyzes every task in `.metis/tasks/todo/` against the **current state of the codebase** and presents actionable suggestions. It can also create new tasks for the backlog.

## Bootstrap

Before starting, ensure `.metis/` exists with a valid config:

1. **If `.metis/config.json` exists** → Read it, load capabilities from `.metis/capabilities/`, proceed
2. **If `.metis/` doesn't exist** → Tell the user to run `/install` first for full interactive setup. If they want to proceed immediately, do a minimal bootstrap:
   - `mkdir -p .metis/capabilities .metis/skills .metis/tasks/todo .metis/tasks/doing .metis/tasks/done`
   - Create `.metis/.gitignore` (hybrid tracking)
   - Auto-detect project type and create minimal `.metis/config.json`

Read `.metis/capabilities/manifest.json` (if exists) — capabilities inform how triage analyzes the codebase (e.g., knowing about Zustand means checking for store consistency).

## Philosophy

- **Suggest, don't ask.** Lead with a clear recommendation and reasoning. Only ask when you genuinely can't decide (e.g., a product direction choice).
- **Be codebase-aware.** Don't just read task specs — grep the actual code to see what exists, what changed, and what conflicts.
- **Respect the user's time.** Group findings into a scannable report. Don't make them read 50 questions.

---

## Commands

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

### Step 5: Apply Changes (with user approval)

After presenting the report, wait for the user to approve/modify suggestions. Then:

**For REMOVE tasks:**
```bash
git mv .metis/tasks/todo/${filename} .metis/tasks/done/${filename}
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

After triage decisions are applied, create or update `.metis/tasks/project.md`:

```markdown
# {project_name} — Project Plan

*Last triaged: YYYY-MM-DD*
*Tasks: X todo / Y doing / Z done*

## Critical Path

The shortest path to the next shippable milestone:

1. **Task XX: Title** — Description
   - Blocks: nothing
   - Blocked by: nothing
   - Complexity: Low/Medium/High

## All Tasks (prioritized)

| # | Task | Status | Complexity | Blocks | Blocked By | Notes |
|---|------|--------|------------|--------|------------|-------|
| XX | Title | todo | Medium | — | — | Notes |

## Blocking Issues

- Description of blocking issues and options

## Recently Completed

| # | Task | Completed | Resolution |
|---|------|-----------|------------|
| XX | Title | YYYY-MM-DD | How it was resolved |

## Architecture Notes

Key decisions that affect task planning (auto-populated from codebase analysis).
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

## Summary

{Brief description of what needs to be done and why}

## Requirements

- {Requirement 1}
- {Requirement 2}

## Acceptance Criteria

- [ ] {Criterion 1}
- [ ] {Criterion 2}

## Technical Details

{Implementation guidance, relevant files, approach suggestions}
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

## Spawning Strategy (2-Layer Leaf-Spine)

Triage is a reasoning task — judgment (assigning DONE/PARTIAL/STALE status) stays with Opus. Haiku agents only gather raw evidence. This follows the metis architecture: leaves gather data, spine reasons about it.

**For small backlogs (< 10 tasks):** Opus analyzes directly. No agents needed.

**For larger backlogs (10+ tasks):** Two-phase approach:

### Phase 1: Data Gathering (Haiku Leaves)

Spawn up to 3 Haiku agents in parallel, each gathering raw evidence for a batch of tasks. These agents collect data — they do NOT assign status or make judgments.

```
Task({
  description: "Gather evidence for tasks ${startNum}-${endNum}",
  prompt: `You are a data-gathering agent. Your job is to collect RAW EVIDENCE about each task — nothing more.

Read the project's CLAUDE.md (if it exists) for codebase conventions.

For each task in your batch, gather:
1. Read the task file — note what it wants to achieve and which files/components it targets
2. Grep for key function names, component names, module names from the task spec
3. Check if files the task wants to create already exist (use Glob)
4. Check git history for relevant commits: git log --oneline --all --grep="${keyword}" (try 2-3 keywords per task)
5. List dependencies/libraries the task assumes — check if they exist in package.json/pyproject.toml/go.mod
6. Note any code patterns that seem related to the task's goal

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
