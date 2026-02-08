---
name: task
description: Pick up and complete a task from the backlog, ask clarifying questions, implement, verify, and ship
argument-hint: [task-number] [--super-ask] (optional - super-ask mode asks thorough questions)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, TaskOutput, WebSearch, WebFetch
---

# Task Workflow

You are executing the `/task` command. Follow this workflow carefully.

## Bootstrap

Before starting, ensure `.metis/` exists with a valid config:

1. **If `.metis/config.json` exists** → Read it, load capabilities from `.metis/capabilities/`, proceed
2. **If `.metis/` doesn't exist** → Tell the user to run `/install` first for full interactive setup. If they want to proceed immediately, do a minimal bootstrap:
   - `mkdir -p .metis/capabilities .metis/skills .metis/tasks/todo .metis/tasks/doing .metis/tasks/done`
   - Create `.metis/.gitignore` (hybrid tracking)
   - Auto-detect project type and create minimal `.metis/config.json`

Read `.metis/capabilities/manifest.json` (if exists) and load capability instructions — these inform how you implement during Step 5.

## Mode Detection

Check `$ARGUMENTS` for `--super-ask` flag. Also check `.metis/config.json` for `"ask_mode"`:
- `--super-ask` flag present → Super Ask ON
- `config.json` has `"ask_mode": "super-ask"` and no `--quick` flag → Super Ask ON
- Otherwise → Normal Mode (current behavior, but with improved answer quality)

Strip `--super-ask` and `--quick` from arguments before passing to Step 1.

## Step 1: Select the Task

**If an argument was provided** (`$ARGUMENTS`):
- Find the task file in `.metis/tasks/todo/` that matches the number (e.g., argument "01" matches "01-fix-auth.md")
- Read that specific task file

**If no argument was provided**:
- List all files in `.metis/tasks/todo/`
- Pick the **lowest-numbered file** (highest priority)
- Read that task file

## Step 2: Understand and Clarify

After reading the task file, **summarize** the task briefly to confirm understanding. Then branch based on mode:

### Normal Mode

1. **Identify any ambiguities** or decisions that need user input:
   - Implementation approach choices
   - Edge cases not covered in requirements
   - Technical decisions with trade-offs
   - Anything unclear in the spec
2. **Ask the user** using AskUserQuestion with **well-reasoned options** — each option should have a detailed `description` field explaining trade-offs and implications. Don't offer vague one-word choices; offer 2-3 specific approaches with pros/cons for each
   - If nothing is ambiguous and the task is crystal clear, skip this step
   - Group related questions together

### Super Ask Mode — Requirements Interview

Super Ask ensures thorough understanding before spending implementation tokens. Work through these categories across 2-4 AskUserQuestion rounds. Skip categories that truly don't apply to this task, but err on the side of asking.

**Round 1 — Requirements & Scope**
- What is the precise expected behavior? (ask about specific inputs → outputs)
- What is explicitly OUT of scope for this task?
- What's the minimum viable version vs the complete version?
- Are there existing patterns in the codebase this should follow?

**Round 2 — Edge Cases & Error Handling**
- What happens on failure? (network errors, invalid input, empty state, timeouts)
- Are there concurrency or race condition concerns?
- How should errors be communicated to the user?
- What's the fallback behavior if a dependency is unavailable?

**Round 3 — Integration & Architecture**
- Which existing modules does this touch? Any shared state?
- Are there performance constraints or scale expectations?
- Does this need backward compatibility with existing APIs/data?
- Should this be behind a feature flag or configuration option?

**Round 4 — Testing & Acceptance** (if relevant)
- What does "done" look like — specific acceptance criteria?
- What test types are needed? (unit, integration, E2E)
- Are there specific test scenarios beyond happy path?
- How will this be verified manually?

After each round, incorporate answers into your understanding. Later rounds can reference earlier answers. If a round reveals new questions, ask them.

Record all answers in a structured format — they feed directly into the plan (Step 3d).

## Step 3: Plan the Implementation

**Before picking up the task, plan the approach.** This prevents wasted tokens on wrong approaches.

### 3a: Explore the Codebase

Explore cheaply — use grep, glob, and file reads (no agents needed):

1. Find related files — glob for similar components, modules, or patterns
2. Read neighboring code to understand the existing architecture around the task's target area
3. Identify existing utilities, helpers, and patterns to reuse
4. Check for potential conflicts with other code

### 3b: Research

After codebase exploration, consider if web research would improve the plan:

