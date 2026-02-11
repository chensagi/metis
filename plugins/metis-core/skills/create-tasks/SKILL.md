---
name: create-tasks
description: Thorough multi-round interview to understand what the user wants to build, then explore the codebase and generate well-structured tasks for the backlog
argument-hint: ["feature description"] (optional - brief description of what to build)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Create Tasks — Interview-Driven Task Generation

You are executing the `/create-tasks` command. This skill conducts a thorough interview to understand what the user wants to build, explores the codebase for context, then generates a complete set of well-structured tasks in `.metis/tasks/todo/`.

## Bootstrap

<rules>
BEFORE DOING ANYTHING ELSE, check if `.metis/config.json` exists:
- **If it exists** → Read it, load capabilities from `.metis/capabilities/`, proceed to Step 1
- **If `.metis/` does not exist** → STOP. Tell the user: "Run `/install` first to set up Metis for this project." Do NOT proceed. Do NOT fall back to any other directory structure. Do NOT attempt to work without `.metis/`. This is a hard requirement — the skill cannot function without it.
</rules>

Read `.metis/capabilities/manifest.json` (if exists) and load capability instructions — these inform how you decompose work and write technical details.

## Step 1: Understand the Goal

**If arguments provided** (`$ARGUMENTS`):
- Use the description as a starting point for the interview
- Summarize your initial understanding before proceeding to questions

**If no arguments**:
- Ask the user: "What do you want to build or accomplish?"

## Step 2: Super-Ask Interview

Conduct a thorough multi-round interview to deeply understand what needs to be built. Work through these categories across 2-4 AskUserQuestion rounds. Skip categories that truly don't apply, but err on the side of asking.

**Round 1 — Vision & Scope**
- What is the high-level goal? What problem does this solve?
- What does the end result look like from the user's perspective?
- What is explicitly OUT of scope?
- What's the minimum viable version vs the full vision?
- Is there a deadline or priority order?

**Round 2 — Features & Requirements**
- Break down the goal into specific features or user stories
- For each feature: what is the expected behavior? (inputs → outputs)
- Are there existing patterns in the codebase this should follow?
- Are there dependencies between features? (what must come first?)

**Round 3 — Technical & Architecture**
- Which parts of the codebase does this touch?
- Are there new libraries or tools needed?
- Are there performance, security, or compatibility concerns?
- Should any of this be behind feature flags?

**Round 4 — Testing & Definition of Done** (if relevant)
- What does "done" look like for each feature?
- What test types are needed? (unit, integration, E2E)
- How will this be verified manually?
- Are there specific edge cases to cover?

After each round, summarize your understanding back to the user. Later rounds should reference earlier answers. If a round reveals new questions, ask them.

## Step 3: Explore the Codebase

Before generating tasks, explore cheaply to ground the tasks in reality:

1. Glob for files and directories related to the features discussed
2. Grep for existing patterns, utilities, and components that can be reused
3. Read key files to understand the current architecture around the affected areas
4. Identify existing conventions (naming, file structure, test patterns)

Use this exploration to write accurate Technical Details in each task.

## Step 4: Research (if needed)

If the interview revealed unfamiliar technologies, libraries, or patterns:

1. WebSearch for current best practices and documentation
2. WebFetch to read specific API docs or guides
3. Incorporate findings into task technical details

Skip this step if everything discussed uses familiar, well-understood technology.

## Step 5: Decompose into Tasks

Based on the interview answers and codebase exploration, decompose the work into discrete, well-scoped tasks. Each task should be:

- **Independent** — can be worked on without completing other tasks first (unless explicitly blocked)
- **Focused** — targets a specific deliverable, not a vague goal
- **Testable** — has clear acceptance criteria
- **Right-sized** — not so big it needs further decomposition, not so small it's trivial

At this stage, produce titles, one-line summaries, priority, complexity, and dependencies for the overview table. Full details (Technical Details, Acceptance Criteria, problem/solution analysis) are fleshed out during the per-task discussion in Step 7 — don't over-invest in details before the user has a chance to reshape tasks.

### Task Ordering

Number tasks in recommended execution order:
- Foundation/infrastructure first
- Core features in dependency order
- UI/polish tasks after core logic
- Testing/verification last

### Task File Format

For each task, create a file in `.metis/tasks/todo/` following this format:

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

