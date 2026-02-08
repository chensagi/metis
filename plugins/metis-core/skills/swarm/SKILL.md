---
name: swarm
description: Orchestrate parallel task execution with automatic dependency management and centralized progress tracking
argument-hint: [status|stop|audit|integrate|test|--budget N|--controlled] (optional - defaults to start)
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, TaskOutput
---

# Swarm Orchestrator

You are executing the `/swarm` command. This skill lets you run multiple tasks in parallel from a single session.

## Bootstrap

Before starting, ensure `.metis/` exists with a valid config:

1. **If `.metis/config.json` exists** → Read it, proceed with existing config
2. **If `.metis/` doesn't exist** → Tell the user to run `/install` first for full interactive setup. If they want to proceed immediately, do a minimal bootstrap:
   - `mkdir -p .metis/capabilities .metis/skills .metis/tasks/todo .metis/tasks/doing .metis/tasks/done`
   - Create `.metis/.gitignore` (hybrid — see install skill)
   - Auto-detect project type and create minimal `.metis/config.json`
   - Initialize `.metis/agents.json` as `{ "agents": [], "completed": [], "needs_review": [] }`

### Loading Capabilities

After bootstrap, load the project's capabilities for use in agent prompts:

1. Read `.metis/capabilities/manifest.json` (if exists) to get the list of active capabilities
2. For each capability listed, read `.metis/capabilities/{name}.md`
3. Extract the content under `## Agent Instructions` from each capability file
4. Store these instructions — they'll be injected into every agent prompt (see "Spawning Agents")

## How It Works

1. You spawn **background agents** using the Task tool with `run_in_background: true`
2. Each agent works on a task independently
3. You **wait** for agents to complete using `TaskOutput(block: true)`
4. When agents complete, you process results (file move, commit) and spawn new agents
5. This continues in a **loop** until all tasks are done or the user stops

## Commands

### `/swarm` (default command)

Run the **continuous swarm loop**. Spawns agents, waits for completion, processes results, spawns more.

<loop>
Continuous loop (autonomous mode — default):

while tasks remain:
  1. AUDIT    — Check running agents for completions (non-blocking)
  2. PROCESS  — For each completed agent (one at a time): verify → file move → commit
  3. FIX      — If needs_review tasks exist, spawn fix agents first
  4. FILL     — Spawn agents for available tasks (hard cap: 4 TOTAL background agents — see "Agent Limit")
  5. BUDGET   — If --budget was set, check estimated cost. Exit if over budget
  6. STATUS   — Display current swarm status
  7. WAIT     — Block-wait on ONE running agent, then loop back to check all (see "Waiting for Agents")
  8. Go back to step 1
</loop>

**The loop exits when:**
- No running agents AND no available tasks AND no needs_review items
- User interrupts
- **Cost budget**: If `--budget` was set and estimated cost exceeds it

**Priority within each iteration:**
1. Fix incomplete tasks (highest priority)
2. Then start new tasks

### `/swarm status`

Show current status without spawning any agents.

**Action:**
1. **Run a quick audit first**: For any agents listed as "running", check their output files to detect silent completions or crashes. Update `.metis/agents.json` before displaying.
2. Read `.metis/tasks/todo/*.md`, `.metis/tasks/doing/*.md`, and `.metis/tasks/done/*.md` to get all tasks and their states
3. Check `.metis/agents.json` for running agents (if exists)
4. Display a status table (no agents spawned)

### `/swarm [task-number]`

Start a specific task (e.g., `/swarm 40`).

**Action:**
1. Move task file: `git mv .metis/tasks/todo/${filename} .metis/tasks/doing/${filename}`
2. Spawn one background agent for that task (pointing to `.metis/tasks/doing/`)
3. Track it in `.metis/agents.json`

### `/swarm --budget N`

Run the continuous loop with an estimated cost ceiling of **$N**. Can combine with other commands.
See [budget-tracking.md](budget-tracking.md) for the cost model and budget check algorithm.

### `/swarm --controlled`

Run the swarm in **controlled mode** — pauses for user approval at every decision point (task selection, decomposition, agent spawn, completion verdict, commit).
See [controlled-mode.md](controlled-mode.md) for the full approval checkpoint flow.

### `/swarm stop`

Stop spawning new agents (running agents continue until done).

### `/swarm audit`

Reconcile `.metis/agents.json` with actual agent state. Checks output files for completion/crash patterns, verifies files were created, runs completion lifecycle (file move, commit). See [audit-reference.md](audit-reference.md) for detailed heuristics and output format.

### `/swarm integrate`

