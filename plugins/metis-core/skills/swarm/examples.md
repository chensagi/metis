# Swarm — Example Session

```
User: /swarm

Claude: Starting swarm execution...

Bootstrapping .metis/ directory...
  Detected: tsconfig.json → TypeScript project
  Created .metis/config.json with verify_command: "npx tsc --noEmit"

Moving task files to doing/:
- .metis/tasks/todo/12-api-auth-middleware.md → .metis/tasks/doing/
- .metis/tasks/todo/13-user-profile-endpoint.md → .metis/tasks/doing/

Spawning agents for ready tasks:
- Task 12: API Auth Middleware → Agent started (2 work items)
- Task 13: User Profile Endpoint → Agent started (1 work item)

Tracking 3 agents (4 max). Use `/swarm status` to check progress.

[Later... agents complete]

User: /swarm

Claude: Running audit...

Task 13 completed!
  .metis/tasks/doing/13-*.md → .metis/tasks/done/
  Committed: "Task 13: User Profile Endpoint — complete"

Task 12 needs review (2 compilation errors)
  Task file stays in .metis/tasks/doing/

Spawning fix agent + new tasks:
- Fix Task 12: API Auth Middleware → Haiku diagnosing...
  Diagnosis complete: 2 missing imports in authMiddleware.ts
  Spawning Sonnet fix agent...
- Task 14: Rate Limiting → moved to doing/, Agent started

[Fix agent completes...]

User: /swarm

Claude:
Task 12 fixes verified — compiles clean!
  .metis/tasks/doing/12-*.md → .metis/tasks/done/
  Committed: "Task 12: API Auth Middleware — complete"

Spawning agents for ready tasks:
- Task 15: Database Migrations → moved to doing/, Agent started
- Task 16: Error Handling → moved to doing/, Agent started

[Later, all agents complete...]

User: /swarm integrate

Claude:
Starting integration verification...
3 tasks completed, committing each:
  "Task 14: Rate Limiting — complete"
  "Task 15: Database Migrations — complete"
  "Task 16: Error Handling — complete"

Spawning Integration Agent (Haiku diagnostics)...

[Integration completes...]

Claude:
Integration Verification Complete!

### PASSED (4)
- Module imports: all cross-module imports resolve correctly
- Type consistency: shared interfaces used consistently
- API routes: all new endpoints registered in router
- Compilation clean: zero errors

All integration checks passed!
```

## Budget Example

```
User: /swarm --budget 5

Claude:
Starting swarm with $5.00 budget...

> Budget is estimated — Claude Code does not expose actual cost to skills.
> Use /cost after the session to see actual spend.

[After 3 iterations...]

BUDGET: ~$4.20 / $5.00 estimated (84%)
Remaining budget too low for another work item agent ($0.50).
Letting 1 running agent finish, then stopping.

[Agent completes...]

Budget exhausted. 4 tasks completed this session.
Use /swarm to continue in a new session.
```

## Controlled Mode Example

```
User: /swarm --controlled

Claude:
PROPOSAL: Pick up Task 20 (Search Indexing)
─────────────────────────────────────────────
Complexity: Medium | Files: ~4 | Est. cost: ~$1.00

Work items:
  1. Types + index config (src/types/search.ts, src/config/search.ts)
  2. Indexing service (src/services/searchIndexer.ts)

Approve / Skip / Modify?

User: Approve

Claude: Spawning 2 agents...
[Agents complete]

VERDICT: Task 20 — verify_command passed, 4 files created
Accept as done / Send to fix / Reject?

User: Accept

Claude:
  .metis/tasks/doing/20-*.md → .metis/tasks/done/
  Committed: "Task 20: Search Indexing — complete"
```