{Implementation guidance based on codebase exploration:
- Relevant files to modify or create
- Existing patterns to follow
- Specific approach suggestions
- Libraries or tools to use}
```

### Auto-Numbering

Find the highest task number across all directories (todo, doing, done) and increment by 1 for the first task. Number subsequent tasks sequentially.

## Step 6: Present the Plan

Before writing any files, present the complete task breakdown to the user:

```
TASK PLAN
═══════════════════════════════════════════════════

Based on our discussion, here's the task breakdown:

  01: {title}  [priority] [complexity]
      {one-line summary}

  02: {title}  [priority] [complexity]
      {one-line summary}
      Depends on: Task 01

  03: {title}  [priority] [complexity]
      {one-line summary}

  ...

Total: {N} tasks
Dependencies: {dependency chain summary}

═══════════════════════════════════════════════════
```

Use AskUserQuestion to ask what the user wants to do next:
- **All look good — write them** — Skip Step 7 entirely and go straight to Step 8 (write files)
- **Deep-dive into specific tasks** — User specifies which task numbers to discuss (via the "Other" free-text option or by naming them). Only those tasks enter the per-task discussion in Step 7. All other tasks are auto-approved as shown above.
- **Redo the whole plan** — Start over with different decomposition

## Step 7: Per-Task Discussion

**Only for tasks the user selected for deep-dive.** For each selected task, in order:

### 1. Present the task in detail

Show the user:
- **The problem / root cause** — what's wrong today or what's missing
- **Proposed solution** — specific approach, not just "fix it"
- **Files touched** — specific paths from codebase exploration
- **Risks or dependencies** — what could go wrong, what this depends on

### 2. Have a real conversation

This is a genuine discussion, not a formality:
- Answer the user's questions about the task
- If the user reveals new context that changes the task scope, **adapt the task** — update the problem statement, solution, files, and risks accordingly
- Multiple conversation rounds per task are expected and fine
- Don't rush to the approval prompt — let the discussion converge naturally

### 3. When the discussion converges, ask for a decision

Use AskUserQuestion with these options:
- **Looks good, next task** — approve the task (as discussed) and move on
- **Too risky, skip it** — remove this task from the plan entirely
- **Split it smaller** — break this task into sub-tasks and discuss those individually
- **Chat about this** — continue the conversation on this task (loop back to step 2)

### 4. Move to the next selected task

Repeat until all selected tasks have been reviewed. Then proceed to Step 8.

## Step 8: Write Task Files

After all deep-dive discussions are complete, present the final approved task list (deep-dived tasks as modified + auto-approved tasks unchanged, minus any skipped tasks).

Write all task files to `.metis/tasks/todo/`:

1. For each approved task, create `.metis/tasks/todo/XX-{slug}.md`
2. Use the full task file format with all sections populated
3. Include dependency notes in Technical Details where applicable
4. Deep-dived tasks should reflect any changes from the discussion — not the original decomposition

## Step 9: Report

```
TASKS CREATED
═══════════════════════════════════════════════════

Created {N} tasks in .metis/tasks/todo/:

  {XX}-{slug}.md  — {title}
  {XX}-{slug}.md  — {title}
  ...

What to do next:
  /clear            — Start a fresh conversation (recommended — this one has heavy context)
  /triage           — Review and prioritize the backlog
  /task             — Pick up the first task
  /swarm            — Run multiple tasks in parallel

═══════════════════════════════════════════════════
```

## Rules

<rules>
- ALWAYS conduct the interview before generating tasks — never skip to task creation
- ALWAYS explore the codebase before writing Technical Details — tasks must reference real files and patterns
- ALWAYS present the plan and get approval before writing files
- Task files go in .metis/tasks/todo/ — never in doing/ or done/
- Each task must have all sections: Summary, Requirements, Acceptance Criteria, Technical Details
- Technical Details must reference specific files, functions, and patterns from the codebase — no generic advice
- Don't create tasks that duplicate what already exists in the backlog — check existing tasks first
- If the user's request maps to a single task, that's fine — don't force decomposition into multiple tasks
- Never modify existing task files — only create new ones
- ALWAYS walk through each selected task individually with the user before writing files — present the detailed analysis, have a real conversation, and get per-task approval
- During per-task discussion, if the user provides new context that changes the task scope, adapt the task accordingly — don't stick to the original decomposition rigidly
</rules>