1. **Unfamiliar APIs** → WebSearch for current documentation and usage examples
2. **Complex patterns** → search for best practices and proven approaches
3. **Dependency concerns** → search for known issues with specific versions
4. **Alternative approaches** → search for how others solved similar problems

Use WebSearch for discovery, WebFetch to read specific documentation pages.
If nothing needs researching, skip this step — don't research for the sake of it.

### 3c: Design the Approach

Based on your exploration and research, design the implementation:

1. List the files to create or modify
2. Describe the approach for each file
3. Note which existing patterns to follow
4. Identify which capabilities are relevant to this task (capability subsetting — only these will be injected into agent prompts)
5. Estimate complexity (low/medium/high)

### 3d: Present the Plan

**Normal Mode** — present the implementation plan:

```
IMPLEMENTATION PLAN — Task XX: Title
═══════════════════════════════════════════════════

Approach: [Brief description]

Files to modify:
  - path/to/file.ts — [what changes]
  - path/to/new-file.ts — [what it does]

Patterns to follow:
  - [existing pattern from codebase]

Relevant capabilities: [typescript, react-native, ...]

Complexity: Medium
═══════════════════════════════════════════════════
```

**Super Ask Mode** — expanded format incorporating interview answers:

```
IMPLEMENTATION PLAN — Task XX: Title (Super Ask)
═══════════════════════════════════════════════════

Scope:
  IN:  [what's included, from Round 1 answers]
  OUT: [what's explicitly excluded]

Approach: [Brief description]

Files to modify:
  - path/to/file.ts — [what changes]

Edge Case Handling:
  - [failure scenario] → [strategy, from Round 2 answers]

Architecture Notes:
  - [integration points, patterns to follow, from Round 3]

Test Plan:
  - [specific test cases, from Round 4 answers]

Relevant capabilities: [typescript, react-native, ...]
Complexity: Medium
═══════════════════════════════════════════════════
```

Wait for user approval before proceeding. If the user suggests changes, adjust the plan.

## Step 4: Pick Up the Task

Once the plan is approved:

1. Move the file: `git mv .metis/tasks/todo/<filename> .metis/tasks/doing/<filename>`
2. Update the `Status:` field in the file to `in-progress`
3. Commit: `git commit -m "Start: <task title>"`

## Step 5: Implement

Do the implementation work:

1. Read the project's `CLAUDE.md` (if it exists) for codebase conventions
2. Follow the capability instructions loaded during bootstrap — but only inject **relevant capabilities** identified in the plan (capability subsetting). Skip capabilities that don't apply to the files being modified
3. Follow the requirements and acceptance criteria exactly
4. Use the technical details provided as guidance
5. Apply any decisions from the clarifying questions and the approved plan
6. Add a `## Log` section at the bottom of the task file with important decisions made

## Step 6: Verify

Run verification using `.metis/config.json` commands:

1. **Verify command** (if configured): Run `verify_command` and ensure zero errors
2. **Test command** (if configured): Run `test_command` — find and run matching tests for changed modules
3. **Lint command** (if configured): Run `lint_command` on changed files
4. Fix any errors before proceeding — do not move forward with failing checks

If no commands are configured, warn the user that verification was skipped.

### Debugging (when errors occur)

**80% — Web search solves it:**
1. Take the exact error message from verify/test/lint output
2. WebSearch: `"{error message}" {library} {version}`
3. Check the results — Stack Overflow, GitHub issues, library docs
4. Apply the fix and re-verify

**20% — Deep evidence collection:**
When web search doesn't solve it:
1. Collect the full error with stack trace
2. Identify the exact file and line
3. Read surrounding code and its dependencies
4. Check recent changes: `git diff` and `git log` for the affected files
5. Search the codebase for the same error pattern (is it elsewhere?)
6. Present all evidence structured to the user — let them decide the next step

## Step 7: Complete the Task

After implementation and verification pass:

1. Move the file: `git mv .metis/tasks/doing/<filename> .metis/tasks/done/<filename>`
2. Update the `Status:` field to `done`
3. Add a `## Completed` section with:
   - Date completed
   - Summary of what was shipped
   - Files changed
   - Any follow-up items
4. Commit: `git commit -m "Done: <task title>"`

## Step 8: Ship It

Use the `/ship` skill to:
- Create a Pull Request
- Wait for CI checks
- Merge to main

---

**IMPORTANT REMINDERS:**
- Never delete task files
- Never modify the original spec (Summary, Requirements, Acceptance Criteria)
- Only append to Log/Completed sections
- Fix ALL verification issues before shipping
