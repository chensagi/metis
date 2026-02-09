---
name: create-tasks
description: Thorough multi-round interview to understand what the user wants to build, then explore the codebase and generate well-structured tasks for the backlog
argument-hint: ["feature description"] (optional - brief description of what to build)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Create Tasks — Interview-Driven Task Generation

You are executing the `/create-tasks` command. This skill conducts a thorough interview to understand what the user wants to build, explores the codebase for context, then generates a complete set of well-structured tasks in `.metis/tasks/todo/`.

## Bootstrap

1. **If `.metis/config.json` exists** → Read it, load capabilities from `.metis/capabilities/`, proceed
2. **If `.metis/` doesn't exist** → Tell the user to run `/install` first

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

Use AskUserQuestion:
- **Approve** — Write all task files
- **Adjust** — Let me modify specific tasks before writing
- **Redo** — Start over with different decomposition

## Step 7: Write Task Files

Once approved, write all task files to `.metis/tasks/todo/`:

1. For each task, create `.metis/tasks/todo/XX-{slug}.md`
2. Use the full task file format with all sections populated
3. Include dependency notes in Technical Details where applicable

## Step 8: Report

```
TASKS CREATED
═══════════════════════════════════════════════════

Created {N} tasks in .metis/tasks/todo/:

  {XX}-{slug}.md  — {title}
  {XX}-{slug}.md  — {title}
  ...

What to do next:
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
</rules>
