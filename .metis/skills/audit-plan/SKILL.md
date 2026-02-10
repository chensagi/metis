---
name: audit-plan
description: Audit all tasks against the codebase to verify the plan is viable, complete, and correctly ordered
argument-hint: [focus-area] (optional: structure|quality|coverage|fix|all)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, TaskOutput
---

# Plan Auditor

You are executing the `/audit-plan` command. This skill spawns multiple agents in parallel to audit different aspects of the task backlog, then synthesizes their findings.

## Bootstrap

<rules>
BEFORE DOING ANYTHING ELSE, check if `.metis/config.json` exists:
- **If it exists** -> Read it, load capabilities from `.metis/capabilities/`, proceed to Step 1
- **If `.metis/` does not exist** -> STOP. Tell the user: "Run `/install` first to set up Metis for this project." Do NOT proceed.
</rules>

Read `.metis/capabilities/manifest.json` (if exists) and load capability names — the quality auditor needs these to check capability alignment.

## How It Works

1. Spawn **3 parallel agents**, each auditing one dimension
2. Each agent writes findings to `.audit/` directory
3. Collect and synthesize all findings into a unified report
4. Present issues by severity with recommended fixes

## Audit Dimensions

| Agent | Focus | What It Checks |
|-------|-------|----------------|
| **structure-auditor** | Dependencies & Codebase | Circular deps, missing deps, ordering, existing code, correct paths, pattern consistency |
| **quality-auditor** | Task Quality & Tech | Missing details, acceptance criteria, tech stack match, feasible approaches, capability alignment |
| **coverage-auditor** | Gaps & Coverage | Missing features, orphan tasks, config alignment, incomplete task coverage |

## Execution

### Step 1: Setup

```bash
mkdir -p .audit
```

### Step 2: Gather Context

Before spawning agents, collect context they'll all need:

1. List all task files across all states:
   - `.metis/tasks/todo/*.md` — pending tasks
   - `.metis/tasks/doing/*.md` — in-progress tasks
   - `.metis/tasks/done/*.md` — completed tasks
2. Read `.metis/config.json` for project configuration (src_dirs, verify_command, etc.)
3. Read `.metis/capabilities/manifest.json` for installed capabilities
4. Check if `CLAUDE.md` exists at the project root — it contains project conventions

### Step 3: Spawn Parallel Agents

Spawn all 3 agents simultaneously using Task tool with `run_in_background: true`.

If a focus argument was provided, only spawn the matching agent:
- `/audit-plan structure` — Only structure agent
- `/audit-plan quality` — Only quality agent
- `/audit-plan coverage` — Only coverage agent
- `/audit-plan all` or no argument — All 3 agents

```
Task({
  description: "Audit: Dependencies",
  prompt: <see agent prompts below>,
  subagent_type: "general-purpose",
  model: "haiku",
  run_in_background: true
})
// Repeat for all 3 agents
```

### Step 4: Monitor & Collect

Check agent output files periodically. When all complete, read findings from:
- `.audit/structure.md` (dependencies + codebase alignment)
- `.audit/quality.md` (completeness + technical viability)
- `.audit/coverage.md` (gaps + feature coverage)

### Step 5: Synthesize Report

Combine all findings into a single report, sorted by severity:
1. Critical (blocks progress)
2. Warning (should address)
3. Suggestion (nice to have)

---

## Agent Prompts

### Agent 1: Structure Auditor (Dependencies + Codebase)

<agent-prompt>
You are the Structure Auditor. Your job is to verify that task dependencies are correct and that tasks align with the actual codebase.

## Steps
1. Read all task files in `.metis/tasks/todo/` and `.metis/tasks/doing/`
2. Scan the existing codebase structure using the project's `src_dirs` from `.metis/config.json`
3. For each task, verify:
   - All listed dependencies (`Depends On`) make logical sense
   - No circular dependencies exist in the dependency graph
   - Transitive dependencies are satisfied (if A depends on B, and B depends on C, A implicitly needs C)
   - If a task references existing files, do they actually exist?
   - If code already exists for a feature described in a task, does the task know about it?
   - Do file paths in Technical Details match the actual project structure?
   - Are tasks ordered correctly? (foundation before features, types before implementation)
4. Check for dependency conflicts with in-progress tasks (`.metis/tasks/doing/`)

## Output
Write your findings to `.audit/structure.md` in this format:

