---
name: task
description: Pick up and complete a task from the backlog, ask clarifying questions, implement, verify, and ship
argument-hint: [task-number]
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

Read `.metis/capabilities/manifest.json` (if exists) and load capability instructions — these inform how you implement during Step 4.

## Step 1: Select the Task

**If an argument was provided** (`$ARGUMENTS`):
- Find the task file in `.metis/tasks/todo/` that matches the number (e.g., argument "01" matches "01-fix-auth.md")
- Read that specific task file

**If no argument was provided**:
- List all files in `.metis/tasks/todo/`
- Pick the **lowest-numbered file** (highest priority)
- Read that task file

## Step 2: Understand and Clarify

After reading the task file:

1. **Summarize** the task briefly to confirm understanding
2. **Identify any ambiguities** or decisions that need user input:
   - Implementation approach choices
   - Edge cases not covered in requirements
   - Technical decisions with trade-offs
   - Anything unclear in the spec
3. **Ask the user** all clarifying questions using the AskUserQuestion tool
   - If nothing is ambiguous and the task is crystal clear, skip this step
   - Group related questions together

## Step 3: Pick Up the Task

Once you have all the answers you need:

1. Move the file: `git mv .metis/tasks/todo/<filename> .metis/tasks/doing/<filename>`
2. Update the `Status:` field in the file to `in-progress`
3. Commit: `git commit -m "Start: <task title>"`

## Step 4: Implement

Do the implementation work:

1. Read the project's `CLAUDE.md` (if it exists) for codebase conventions
2. Follow the capability instructions loaded during bootstrap (e.g., TypeScript patterns, React Native conventions, Zustand store patterns — whatever is installed in `.metis/capabilities/`)
3. Follow the requirements and acceptance criteria exactly
4. Use the technical details provided as guidance
5. Apply any decisions from the clarifying questions
6. Add a `## Log` section at the bottom of the task file with important decisions made

## Step 5: Verify

Run verification using `.metis/config.json` commands:

1. **Verify command** (if configured): Run `verify_command` and ensure zero errors
2. **Test command** (if configured): Run `test_command` — find and run matching tests for changed modules
3. **Lint command** (if configured): Run `lint_command` on changed files
4. Fix any errors before proceeding — do not move forward with failing checks

If no commands are configured, warn the user that verification was skipped.

## Step 6: Complete the Task

After implementation and verification pass:

1. Move the file: `git mv .metis/tasks/doing/<filename> .metis/tasks/done/<filename>`
2. Update the `Status:` field to `done`
3. Add a `## Completed` section with:
   - Date completed
   - Summary of what was shipped
   - Files changed
   - Any follow-up items
4. Commit: `git commit -m "Done: <task title>"`

## Step 7: Ship It

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
