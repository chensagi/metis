# Controlled Mode (`--controlled`)

Run the swarm in **controlled mode** — the orchestrator pauses for user approval at every decision point before executing. Can combine with other flags: `/swarm --controlled --budget 10`.

## What Changes in Controlled Mode

The continuous loop becomes a **propose → approve → execute** cycle. At each step where the swarm would normally act autonomously, it instead presents a proposal and waits for the user to approve, modify, or reject.

## Approval Checkpoints

| Checkpoint | What's presented | User options |
|------------|-----------------|--------------|
| **Task selection** | Which task(s) to pick up next from `todo/` | Approve, skip task, reorder |
| **Task decomposition** | Work items breakdown with file assignments | Approve, modify scope, reject |
| **Agent prompts** | Full prompt for each agent about to be spawned | Approve, edit prompt, skip |
| **Completion verdict** | Verification results + spot-check for completed agent | Accept as done, send to fix, reject |
| **Fix plan** | Diagnosis results + proposed fix work items | Approve, modify, skip |
| **Git commit** | Staged files + commit message | Approve, edit message, skip |

## Controlled Mode Loop

```
while tasks remain:
  1. PROPOSE TASKS  — Show which tasks will be picked up. Wait for approval.
  2. PROPOSE DECOMP — For each approved task, show work item breakdown. Wait for approval.
  3. PROPOSE AGENTS — Show the full agent prompt for each work item. Wait for approval.
  4. SPAWN          — Only spawn approved agents
  5. WAIT           — Block-wait for agents (same as normal mode)
  6. PROPOSE RESULT — Show agent output summary + verification results. Wait for verdict.
  7. PROCESS        — Apply approved completions (file move, commit)
  8. Loop
```

## How to Present Proposals

Use `AskUserQuestion` for each checkpoint. Format the proposal clearly so the user can scan it quickly:

```
PROPOSAL: Pick up Task 26 (Stop-Loss Orders)
─────────────────────────────────────────────
Complexity: Medium | Files: ~5 | Est. cost: ~$1.00

Work items:
  1. Types + constants (src/types/orders.ts, src/constants/orders.ts)
  2. Core logic (src/services/orderService.ts — add stop-loss monitoring)
  3. UI (src/components/StopLossInput.tsx, integration with existing UI)
```

Options: Approve / Skip this task / Modify scope

## Key Rules

<rules>
- Never spawn an agent without explicit user approval in controlled mode
- Show enough context for the user to make an informed decision (file list, interfaces, key logic)
- If the user modifies a prompt, use their version exactly
- Between checkpoints, the orchestrator can do read-only work (reading tasks, analyzing code) without approval
- The `--controlled` flag is stored in `.metis/agents.json` so it persists across `/swarm status` calls
</rules>

## agents.json Addition

```json
{
  "mode": "controlled",
  "agents": [ ... ]
}
```