```markdown
# Structure Audit (Dependencies + Codebase)

## Critical Issues
- [Task XX]: Has circular dependency with Task YY
- [Task XX]: Missing dependency on Task YY (uses types defined in YY)
- [Task XX]: References src/foo/bar.ts but file doesn't exist

## Warnings
- [Task XX]: Long dependency chain (5+ steps) may slow progress
- [Task XX]: Feature already partially implemented in src/existing.ts
- [Task XX]: In-progress Task YY modifies same files — potential conflict

## Suggestions
- [Task XX]: Could run parallel with Task YY (no actual dependency)
- [Task XX]: Could extend existing pattern in src/utils/

## Statistics
- Tasks audited: X
- Dependency relationships: X
- Issues found: X

## Codebase State
- Source directories: [list from config]
- Key existing modules: [describe relevant existing code]
```

Be thorough. Check every task. Write findings to the file.
</agent-prompt>

### Agent 2: Quality Auditor (Completeness + Technical)

<agent-prompt>
You are the Quality Auditor. Your job is to verify that every task is implementation-ready with clear requirements and feasible technical approach.

## Steps
1. Read `.metis/config.json` to understand the project setup (verify_command, test_command, src_dirs)
2. Read `.metis/capabilities/manifest.json` to know which capabilities are installed
3. Read each task file in `.metis/tasks/todo/` and `.metis/tasks/doing/`
4. For each task, check:
   - Does it have a clear Summary section?
   - Are Requirements specific and actionable (not vague)?
   - Are Acceptance Criteria checkboxes specific and testable?
   - Does Technical Details reference real files, patterns, and approaches?
   - Are there ambiguous terms that need clarification?
   - Do referenced libraries/tools match the project's installed capabilities?
   - No two tasks create the same file (file conflicts)?
   - Is the complexity rating reasonable given the scope?
   - If verify_command is configured, does the task account for verification?

## Capability Alignment Check
For each task's Technical Details, verify:
- Referenced technologies match installed capabilities
- No task assumes a capability that isn't installed
- Suggested patterns align with capability instructions

## Output
Write your findings to `.audit/quality.md` in this format:

```markdown
# Quality Audit (Completeness + Technical)

## Critical Issues
- [Task XX]: No acceptance criteria defined
- [Task YY]: Creates src/foo.ts but Task ZZ also creates it
- [Task XX]: References React Native but no react-native capability installed

## Warnings
- [Task XX]: Technical Details section is empty or generic
- [Task YY]: References "the component" without specifying which
- [Task XX]: Complexity rated "low" but touches 8+ files

## Suggestions
- [Task XX]: Could benefit from more specific acceptance criteria
- [Task XX]: Could reuse existing utility in src/utils/

## Capability Alignment
- Installed: [list capabilities]
- Tasks referencing unlisted tech: [list any mismatches]

## File Conflict Check
- [List any files that multiple tasks claim to create or modify]

## Statistics
- Tasks audited: X
- Fully implementation-ready: X
- Need improvement: X
```

Be thorough. A task should be implementable by an agent reading only that file plus the codebase.
</agent-prompt>

### Agent 3: Coverage Auditor (Gaps & Features)

<agent-prompt>
You are the Coverage Auditor. Your job is to find missing tasks, orphan tasks, and ensure all features described in the project are covered.

## Steps
1. Read all task files across all states: `.metis/tasks/todo/`, `.metis/tasks/doing/`, `.metis/tasks/done/`
2. Read `CLAUDE.md` (if exists) for project context and conventions
3. Read `.metis/config.json` for project configuration
4. Check for:
   - Features or requirements mentioned in CLAUDE.md or project docs that have no corresponding task
   - Orphan tasks (nothing depends on them AND they depend on nothing — may be disconnected)
   - Missing infrastructure tasks (testing setup, CI/CD, deployment, documentation)
   - Incomplete feature coverage (e.g., a feature partially described across tasks with gaps)
   - Tasks in `doing/` that appear stalled (no recent progress indicators)
   - Completed tasks (`done/`) that created follow-up items not yet captured as tasks
5. Check `.metis/learnings.json` for any suggestions that haven't been acted on

## Output
Write your findings to `.audit/coverage.md` in this format:

```markdown
# Coverage Audit (Gaps & Features)

## Critical Gaps
- No task for [critical feature mentioned in CLAUDE.md]
- Feature X is partially covered — Task XX handles part A but part B has no task

## Missing Nice-to-Haves
- No task for test infrastructure setup
- No task for documentation updates

## Suggestions
- Consider adding task for [X]
- Learning from learnings.json not yet applied: [detail]

## Coverage Summary
- Total tasks: X (todo: X, doing: X, done: X)
- Features covered: X/Y (if determinable)
- Orphan tasks: [list any disconnected tasks]

## Backlog Health
- Average task completeness score: X/5
- Tasks with dependencies satisfied: X/Y
- Estimated remaining effort: [low/medium/high]
```

Be thorough. Missing tasks discovered now prevent scope creep later.
</agent-prompt>

---

## Synthesized Report Format

After all agents complete, present:

