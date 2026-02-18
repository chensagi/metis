# Cost Budget Tracking (`--budget`)

When OTEL is enabled (see "Real Cost Data" below), actual session cost is available via the Prometheus endpoint. Otherwise, the budget feature uses estimation based on agent spawns and loop iterations.

## Cost Model

Cost has two components: **per-task costs** (agents spawned for each task) and **per-iteration costs** (L0 orchestrator overhead each loop cycle).

### Per-Task Costs

Each task incurs these costs when processed:

| Component | Model | Estimated cost | Notes |
|---|---|---|---|
| Decomposition | Opus (foreground) | ~$0.75 | Codebase exploration + structured work items |
| Work item agent | Sonnet (background) | ~$0.50 | Per work item (1-3 per task) |
| Fix agent | Sonnet (background) | ~$0.50 | Only if task goes to needs_review |
| Diagnostics | Haiku (background) | ~$0.05 | Fix flow Phase 1 |
| Integration diagnostics | Haiku (background) | ~$0.08 | End-of-swarm integration check |

**Per-task estimate:** ~$1.25 for a simple task (1 decomposition + 1 work item), ~$2.25 for a complex task (1 decomposition + 3 work items).

### Per-Iteration Costs (L0 Orchestrator)

The L0 orchestrator (Opus) processes each loop iteration: reading agents.json, running verification, managing file moves, displaying status. This cost **scales with context size** — early iterations are cheap, later ones are expensive as context accumulates.

| Phase | Estimated cost per iteration |
|---|---|
| Early iterations (1-5, small context) | ~$0.30 |
| Mid iterations (6-15, medium context) | ~$0.60 |
| Late iterations (16+, large context) | ~$1.00+ |

**Use $0.50/iteration as the default estimate.** This is an average that works for typical sessions (8-15 iterations). For long sessions (20+ iterations), actual cost will exceed estimates.

### Quick Estimation Formula

```
estimated_total = sum(per_task_costs) + (iterations × $0.50)
```

**Example: 7-task swarm**
- 7 decompositions × $0.75 = $5.25
- 7 work items × $0.50 = $3.50
- ~12 iterations × $0.50 = $6.00
- **Total estimate: ~$14.75**

Actual cost depends on task complexity, codebase size, cache hit rates, and how many fix cycles are needed. The estimates are intentionally conservative (high) so the budget acts as a ceiling, not a target.

## Budget Tracking in agents.json

When `--budget` is used, add a `budget` field to `.metis/agents.json`:

<schema>
```json
{
  "budget": {
    "limit_usd": 10.00,
    "estimated_spent_usd": 3.85,
    "agents_spawned": [
      { "type": "decomposition", "model": "opus", "estimated_cost": 0.75 },
      { "type": "work_item", "model": "sonnet", "estimated_cost": 0.50 },
      { "type": "work_item", "model": "sonnet", "estimated_cost": 0.50 }
    ],
    "iterations": 4
  },
  "agents": [ ... ]
}
```
</schema>

## Budget Check (the BUDGET step)

Each iteration:

1. Calculate `estimated_spent_usd` = sum of all spawned agent costs (including decomposition calls) + (iterations × $0.50 orchestrator overhead)
2. If `estimated_spent_usd >= limit_usd`: stop spawning new agents, display budget exhausted message, let running agents finish, then exit
3. If `estimated_spent_usd + next_task_cost > limit_usd`: skip spawning, warn in STATUS. Use ~$1.25 as the minimum next-task cost (1 decomposition + 1 work item)
4. Display budget status in every STATUS output:
   ```
   BUDGET: ~$7.50 / $15.00 estimated (50%)
   ```

## Real Cost Data (when OTEL is enabled)

When `/install` configures OTEL (Step 10), Claude Code serves Prometheus metrics at `http://localhost:8888/metrics`. This provides **actual** cost and token usage per model — no estimation needed.

### Reading Actual Cost

```bash
# Check if OTEL endpoint is available
actual_cost=$(curl -s http://localhost:8888/metrics 2>/dev/null \
  | grep '^claude_code_cost_usage_total' \
  | awk '{sum += $2} END {printf "%.2f", sum}')
```

If `actual_cost` is non-empty and non-zero, OTEL is active. Use it instead of estimates.

### Per-Model Breakdown

The endpoint provides per-model data via the `model` label:

```bash
# Cost per model
curl -s http://localhost:8888/metrics 2>/dev/null \
  | grep '^claude_code_cost_usage_total'
# Output: claude_code_cost_usage_total{model="claude-opus-4-6"} 0.75
#         claude_code_cost_usage_total{model="claude-sonnet-4-5-20250929"} 1.50
#         claude_code_cost_usage_total{model="claude-haiku-4-5-20251001"} 0.02

# Token usage per model and type (input/output)
curl -s http://localhost:8888/metrics 2>/dev/null \
  | grep '^claude_code_token_usage_total'
# Output: claude_code_token_usage_total{model="claude-opus-4-6",type="input"} 5000
#         claude_code_token_usage_total{model="claude-opus-4-6",type="output"} 1200
```

### Budget Check with OTEL

When OTEL is available, the budget check becomes:

```
if actual_cost >= limit_usd: stop
```

No estimation formula needed — this is real data.

### Status Display Change

When OTEL is available, the budget line in STATUS changes from:
```
BUDGET: ~$7.50 / $15.00 estimated (50%)
```
to:
```
BUDGET: $7.50 / $15.00 actual (50%)
```

Note the absence of `~` — this is real data, not an estimate.

### Fallback

If the OTEL endpoint is unreachable (not configured, Claude Code not restarted, or port unavailable), fall back to the estimation model above. The budget check algorithm remains the same — only the data source changes.

## Accuracy Disclaimer

Display this once when `--budget` is first used:

> **When OTEL is enabled:** Budget uses actual cost from Claude Code's Prometheus endpoint. This is accurate real-time data.
>
> **When OTEL is not enabled:** Budget is **estimated** — estimates include decomposition (Opus), work items (Sonnet), and orchestrator overhead ($0.50/iteration). Actual cost scales with context size and task complexity. Run `/install` to enable OTEL for accurate tracking, or use `/cost` after the session to see actual spend.