Run integration testing on recently completed tasks using a two-phase diagnose-then-fix approach.
See [integration-flow.md](integration-flow.md) for the full workflow. The diagnostics agent uses [integration-checklist.md](integration-checklist.md).

### `/swarm test`

Run a parallel test swarm that verifies current changes using static checks and tests (compile/type check, lint, unit tests).
See [test-swarm.md](test-swarm.md) for agent configurations and scope detection.

---

## Task Lifecycle Management

Every task goes through a clear lifecycle reflected by its file location:

```
.metis/tasks/todo/XX-name.md  →  .metis/tasks/doing/XX-name.md  →  .metis/tasks/done/XX-name.md
       (available)                      (agent working)                    (verified complete)
```

### When Spawning an Agent
1. Move the task file: `git mv .metis/tasks/todo/${filename} .metis/tasks/doing/${filename}`
2. Spawn the background agent (pointing to `.metis/tasks/doing/${filename}`)
3. **Capture the `agent_task_id`** from the Task tool's response — needed for `TaskOutput` waiting
4. Update `.metis/agents.json` with agent info including `agent_task_id`

### When a Task Completes Successfully

**VERIFY BEFORE MARKING DONE** — Run verification directly (no agent spawn):

1. Run `${verify_command} 2>&1 | head -30` (from `.metis/config.json`) — zero errors required. If `verify_command` is null, skip this step
2. Read the task spec at `.metis/tasks/doing/${filename}` — find the file structure or requirements
3. Spot-check that key files listed in the spec exist (use Glob)

- If **clean** → proceed to completion lifecycle
- If **errors** → task goes to `needs_review` with the errors noted

> **Why no verification agent?** Each agent result adds to context. The orchestrator can run verification directly via Bash in one call — cheaper and context-lighter than spawning an agent that does the same thing.

**If verification passes:**
1. Move the task file: `git mv .metis/tasks/doing/${filename} .metis/tasks/done/${filename}`
2. Move entry from `agents` → `completed` in `.metis/agents.json`
3. **Git commit** the completed task (see "Git Commits" below)

