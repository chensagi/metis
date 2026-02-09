---
name: task
description: Pick up and complete a task from the backlog, ask clarifying questions, implement, verify, and ship
argument-hint: [task-number] [--super-ask] (optional - super-ask mode asks thorough questions)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, TaskOutput, WebSearch, WebFetch
---

# Task Workflow

You are executing the `/task` command. Follow this workflow carefully.

## Bootstrap

<rules>
BEFORE DOING ANYTHING ELSE, check if `.metis/config.json` exists:
- **If it exists** → Read it, load capabilities from `.metis/capabilities/`, proceed
- **If `.metis/` does not exist** → STOP. Tell the user: "Run `/install` first to set up Metis for this project." Do NOT proceed. Do NOT fall back to any other directory structure. Do NOT attempt to work without `.metis/`. This is a hard requirement — the skill cannot function without it.
</rules>

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

The plan must be detailed enough for a Sonnet agent to implement without architectural thinking. Opus does MORE thinking upfront so Sonnet does LESS during implementation.

**Normal Mode** — present the implementation plan:

```
IMPLEMENTATION PLAN — Task XX: Title
═══════════════════════════════════════════════════

Approach: [Brief description]

Files to create/modify:
  - path/to/file.ts — [what changes]
    - function signatures: [exact function names, params, return types]
    - key logic: [what the implementation does, step by step]
  - path/to/new-file.ts — [what it does]
    - exports: [exact exports with types]

Wiring (existing files to update):
  - path/to/router.ts — register new route handler
  - path/to/index.ts — export new module

Patterns to follow:
  - [existing pattern from codebase — reference specific files]

Research hints:
  - [API docs to look up, library patterns to search for]

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

Files to create/modify:
  - path/to/file.ts — [what changes]
    - function signatures: [exact function names, params, return types]
    - key logic: [what the implementation does, step by step]

Wiring (existing files to update):
  - path/to/router.ts — register new route handler
  - path/to/index.ts — export new module

Edge Case Handling:
  - [failure scenario] → [strategy, from Round 2 answers]

Architecture Notes:
  - [integration points, patterns to follow — reference specific files, from Round 3]

Test Plan:
  - [specific test cases, from Round 4 answers]

Research hints:
  - [API docs to look up, library patterns to search for]

Relevant capabilities: [typescript, react-native, ...]
Complexity: Medium
═══════════════════════════════════════════════════
```

**What the plan MUST include** (both modes):
- Exact file paths to create or modify
- Function signatures and types (copy from codebase exploration in Step 3a)
- Which capability instructions apply (for capability subsetting in Step 5)
- Research hints for unfamiliar APIs or patterns
- Explicit implementation details per file — not just "add auth" but "add middleware function that checks JWT token from Authorization header, returns 401 if invalid"
- Wiring — which existing files to update for imports, route registration, barrel exports, navigation config, etc.

Wait for user approval before proceeding. If the user suggests changes, adjust the plan.

## Step 4: Pick Up the Task

Once the plan is approved:

1. Move the file: `git mv .metis/tasks/todo/<filename> .metis/tasks/doing/<filename>`
2. Update the `Status:` field in the file to `in-progress`
3. Commit: `git commit -m "Start: <task title>"`

## Step 5: Implement (Sonnet Delegation)

Opus has done the smart work (interview, explore, plan). Now delegate the "dumb work" — code writing — to a cheaper Sonnet agent.

### 5a: Build the Agent Prompt

Construct a focused prompt for the Sonnet agent using the approved plan from Step 3d:

1. **Plan** — the approved implementation plan (exact files, types, approach, implementation details per file)
2. **Capability instructions** — read only the relevant capabilities identified in the plan (capability subsetting). Extract the `## Agent Instructions` section from each
3. **Research hints** — from the plan (Step 3d) and any findings from Step 3b
4. **CLAUDE.md** — read the project's `CLAUDE.md` (if it exists) for codebase conventions
5. **Task file** — the full task spec from `.metis/tasks/doing/`
6. **verify_command** — from `.metis/config.json` (may be null)

### 5b: Spawn Sonnet Agent (foreground, blocking)