```
PLAN AUDIT REPORT
================================================================

## Summary
| Dimension                     | Critical | Warning | Suggestion |
|-------------------------------|----------|---------|------------|
| Structure (deps + codebase)   | X        | X       | X          |
| Quality (completeness + tech) | X        | X       | X          |
| Coverage (gaps + features)    | X        | X       | X          |
| **Total**                     | **X**    | **X**   | **X**      |

## Critical Issues (must fix before proceeding)

### From Structure Audit
- ...

### From Quality Audit
- ...

### From Coverage Audit
- ...

## Warnings (should address soon)
- ...

## Suggestions (nice to have)
- ...

================================================================

## Recommended Actions
1. [Highest priority fix]
2. [Second priority fix]
...

Would you like me to fix any of these issues?
```

---

## Fix Mode

### `/audit-plan fix`

Run after an audit to fix identified issues. Reads the `.audit/` reports and spawns fixer agents.

### Fixer Agent Prompts

#### Structure Fixer

<agent-prompt>
You are the Structure Fixer.

## Your Task
Fix all dependency and codebase alignment issues identified in `.audit/structure.md`

## Steps
1. Read `.audit/structure.md` to see the issues
2. Read affected task files in `.metis/tasks/todo/` and `.metis/tasks/doing/`
3. For each issue:
   - Add missing dependencies to task files
   - Remove incorrect dependencies
   - Update file paths to match actual project structure
   - Note existing code that tasks should reference
4. Write a summary of changes to `.audit/structure-fixed.md`

## Rules
- Only fix what's in the audit report
- Preserve existing correct content
- Don't modify completed tasks in done/
- Don't modify source code — only task files
</agent-prompt>

#### Quality Fixer

<agent-prompt>
You are the Quality Fixer.

## Your Task
Fix completeness and technical issues identified in `.audit/quality.md`

## Steps
1. Read `.audit/quality.md` to see the issues
2. For each issue:
   - Add missing acceptance criteria
   - Clarify vague requirements
   - Add technical details if missing (explore codebase to ground them)
   - Correct wrong file paths or technology references
   - Resolve file conflicts (rename one task's target)
3. Write a summary of changes to `.audit/quality-fixed.md`

## Rules
- Don't change the task's scope or intent
- Add detail, don't remove existing content
- Make tasks implementable by an agent reading only that file plus the codebase
- When resolving file conflicts, prefer the task that logically owns the file
</agent-prompt>

#### Coverage Fixer

<agent-prompt>
You are the Coverage Fixer.

## Your Task
Create missing tasks identified in `.audit/coverage.md`

## Steps
1. Read `.audit/coverage.md` to see the gaps
2. For each missing task:
   - Create a new task file in `.metis/tasks/todo/`
   - Follow the existing task format (Summary, Requirements, Acceptance Criteria, Technical Details)
   - Add appropriate dependencies referencing existing tasks
   - Use the next available task number
3. Write a summary of new tasks to `.audit/coverage-fixed.md`

## Rules
- Use next available task number (check highest across todo/doing/done)
- Match the detail level and format of existing tasks
- New tasks must reference real files and patterns from the codebase
- Don't duplicate work already covered by existing tasks
</agent-prompt>

---

## Commands Summary

| Command | What It Does |
|---------|--------------|
| `/audit-plan` | Run all 3 auditors, report issues |
| `/audit-plan structure` | Run only structure auditor (deps + codebase) |
| `/audit-plan quality` | Run only quality auditor (completeness + tech) |
| `/audit-plan coverage` | Run only coverage auditor (gaps + features) |
| `/audit-plan fix` | Fix issues from last audit |
| `/audit-plan all` | Same as no argument — all 3 auditors |

## Output Files

| File | Purpose |
|------|---------|
| `.audit/structure.md` | Dependency + codebase alignment analysis |
| `.audit/quality.md` | Task completeness + technical viability |
| `.audit/coverage.md` | Gap analysis + feature coverage |
| `.audit/structure-fixed.md` | Summary of structure fixes applied |
| `.audit/quality-fixed.md` | Summary of quality fixes applied |
| `.audit/coverage-fixed.md` | Summary of new tasks created |

---

## When to Run

- Before starting a new phase of work
- After running `/create-tasks` to validate the generated backlog
- After a `/swarm` session to check what's left
- When something feels wrong about the plan
- Periodically during active development

---

## Key Rules

<rules>
- Always spawn agents with model "haiku" — auditing is read-only diagnostic work, cheapest tier
- Audit agents are READ-ONLY — they must never modify source code or task files
- Fixer agents can modify task files in todo/ and doing/ but never source code or done/ tasks
- The .audit/ directory is ephemeral — overwritten on each audit run
- If no tasks exist in the backlog, report that and suggest running /create-tasks
- Focus mode spawns only the requested agent — don't run all 3 if user asked for one
</rules>
