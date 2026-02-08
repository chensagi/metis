# Metis

## Mission

Cost-efficient, self-learning AI orchestration that makes professional coding accessible to everyone. Every token is currency — use the cheapest model that can do the job.

## Core Philosophy

### Cost Efficiency First

- Every token counts. Reduce prompt sizes, inject only relevant capabilities
- Use the cheapest model tier that can handle the task
- Current hierarchy: Haiku (diagnostics, ~$0.05) → Sonnet (implementation, ~$0.50) → Opus (orchestrator only)
- Future: Ollama local models (7B/13B, $0 cost) for mundane preprocessing
- Agent turns are budget: Haiku max 10-15, Sonnet max 30

### Ask → Explore → Research → Plan → Execute

- Always clarify requirements before spending tokens on implementation
- Explore the codebase cheaply (Haiku/grep) before designing solutions
- **Research** — search the web for relevant docs, best practices, known issues. Always consider if web research would improve your plan
- Plan the approach and get user approval before writing code
- Only then execute with Sonnet agents
- This workflow prevents wasted tokens on wrong approaches

### Self-Learning

- Every task completion feeds back into the system (learnings.json)
- Capabilities improve with every repo Metis touches
- Error patterns are tracked and inform future agent prompts
- `/learn` analyzes gaps and suggests improvements automatically

### Accessibility

- Main goal: everyone should be able to vibecode and code professionally
- Ask good questions to understand user intent
- Deliver fast, be on point
- Reduce complexity — the user shouldn't need to understand the internals

## Architecture

### 3-Layer Architecture

| Layer | Component | Runs On | Role |
|-------|-----------|---------|------|
| L0 — Platform | Claude Code | Any model (even Haiku) | User session, thin dispatcher for complex skills |
| L1 — Spine | Opus | Spawned as Task agent | Thinking, judgment, research direction, evaluation |
| L2 — Leaves | Sonnet/Haiku/Ollama | Spawned as Task agents | Implementation, exploration, web research retrieval |

**The core pattern — Opus thinks, agents do, Opus decides:**
- Opus THINKS: decomposition, research queries, work item design, evaluation criteria
- Agents DO: code writing, web searching, diagnostics, data gathering
- Opus DECIDES: verification, relevance judgment, commit/reject

**Hybrid skill execution:**
- **Dispatcher skills** (swarm, large triage): L0 coordinates — spawns Opus for judgment,
  Sonnet/Haiku for work. The user's session can run on a cheap model.
- **Direct skills** (task, install, learn quick scan): Opus runs in chat context for
  interactive work. Simpler, lower overhead.

Claude Code's hard constraint: Task agents cannot spawn further Task agents (no nesting).
For dispatcher skills, L0 handles all spawning — alternating between Opus (for thinking)
and Sonnet/Haiku (for execution).

### Capability Subsetting (Cost Optimization)

When spawning agents, inject ONLY capabilities relevant to the work item — not the full installed set:

- Backend logic task → skip ios-simulator, maestro, react-native capabilities
- UI task → skip backend-specific capabilities
- Type-only task → only typescript capability

The orchestrator decides which capabilities to inject based on the work item's file targets and description. This reduces prompt size and agent confusion. Match capabilities against their `provides` tags to determine relevance.

### Swarm Isolation

- `/swarm` should run in a dedicated session (separate conversation)
- It loops until: all tasks done, budget exhausted, or user stops it
- Think properly before implementation — poor planning wastes expensive Sonnet tokens
- Each swarm agent gets a focused, minimal prompt
- State is persisted in `.metis/agents.json` — safe to restart in a new session

### Planning Before Implementation

