# Fix Flow (for incomplete tasks) — Two-Phase

When a task is in `needs_review`, the orchestrator (you) drives the fix. Subagents can't spawn subagents, so YOU do the analysis and decomposition.

## Phase 1: Diagnose

Spawn a cheap Haiku agent to collect current errors. Read `.metis/config.json` for `verify_command`.

<agent-prompt>
Task({
  description: "Diagnose Task ${num}: ${name}",
  prompt: `You are a diagnostic agent. Your job is to run checks and produce a structured report. Do NOT fix anything — only report.

Read the project's CLAUDE.md (if it exists) for codebase conventions.

Run these checks:
1. Compilation/Type Check: Run ${verify_command} 2>&1 and capture ALL errors
2. Import Verification: Grep for broken imports (importing from paths that don't exist)
3. Export Check: Verify any new modules are properly exported

Files to check: ${files_affected.join(', ')}
Known issues from previous run: ${notes}

Output format:
## Compilation Errors
[List each error with file:line and the error message]
## Missing Exports
[List any modules missing exports]
## Broken Imports
[List any imports pointing to non-existent files]
## Summary
- Total errors: N
- Files affected: [list]`,
  subagent_type: "Explore",
  model: "haiku",
  run_in_background: true,
  max_turns: 10
})
</agent-prompt>

## Phase 2: Decompose & Fix

When the diagnostics agent returns:

1. Read its report (the output_file)
2. YOU (Opus) analyze the errors, understand root causes, and group them into fix work items
3. Spawn worker agents for each fix work item:

<agent-prompt>
Task({
  description: "Fix Task ${num}: ${name} — ${fixDescription}",
  prompt: `You are a task-filler agent. Fix the specific errors described below.

Read the project's CLAUDE.md (if it exists) for codebase conventions.

Rules:
- Stay focused on YOUR fix scope — don't touch files outside your scope
- Follow existing code patterns in the codebase
- You MUST end with ${verify_command} returning ZERO errors. This is a hard gate — do not finish with errors
- Your FINAL message must be a single short line: "Done: [N files fixed]" or "Error: [brief description]". No summary, no explanation

Fix work item for Task ${num} (${name}).

Task file: .metis/tasks/doing/${filename}

## Errors to fix
${specificErrorsForThisWorkItem}

## Files to modify
${specificFilesToFix}

## What the correct behavior should be
${whatTheCodeShouldDo}`,
  subagent_type: "general-purpose",
  model: "sonnet",
  run_in_background: true,
  max_turns: 30
})
</agent-prompt>
