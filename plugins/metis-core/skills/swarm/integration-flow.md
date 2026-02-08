# Integration Flow — Two-Phase

After tasks complete, the orchestrator drives integration. Same pattern as fix flow: diagnose first, then decompose fixes. Read `.metis/config.json` for `verify_command`.

## Phase 1: Diagnose

Spawn a cheap Haiku agent to run all checks:

<agent-prompt>
Task({
  description: "Integration check: ${taskList}",
  prompt: `You are a diagnostic agent. Your job is to run checks and produce a structured report. Do NOT fix anything — only report.

Read the project's CLAUDE.md (if it exists) for codebase conventions.

Run these checks:
1. Compilation/Type Check: Run ${verify_command} 2>&1 and capture ALL errors
2. Import Verification: Grep for broken imports (importing from paths that don't exist)
3. Cross-Module Consistency: Check that modules used by consumers match their actual exports

Check these recently completed tasks:
${completedTasks.map(t => '- Task ' + t.task_id + ': ' + t.task_name).join('\\n')}

Also read the integration-checklist.md file (in the same directory as this skill) for the full checklist.

Output format:
## Compilation Errors
[List each error with file:line and the error message]
## Missing Exports
[List any modules missing exports]
## Cross-Module Integration Issues
[List any issues where modules don't wire together correctly]
## Summary
- Total errors: N
- Files affected: [list]
- Modules affected: [list]`,
  subagent_type: "Explore",
  model: "haiku",
  run_in_background: true,
  max_turns: 15
})
</agent-prompt>

## Phase 2: Analyze & Fix

When the diagnostics agent returns:

1. Read its report
2. If all clean → mark integration as passed, done
3. If issues found → YOU (Opus) understand the root causes across modules, decompose into targeted fix work items
4. Spawn task-worker agents for each fix, same as the [fix flow](fix-flow.md)
5. After fix agents complete, run Phase 1 again to verify

See also: [integration-checklist.md](integration-checklist.md) for the full verification checklist used by the diagnostics agent.
