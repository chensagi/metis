# Test Swarm (`/swarm test`)

Run a **test swarm** — a small parallel swarm that verifies current changes using static checks and tests. Spawns up to 3 test agents that each validate a different aspect of the codebase. Read `.metis/config.json` for project-specific commands.

**Architecture note:** Haiku agents (Layer 2 — leaves) execute commands and report raw output. The orchestrator (you, Opus — Layer 1 spine) synthesizes results, correlates failures across agents, and identifies root causes. Agents report what happened; you figure out what it means.

Can target specific scope: `/swarm test 26` (test task 26's files), `/swarm test src/services/` (test a directory).

## Action

1. Read `.metis/config.json` for `verify_command`, `lint_command`, and `test_command`
2. Detect changed files (`git diff --name-only HEAD` + staged)
3. Spawn test agents in parallel (see agent table below)
4. Wait for all to complete — read raw results from each agent
5. **Synthesize results (Opus):** Correlate failures across agents, identify root causes, prioritize by impact
6. Present unified report with root cause analysis (see "Result Synthesis" below)

## Test Agents

| Agent | Model | What it does | When spawned |
|-------|-------|-------------|--------------|
| **Compile/Type Check** | Haiku | Run `verify_command`, report errors | When `verify_command` is configured |
| **Lint** | Haiku | Run `lint_command` on changed files | When `lint_command` is configured and source files changed |
| **Unit Tests** | Haiku | Find and run matching tests | When `test_command` is configured and test files exist for changed modules |

## Agent Prompts

### Agent 1: Compile/Type Check (Haiku, max_turns: 5)

<agent-prompt>
Run ${verify_command} 2>&1 and report:
- Status: PASS or FAIL
- Error count and details (file:line + message, max 20)
</agent-prompt>

### Agent 2: Lint Check (Haiku, max_turns: 5)

<agent-prompt>
Run ${lint_command} on changed files, report:
- Status: PASS or FAIL
- Warning/error count and details
</agent-prompt>

### Agent 3: Unit Tests (Haiku, max_turns: 8)

<agent-prompt>
Find test files matching changed modules.
Run ${test_command} on those files, report:
- Status: PASS or FAIL or NO_TESTS
- Test count, pass count, fail details
</agent-prompt>

## Result Synthesis (Opus)

After all Haiku agents report back, the orchestrator (Opus) synthesizes the raw output:

1. **Correlate failures across agents** — A type error in `auth.ts` that causes both a compile failure AND test failures is ONE root cause, not separate issues. Group related failures together.
2. **Prioritize by impact** — Compile errors first (they block everything), then lint errors, then test failures. Within each category, group by root cause.
3. **Suggest fixes** — For each root cause, suggest a concrete fix (e.g., "Missing export in `src/utils/index.ts` — add `export { validateToken }` to fix 3 compile errors and 2 test failures").

This is why test agents just report raw output — the orchestrator has the full picture across all agents and can see that failures in different domains share a common root cause.

## Test Result Report

When all agents pass:
```
SWARM TEST RESULTS
═══════════════════════════════════════════════════

  Compile      ✓ PASS     0 errors
  Lint         ✓ PASS     0 errors, 2 warnings
  Unit Tests   ✓ PASS     12 tests, 12 passed

───────────────────────────────────────────────────
  Overall: PASS
  Duration: ~30s | Agents: 3
═══════════════════════════════════════════════════
```

When failures exist — show root cause analysis:
```
SWARM TEST RESULTS
═══════════════════════════════════════════════════

  Compile      ✗ FAIL     3 errors
  Lint         ✓ PASS     0 errors, 1 warning
  Unit Tests   ✗ FAIL     12 tests, 9 passed, 3 failed

───────────────────────────────────────────────────

ROOT CAUSES (2)

  1. Missing export in src/utils/index.ts
     Impact: 2 compile errors + 2 test failures
     Fix: Add `export { validateToken }` to src/utils/index.ts
     Affected: src/auth/middleware.ts, src/auth/__tests__/middleware.test.ts

  2. Type mismatch in UserProfile interface
     Impact: 1 compile error + 1 test failure
     Fix: Change `age: string` to `age: number` in src/types/user.ts:14
     Affected: src/services/profile.ts

───────────────────────────────────────────────────
  Overall: FAIL (2 root causes)
  Duration: ~30s | Agents: 3
═══════════════════════════════════════════════════
```

## Cost Estimates

| Scope | Agents | Estimated cost |
|-------|--------|---------------|
| All checks | 3 Haiku | ~$0.10 |
| Compile only | 1 Haiku | ~$0.03 |

## Key Rules

<rules>
- Test agents are **read-only** — they never modify source files
- All agents run with `run_in_background: true`
- If compilation fails, still run other agents (user wants the full picture)
- Skip agents whose commands are not configured (null in config.json) — warn the user
</rules>