The `/task` skill includes a planning phase (like Claude's plan mode):

1. Read the task spec
2. Explore relevant code (cheap: grep, glob, read)
3. **Research** — search the web for relevant docs, patterns, known issues (see "Web Research")
4. Design the implementation approach
5. Present the plan to the user
6. Only then implement

This prevents wasted Sonnet tokens on wrong approaches. The swarm skill also follows this principle — the orchestrator reads the full task spec and explores the codebase area before decomposing into work items.

### Web Research

**Always consider whether web research would improve your plan.** Real developers constantly search docs, check APIs, and look up error messages. Metis agents should do the same.

**When to research:**
- Planning any task: search for current best practices, API documentation, known issues with specific library versions
- Debugging: search for the exact error message + library name — this solves ~80% of issues
- Evaluating new tools: search for comparisons, benchmarks, community feedback before suggesting
- Unfamiliar technology: search for quickstart guides, architecture patterns, common pitfalls

**How web research fits the 3-layer architecture:**
- Opus (L1) DESIGNS search queries during planning/decomposition — identifies what to research
- Agents (L2) EXECUTE the searches using `WebSearch` and `WebFetch` — gather and summarize
- Opus (L1) EVALUATES the results — judges relevance, applies findings to decisions
- Exception: during debugging, Opus may search directly (needs real-time judgment on relevance)
- Opus includes **web research hints** in agent prompts — telling Sonnet/Haiku specifically what to search for
- All web access MUST go through `WebSearch` and `WebFetch` tools — no other method

**Web research hints in agent prompts:**
When spawning agents, Opus should include a `## Research Hints` section:
```
## Research Hints
- Library docs: [specific page or search term]
- Known issue: [error pattern to search for]
- Reference: [API or pattern to look up]
```

This guides agents to research effectively instead of guessing.

### Debugging Philosophy

**The 80/20 rule of debugging:**

**80% — Web search solves it:**
1. Take the exact error message
2. Search: `"{error message}" {library} {version}`
3. Check Stack Overflow, GitHub issues, library docs
4. Apply the fix

**20% — Deep evidence collection:**
When web search doesn't solve it, switch to structured evidence gathering:
1. Collect the full error with stack trace
2. Identify the exact file and line where it fails
3. Read the surrounding code and its dependencies
4. Check recent changes (git diff/log) that might have caused it
5. Search for the error pattern in the codebase (is it happening elsewhere?)
6. Present all evidence structured to the user — help them make sense of it

The deep debug approach doesn't guess — it collects and organizes evidence so the user (or a more capable model) can reason about the root cause.

### Tool & Library Suggestions

The orchestrator should notice when a project could benefit from new tools or libraries:

- During `/task` or `/swarm`: if the implementation would be significantly simpler with a specific library, note it
- During `/learn`: actively search the web for tools that complement the project's current stack
- During debugging: if a recurring error pattern would be solved by a better library, suggest it

**The suggestion flow:**
1. **Observe** — notice a gap or opportunity during normal work
2. **Research** — web search to validate the suggestion (is it maintained? popular? compatible?)
3. **Revisit** — evaluate the suggestion yourself before presenting it (is it truly worth it? does it add complexity?)
4. **Suggest** — only present to the user if you have high confidence it's genuinely valuable
5. **Don't push** — present it as an option, not a requirement. The user decides

## Development Conventions

### Skills

- YAML frontmatter: name, description, argument-hint, allowed-tools
- Markdown body with clear step-by-step instructions
- Use `<agent-prompt>` blocks for agent spawning templates
- Use `<rules>` blocks for hard constraints
- Keep agent prompts concise — every token costs money

### Capabilities

- YAML frontmatter: name, version, description, requires, provides, commands
- `## Agent Instructions` section gets injected into agent prompts
- Keep instructions focused and actionable — no essays
- Version independently with semver

### General

- Prefer editing existing files over creating new ones
- Don't over-engineer — minimum complexity for current needs
- Always include `Co-Authored-By` trailer in commits
- Stage specific files, never `git add -A`

## Repo Structure

```
metis/
├── plugins/metis-core/
│   ├── capabilities/         # Technology-specific agent instructions
│   │   ├── registry.json     # All capability metadata
│   │   └── {name}/capability.md
│   ├── profiles/             # Predefined capability bundles
│   │   └── {name}.json
│   ├── skills/               # Slash command implementations
│   │   └── {name}/SKILL.md
│   └── hooks/hooks.json      # Lifecycle hooks
├── CLAUDE.md                 # This file
└── README.md                 # User-facing docs
```

## Testing Changes

1. Install the plugin in a test project: `/plugin install metis-core@metis`
2. Run `/install` to set up `.metis/`
3. Test the modified skill with a real task
4. Verify agent prompts are concise and capability subsetting works
5. Check that cost estimates make sense