<agent-prompt>
Task({
  description: "Implement task ${num}: ${name}",
  prompt: `You are a task-filler agent. Implement the following plan exactly as specified.

## Project Conventions
${claudeMdContents}

## Capability Instructions (relevant subset)
${relevantCapabilityInstructions}

## Research Hints
${researchHints}

When you encounter errors or unfamiliar APIs, use WebSearch to find solutions.
Use WebFetch to read specific documentation pages.

## Implementation Plan
${approvedPlanFromStep3d}

## Task Spec
${taskFileContents}

## Rules
- Implement ALL files listed in the plan — do not skip any
- Follow existing code patterns — read neighboring files to match style
- Wire your code into the project — don't just create files. Update existing files to import, register, and connect your new modules (barrel exports, route registration, navigation config, app initialization). The plan's "Wiring" section specifies exactly what to update
- Use exact types and interfaces from the plan
- Be concise — don't explain what you're doing, just do it. Minimize reasoning output
- Do NOT repeat the plan or requirements back. Just implement
- ${verify_command ? 'End with ' + verify_command + ' returning ZERO errors. If there are errors, fix them before finishing' : 'No verify command configured — review your changes manually before finishing'}
- When you encounter errors, use WebSearch to find solutions
- Add a ## Log section at the bottom of the task file with important decisions made`,
  subagent_type: "general-purpose",
  model: "sonnet",
  run_in_background: false,
  max_turns: 30
})
</agent-prompt>

### 5c: Complex Tasks (4+ files)

If the approved plan targets 4 or more files, decompose into 2-3 sequential work items before spawning:

1. **Types/interfaces first** — shared definitions that other files depend on
2. **Core logic** — business logic, services, utilities
3. **Integration/wiring** — routing, config, exports, tests

Spawn each work item as a separate Sonnet agent (foreground, sequential — not parallel, since `/task` is interactive). Each agent gets only the relevant subset of the plan.

> **Why sequential, not parallel?** `/task` is interactive and single-task. Parallel spawns would dump multiple result payloads into context at once. Sequential keeps context clean and lets each agent build on the previous one's output.

## Step 6: Verify (L0 runs directly)

After the Sonnet agent completes, L0 runs verification directly — no agent spawn needed.

### 6a: Run Verification Commands

Run each configured command from `.metis/config.json`, truncating output:

1. **Verify command** (if configured): `${verify_command} 2>&1 | head -30` — zero errors required
2. **Test command** (if configured): `${test_command} 2>&1 | head -30` — find and run matching tests
3. **Lint command** (if configured): `${lint_command} 2>&1 | head -30` — check changed files
4. **Spot-check**: Glob for key files listed in the plan to confirm they exist
5. **Wiring scan**: For each new file created, grep to check it's imported somewhere in the project. If new files exist but aren't imported anywhere (excluding test files and entry points), warn: "Potential wiring issue — [file] is not imported anywhere." The Sonnet fix agent (Step 6b) should wire it if the warning is legitimate

If no commands are configured, warn the user: "No verify/test/lint commands configured in .metis/config.json — verification skipped. Run `/install --update` to configure." Proceed only after the user acknowledges.

If all checks pass (including wiring scan) → proceed to Step 7.

### 6b: Fix Errors (Sonnet fix agent)

If verification fails, do NOT fix code directly as Opus. Spawn a Sonnet fix agent:

1. Capture the error output (already truncated to 30 lines from 6a)
2. Identify which files have errors
3. Spawn a Sonnet fix agent:

<agent-prompt>
Task({
  description: "Fix errors in task ${num}: ${name}",
  prompt: `You are a fix agent. The implementation has verification errors. Fix them.

## Errors
${errorOutput}

## Files with errors
${affectedFiles}

## Research Hints
- Search for: "${exactErrorMessage}" ${library} ${version}
- Check: ${relevantDocs}

## Rules
- Fix ONLY the errors listed above — do not refactor or change unrelated code
- Use WebSearch to find solutions for error messages
- Be concise — just fix the code, don't explain
- ${verify_command ? 'End with ' + verify_command + ' returning ZERO errors' : 'Review your changes manually'}`,
  subagent_type: "general-purpose",
  model: "sonnet",
  run_in_background: false,
  max_turns: 15
})
</agent-prompt>

4. After the fix agent completes, re-run verification (Step 6a)
5. If the fix agent fails too → **the 20% case**: present all evidence structured to the user:
   - Full error with stack trace
   - Affected files and lines
   - What the fix agent tried
   - Recent git changes (`git diff`)
   - Let the user decide the next step

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

After shipping, suggest `/clear` to start a fresh conversation for the next task.

<rules>
- NEVER delete task files
- NEVER modify the original spec (Summary, Requirements, Acceptance Criteria) — only append to Log/Completed sections
- Fix ALL verification issues before shipping — do not proceed to Step 7 with failing checks
- ALWAYS run Bootstrap first regardless of which step the user starts at
</rules>
