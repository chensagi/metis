---
name: swarm
description: Orchestrate parallel task execution with automatic dependency management and centralized progress tracking
argument-hint: [status|stop|audit|integrate|test|--budget N|--controlled] (optional - defaults to start)
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, TaskOutput, WebSearch, WebFetch
---

# Swarm Orchestrator

You are executing the `/swarm` command. This skill lets you run multiple tasks in parallel from a single session. For best results, run `/swarm` in a **dedicated conversation** — start it and let it loop continuously until all tasks are done, budget is exhausted, or you stop it with `/swarm stop`. State persists in `.metis/agents.json`, so it's always safe to restart in a new session.

## Architecture: 3-Layer Dispatcher

The swarm runs as a dispatcher on L0 (your Claude Code session — any model).
It spawns Opus for thinking and Sonnet/Haiku for execution. The nesting constraint
(subagents can't spawn subagents) means L0 handles ALL spawning.

```
L0 (this skill, any model) — mechanical routing, file moves, agent tracking
  ↓ spawns (foreground, blocking)
L1 Opus — decomposition, research direction, evaluation, judgment
  ↓ returns structured decisions to L0
L0 reads decisions
  ↓ spawns (background)
L2 Sonnet/Haiku — implementation, web research, diagnostics
  ↓ returns results via TaskOutput
L0 processes results
  ↓ spawns Opus again (foreground) for evaluation
Loop
```

**Key principle:** Opus THINKS (decomposition, research queries, evaluation criteria). Agents DO (code writing, web searching, diagnostics). Opus DECIDES (verification, commit/reject). L0 routes mechanically between them.

### How This Applies Across Skills

| Skill | L0 (Dispatcher) | L1 Opus (Spine) | L2 Sonnet/Haiku (Leaves) |
|-------|-----------------|-----------------|--------------------------|
| `/swarm` | Route, track, file moves | Decompose, evaluate, judge | Implement work items, diagnose |
| `/triage` | Spawn agents, collect results | Synthesize report, assign status | Gather codebase evidence |
| `/swarm test` | Spawn check agents | Correlate failures, root causes | Run compile/lint/test |
| `/swarm integrate` | Coordinate fix cycle | Analyze issues, plan fixes | Fix errors, run checks |
| `/learn` | Spawn explorer | Analyze gaps, recommend | Explore project data, web search |

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
4. Store these instructions — they'll be selectively injected into agent prompts (see "Capability Subsetting" and "Spawning Agents")

### Capability Subsetting

**Not every agent needs every capability.** When spawning agents, inject ONLY the capabilities relevant to that specific work item — not the full installed set.

How the orchestrator selects capabilities for a work item:

1. Look at the work item's target files and description
2. Match against each capability's `provides` tags and the file types involved
3. Include only capabilities whose features are relevant to the work item

**Examples:**
- Backend API task → include typescript, skip react-native, ios-simulator, maestro
- UI component task → include typescript, react-native, skip backend-specific capabilities
- Type definitions task → include only typescript
- E2E test task → include maestro, ios-simulator, skip others

**Why this matters:**
- Reduces prompt size by 60-80% for focused tasks
- Keeps agents focused on relevant patterns
- Saves tokens — every capability injected costs money in agent context
- Prevents agents from applying wrong patterns (e.g., React Native patterns in a Node.js backend file)

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

### Standard Task — Dispatcher Pattern

The swarm uses L0 as a mechanical dispatcher. L0 reads task files, spawns Opus for thinking, and spawns Sonnet/Haiku for execution. This decouples the user's session model from the orchestration intelligence.

**Step 1: Move the task file**
```bash
git mv .metis/tasks/todo/${filename} .metis/tasks/doing/${filename}
```

**Step 2: Spawn Opus for decomposition (foreground, blocking)**

L0 sends the task spec + codebase context to Opus, which explores, thinks, and returns structured work items.

```
Task({
  description: "Decompose task ${num}: ${name}",
  prompt: `You are the Metis orchestrator. Read this task spec and decompose it into work items.

## Task Spec
${taskFileContents}

## Instructions
1. Read the full task spec carefully
2. Explore the codebase area: grep for key names, glob for target dirs, read neighboring files
3. Consider if web research would improve the plan — search for relevant docs/patterns if so
4. Break into 1-3 focused work items. Each work item must:
   - Target specific files
   - Include exact interfaces/types to export (from task spec)
   - Be independent enough to implement without other work items existing yet
5. For each work item, generate research hints: what APIs/libraries/docs the agent should look up
6. Select relevant capabilities per work item (capability subsetting)

## Decomposition Strategy
- Types/interfaces first → core logic → integration/wiring
- Simple tasks (<=3 files): single work item
- Complex tasks (4+ files): 2-3 work items

## Project Capabilities Available
${allCapabilityNames}

## Return Format
Return a JSON object with this structure:
{
  "work_items": [
    {
      "description": "what this work item does",
      "files": ["path/to/file.ts"],
      "capabilities": ["typescript", "react-native"],
      "research_hints": ["Search for X API docs", "Check Y library version"],
      "types": "interfaces/types to use",
      "details": "implementation specifics",
      "model": "sonnet"
    }
  ]
}`,
  subagent_type: "general-purpose",
  model: "opus",
  run_in_background: false
})
```

**Step 3: L0 reads Opus output and spawns worker agents (background)**

L0 parses the work items from Opus's response and spawns Sonnet/Haiku agents for each. Read `.metis/config.json` for `verify_command`.

<agent-prompt>
Task({
  description: "Task ${num}: ${name} — ${workItemDescription}",
  prompt: `You are a task-filler agent. You receive a focused work item describing specific files to create or modify.

## Project Context
Read the project's CLAUDE.md (if it exists) for codebase conventions and architecture.

## Project Capabilities (subset — relevant to this work item)
${relevantCapabilityInstructions}

## Research Hints
${researchHints}

When you encounter errors or unfamiliar APIs, use WebSearch to find solutions.
Use WebFetch to read specific documentation pages.
All web access MUST go through these tools.

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

**How `relevantCapabilityInstructions` is built:**

Opus selects relevant capabilities during decomposition (Step 2). L0 reads each selected capability's "Agent Instructions" section and injects them. For a UI component work item in a React Native + Expo + Zustand project:

```
### TypeScript
Every task MUST end with npx tsc --noEmit returning ZERO errors...

### React Native
Use React Native primitives — NOT web HTML elements...

### Zustand
Naming: use{Name}Store for the hook...
```

This is injected directly into the prompt. See "Capability Subsetting" for the full selection process.

**Step 4: L0 waits for completion, then spawns Opus for evaluation (foreground)**

After agents complete (via TaskOutput), L0 spawns Opus to evaluate:

```
Task({
  description: "Evaluate task ${num}: ${name}",
  prompt: `Evaluate these agent results against the task spec. Run verification.
Return verdict: pass/fail per work item, with reasons.

## Task Spec
${taskFileContents}

## Agent Results
${agentOutputs}

## Verification
Run ${verify_command} and report the result.
Check that key files exist and match the spec.`,
  subagent_type: "general-purpose",
  model: "opus",
  run_in_background: false
})
```

**Step 5: L0 acts on verdict** — file moves, commits, or spawns fix agents for failures.

**Step 6: Capture agent_task_id**

The Task tool response includes a task ID when `run_in_background: true`. Store this as `agent_task_id` in `.metis/agents.json` — it's required for `TaskOutput` to wait on the agent in the WAIT step.

**Example decomposition** for a task with 6 files:
- Work item 1: "Create types and constants" (shared definitions)
- Work item 2: "Create core service logic and utilities" (business logic)
- Work item 3: "Create integration layer and wire up" (routing, config, exports)

Each agent gets `max_turns: 30` (focused scope needs fewer turns than a full task).

### Fix Flow — Debugging with Web Research

When a task goes to `needs_review`, the fix flow starts with web research:

**Phase 0: Web Research First (NEW)**

Before spawning a fix agent, the dispatcher:
1. Extracts exact error messages from the failed agent's output
2. Spawns Opus (foreground) to analyze errors and design search queries
3. Includes those queries as research hints in the fix agent's prompt

The fix agent then:
1. Searches the web FIRST for each error (`WebSearch` with error message + library name)
2. If solution found → apply it
3. If no solution (the 20%) → switch to deep evidence collection:
   - Full error + stack trace
   - Relevant code and dependencies
   - Recent git changes
   - Structured evidence report returned to L0 for Opus to evaluate

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
9. **Session isolation** — For long-running swarm sessions, use a dedicated conversation. The swarm loop is designed to run continuously — start it and let it work. Use `/swarm stop` to stop spawning, or close the session. All state persists in `.metis/agents.json` and the filesystem
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