### When a Task Needs Review
1. Task file stays in `.metis/tasks/doing/` (it's still being worked on)
2. Move entry to `needs_review` in `.metis/agents.json`

### When a Fix Agent Completes a needs_review Task
1. Move the task file: `git mv .metis/tasks/doing/${filename} .metis/tasks/done/${filename}`
2. Move entry from `needs_review` → `completed` in `.metis/agents.json`
3. **Git commit**

### Git Commits

After each task completion (file moved to `done/`), create a git commit:

```bash
git add .metis/tasks/done/${filename} .metis/tasks/doing/ .metis/agents.json
git add ${relevant_source_files}
git commit -m "$(cat <<'EOF'
Task ${num}: ${name} — complete

- Implemented ${brief_summary}
- Files: ${key_directories}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

<rules>
- Commit each task individually (not batched) so git history is clean
- Only stage files relevant to that task + the task file move + agents.json
- If multiple tasks complete at once (discovered during audit), commit each one separately in task-number order
- Never force-push or amend previous commits
</rules>

---

## Spawning Agents

### Standard Task — Decompose then Fill

The orchestrator (you, running on Opus) decomposes tasks into focused work items, then spawns Sonnet agents to fill each one. This is more cost-effective and reliable than sending one agent the entire task.

**Step 1: Move the task file**
```bash
git mv .metis/tasks/todo/${filename} .metis/tasks/doing/${filename}
```

**Step 2: Read and decompose the task**

Read `.metis/tasks/doing/${filename}` and break it into 1-3 focused work items. Each work item should:
- Target specific files (e.g., "create auth middleware and validation utils")
- Include the exact interfaces/types the files should export (copy from task spec)
- Be independent enough to implement without the other work items existing yet

**Decomposition strategy:**
1. **Types/interfaces first**: If the task defines shared types, create a work item for the types file
2. **Core logic**: Group related implementation files into 1-2 work items
3. **Integration/wiring**: The last work item should wire everything together and handle exports

For simple tasks (<=3 files), use a single work item. For complex tasks (4+ files), split into 2-3 work items.

**Step 3: Spawn worker agents**

For each work item, spawn a focused agent. Read `.metis/config.json` for `verify_command` and load capability instructions (gathered during bootstrap).

<agent-prompt>
Task({
  description: "Task ${num}: ${name} — ${workItemDescription}",
  prompt: `You are a task-filler agent. You receive a focused work item describing specific files to create or modify.

## Project Context
Read the project's CLAUDE.md (if it exists) for codebase conventions and architecture.

## Project Capabilities
${capabilityInstructions}

## Rules
- Stay focused on YOUR work item — don't implement files outside your scope
- If shared types are provided, use them exactly as given
- If you need to import from a sibling module being built by another agent, create the import assuming it will exist
- Follow existing code patterns in the codebase — read neighboring files to match style
- Create ALL files listed in the work item requirements — do not skip any
- You MUST end with ${verify_command} returning ZERO errors. If there are errors, fix them before finishing. This is a hard gate — do not finish with errors

## Work Item for Task ${num} (${name})

Task file: .metis/tasks/doing/${filename}

### Your scope
${exactFilesToCreate}

### Types to use
${copyRelevantInterfacesFromTaskSpec}

### Implementation details
${specificLogicForTheseFiles}`,
  subagent_type: "general-purpose",
  model: "sonnet",
  run_in_background: true,
  max_turns: 30
})
</agent-prompt>

**How `capabilityInstructions` is built:**

The orchestrator reads each active capability's "Agent Instructions" section and concatenates them. For a React Native + Expo + Zustand project, this might produce:

```
### TypeScript
Every task MUST end with npx tsc --noEmit returning ZERO errors...
Use explicit types for function parameters...

### React Native
Use React Native primitives — NOT web HTML elements...
Always use StyleSheet.create() for styles...

### Expo
If the project uses Expo Router, directory structure = routes...

### Zustand
Naming: use{Name}Store for the hook...
Always use selectors: useMyStore(s => s.specificField)...
```

This is injected directly into the prompt. The orchestrator decides how much to include based on relevance to the work item (e.g., skip `ios-simulator` instructions for a backend logic task).

**Step 4: Capture agent_task_id**

The Task tool response includes a task ID when `run_in_background: true`. Store this as `agent_task_id` in `.metis/agents.json` — it's required for `TaskOutput` to wait on the agent in the WAIT step.

**Example decomposition** for a task with 6 files:
- Work item 1: "Create types and constants" (shared definitions)
- Work item 2: "Create core service logic and utilities" (business logic)
- Work item 3: "Create integration layer and wire up" (routing, config, exports)

Each agent gets `max_turns: 30` (focused scope needs fewer turns than a full task).

### Fix Flow and Integration Flow

For detailed agent prompts and two-phase workflows:
- **Fix incomplete tasks**: See [fix-flow.md](fix-flow.md)
- **Integration testing**: See [integration-flow.md](integration-flow.md)

---

## Tracking Agents

After spawning, save to `.metis/agents.json`. When a task is decomposed into multiple work items, track each agent separately with a `work_item` label:

<schema>
```json
{
  "agents": [
    {
      "task_id": "12",
      "task_name": "API Auth Middleware",
      "work_item": "types and service logic",
      "output_file": "/path/to/output-12a.txt",
      "agent_task_id": "bg_task_abc123",
      "started_at": "2026-02-06T10:30:00Z",
      "status": "running"
    },
    {
      "task_id": "12",
      "task_name": "API Auth Middleware",
      "work_item": "route handlers and wiring",
      "output_file": "/path/to/output-12b.txt",
      "agent_task_id": "bg_task_def456",
      "started_at": "2026-02-06T10:30:00Z",
      "status": "running"
    }
  ],
  "completed": [
    {
      "task_id": "13",
      "task_name": "User Profile Endpoint",
      "completed_at": "2026-02-06T12:00:00Z",
      "status": "complete"
    }
  ],
  "needs_review": [
    {
      "task_id": "14",
      "task_name": "Rate Limiting",
      "notes": "Hit rate limit. 3 compilation errors in rateLimiter.ts",
      "files_affected": ["rateLimiter.ts", "middleware.ts"]
    }
  ],
  "integration": {
    "status": "running|passed|failed",
    "output_file": "/path/to/integration-output.txt",
    "started_at": "2026-02-06T14:00:00Z",
    "completed_at": "2026-02-06T14:15:00Z",
    "tasks_verified": ["12", "13"],
    "result": {
      "passed": ["Cross-module imports", "Type consistency"],
      "warnings": ["Missing export in utils/index.ts"],
      "failed": []
    }
  }
}
```
</schema>

**When an agent completes:**
- If clean: mark agent entry as `"status": "complete"` in `.metis/agents.json`
- If hit rate limit or has errors: move agent entry to `needs_review`
- **When ALL agents for a task are complete**: run the full completion lifecycle (file move → agents.json update → git commit)
- A task is only "done" when every work item agent for that task_id has completed successfully

### Waiting for Agents (the WAIT step)

This is the key mechanism that makes the swarm continuous. After spawning/filling slots:

1. Collect `agent_task_id` values for all running agents in `.metis/agents.json`
2. **Non-blocking sweep**: Call `TaskOutput(task_id=..., block=false)` on all running agents in parallel to check who's already done
3. **Process any completions immediately** (one at a time — run verification, file move, commit for each before processing the next)
4. **Block-wait on ONE agent**: If agents are still running, pick the oldest and call `TaskOutput(task_id=..., block=true, timeout=600000)` on just that one
5. When it completes, process it, then return to step 2 (non-blocking sweep for any others that finished while we waited)
6. When all agents are processed OR only timed-out agents remain, return to the top of the continuous loop

> **Why not parallel TaskOutput on all agents?** When N agents complete simultaneously, all N result payloads land in context at once. With 6 agents, this can exceed the context window before the orchestrator even gets to process them. Incremental processing lets auto-compaction reclaim space between completions.

<rules>
Never call `TaskOutput(block=true)` on more than ONE agent at a time.
</rules>

### Checking Progress (for `/swarm status` and audits)

When NOT in the continuous loop (e.g., `/swarm status`), check agents the old way:
1. Read each agent's `output_file` using the Read tool
2. Look for completion indicators
3. Update status in `.metis/agents.json`

### Status Display

```
METIS SWARM STATUS
=================================================

RUNNING (2 agents)
   Task 12: API Auth Middleware
   - Agent working for 5 minutes...

NEEDS FIX (1 task) — These get fixed FIRST on next /swarm start
   Task 14: Rate Limiting
   - 3 compilation errors in rateLimiter.ts, middleware.ts

READY TO START (3 tasks)
   Task 15: Database Migrations
   Task 16: Error Handling
   Task 17: Caching Layer

COMPLETED (2 tasks)
   Task 13: User Profile Endpoint
   Task 11: Health Check Endpoint

INTEGRATION
   Last run: 10 minutes ago
   Status: PASSED (verified Tasks 12, 13)

=================================================
Waiting for agents to complete...
```

---

## Backlog Reconciliation

On first run, if `.metis/agents.json` shows tasks as `completed` but their files are still in `.metis/tasks/todo/` (not `.metis/tasks/done/`), reconcile them:

1. For each task in `.metis/agents.json` `completed` array:
   - Check if the task file is in `.metis/tasks/todo/` or `.metis/tasks/doing/` (it should be in `.metis/tasks/done/`)
   - If misplaced: `git mv` to `.metis/tasks/done/`
2. Commit all reconciled moves in a single commit
3. This only needs to happen once — after reconciliation, the lifecycle management keeps everything in sync.

---

## Limitations

<rules>
1. **Max 4 total background agents** — This counts every work item, not tasks. Example: 2 tasks x 2 work items = 4 agents (at the cap). Do NOT exceed this. More agents = more results landing in context at once = context exhaustion risk
2. **File conflicts** — Don't run agents that edit the same files
3. **Rate limits** — Agents may hit API limits mid-task; they go to `needs_review` and get fixed next iteration
4. **Integration flow** — Only run one integration cycle at a time; wait for completion before starting new tasks
5. **No nested agents** — Subagents can't spawn subagents. The orchestrator (you) must do all decomposition and spawning. This is why fix/integration use two-phase flows
6. **TaskOutput timeout** — Max 10 minutes per wait cycle. Long-running agents get re-waited in the next iteration
7. **Context accumulation** — Very long swarm sessions accumulate context. Auto-compaction handles this in most cases, but if the session becomes sluggish, restarting `/swarm` in a new conversation is always safe (state is in .metis/agents.json + filesystem)
8. **Budget is estimated** — Claude Code does not expose actual cost to skills. The `--budget` feature uses rough estimates. Always check actual spend with `/cost` after the session
</rules>

---

## Supporting Files

Load these when the relevant subcommand is invoked:

| File | Load when |
|------|-----------|
| [controlled-mode.md](controlled-mode.md) | `/swarm --controlled` |
| [test-swarm.md](test-swarm.md) | `/swarm test` |
| [fix-flow.md](fix-flow.md) | Processing `needs_review` tasks |
| [integration-flow.md](integration-flow.md) | `/swarm integrate` |
| [budget-tracking.md](budget-tracking.md) | `/swarm --budget N` |
| [audit-reference.md](audit-reference.md) | `/swarm audit` |
| [integration-checklist.md](integration-checklist.md) | Integration diagnostics agent |
| [examples.md](examples.md) | First-time usage reference |
