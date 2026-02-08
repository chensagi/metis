# Cost Budget Tracking (`--budget`)

Claude Code has **no API to query actual session cost** from within a skill. The budget feature uses estimation based on agent count and model.

## Cost Model (estimates per agent)

| Agent type | Model | max_turns | Estimated cost |
|---|---|---|---|
| Work item (task-filler) | Sonnet | 30 | ~$0.50 |
| Fix work item | Sonnet | 30 | ~$0.50 |
| Diagnostics | Haiku | 10 | ~$0.05 |
| Integration diagnostics | Haiku | 15 | ~$0.08 |
| Orchestrator overhead | Opus | per iteration | ~$0.30 |

These are rough estimates. Actual cost depends on task complexity, codebase size, and cache hit rates. The estimates are intentionally conservative (high) so the budget acts as a ceiling, not a target.

## Budget Tracking in agents.json

When `--budget` is used, add a `budget` field to `.metis/agents.json`:

<schema>
```json
{
  "budget": {
    "limit_usd": 10.00,
    "estimated_spent_usd": 3.85,
    "agents_spawned": [
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

1. Calculate `estimated_spent_usd` = sum of all spawned agent costs + (iterations x $0.30 orchestrator overhead)
2. If `estimated_spent_usd >= limit_usd`: stop spawning new agents, display budget exhausted message, let running agents finish, then exit
3. If `estimated_spent_usd + next_agent_cost > limit_usd`: skip spawning, warn in STATUS
4. Display budget status in every STATUS output:
   ```
   BUDGET: ~$3.85 / $10.00 estimated (38%)
   ```

## Accuracy Disclaimer

Display this once when `--budget` is first used:

> Budget is **estimated** — Claude Code does not expose actual cost to skills. Estimates are based on agent model and max_turns. Use `/cost` after the session to see actual spend.
