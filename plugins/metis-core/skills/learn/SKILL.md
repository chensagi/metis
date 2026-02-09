---
name: learn
description: Analyze the project and suggest capability improvements, config tuning, and custom skills. Uses the best model for intelligent analysis.
argument-hint: [--deep] (optional - run a thorough analysis instead of quick scan)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, TaskOutput, WebSearch, WebFetch
---

# Metis Learn — Analyze & Suggest Improvements

You are executing the `/learn` command. This skill analyzes how the project is being used and suggests improvements to capabilities, config, and custom skills.

**Model hierarchy:** Opus for thinking/reasoning tasks, Sonnet for implementation, Haiku for exploration and trivial tasks. Learning is fundamentally a *thinking* task — the orchestrator (Opus) handles the quick scan directly. Deep analysis uses Opus for reasoning about what's missing, with Haiku agents for gathering the raw data.

## Prerequisites

<rules>
BEFORE DOING ANYTHING ELSE, check if `.metis/config.json` exists:
- **If it exists** → Proceed
- **If `.metis/` does not exist** → STOP. Tell the user: "Run `/install` first to set up Metis for this project." Do NOT proceed. Do NOT fall back to any other directory structure. Do NOT attempt to work without `.metis/`. This is a hard requirement — the skill cannot function without it.
</rules>

## Modes

### Quick Scan (default)

The orchestrator (you, Opus) runs this directly — no agents spawned. Checks for obvious improvements based on file existence, dependency analysis, and pattern matching. This is also what runs automatically after `/swarm` or `/task` completes (if `learning.auto_suggest` is true in config).

### Deep Analysis (`/learn --deep`)

Two-phase: Haiku agent explores and gathers raw data, then YOU (Opus) reason about the findings and produce intelligent recommendations. This follows the metis model hierarchy: Haiku for exploration, Opus for thinking.

---

## Quick Scan Flow

### Step 1: Gather State

Read directly (no agents needed):
1. `.metis/config.json` — current settings
2. `.metis/capabilities/manifest.json` — installed capabilities
3. `.metis/learnings.json` — previous learnings and applied suggestions
4. Recent git log: `git log --oneline -10`
5. Package manifest (package.json, pyproject.toml, go.mod, or Cargo.toml)

### Step 2: Check for Gaps

Run quick checks directly:

1. **Missing capabilities**: Grep for technology signatures not covered by installed capabilities:
   - `zustand` in package.json but no zustand capability → suggest adding
   - `@shopify/react-native-skia` in package.json but no skia capability → suggest adding
   - `reanimated` in package.json → suggest adding when available
   - Maestro flows in `.maestro/` but no maestro capability → suggest adding
   - pytest in pyproject.toml but no python capability → suggest adding

2. **Config staleness**: Check if commands still work:
   - Does `verify_command` reference a tool that exists? (check node_modules/.bin/ or system PATH)
   - Are `src_dirs` still accurate? (do the directories exist?)
   - Has the project structure changed? (new top-level directories with source code)

3. **Agent failure patterns**: If `learnings.json` has entries, check for recurring issues:
   - Same type of compilation error across multiple tasks → suggest capability update
   - Agents repeatedly failing on import patterns → suggest custom skill
   - Repeated timeout or rate limit issues → suggest reducing max_agents

4. **Capability version drift**: Compare installed versions against metis registry:
   - The plugin root is two levels up from this skill's base directory (`{base_directory}/../../`). Read the registry at `{plugin_root}/capabilities/registry.json`
   - Flag capabilities that have newer versions available

### Step 3: Present Quick Suggestions

```
METIS LEARN — Quick Scan
═══════════════════════════════════════════════════

Findings:

  1. MISSING CAPABILITY: zustand
     Evidence: "zustand" found in package.json dependencies
     Suggestion: Run /install --update to add the zustand capability

  2. CONFIG: src_dirs outdated
     Evidence: src/services/ exists but not in src_dirs
     Suggestion: Add "src/services/" to src_dirs in .metis/config.json

  3. CUSTOM SKILL OPPORTUNITY
     Evidence: 3 recent commits involve Maestro test creation
     Suggestion: Run /add-metiskill to create a "create-test" skill
     that scaffolds Maestro flows with your project's testIDs

  4. CAPABILITY UPDATE: typescript 0.1.0 → 0.2.0
     What changed: Added strictNullChecks conventions
     Suggestion: Run /install --update to upgrade

═══════════════════════════════════════════════════

Apply suggestions? (will ask for each one individually)
After applying, consider /clear to start fresh.
```

### Step 4: Apply Approved Suggestions

For each approved suggestion:
- **Add capability** → Copy from registry to `.metis/capabilities/`, update manifest
- **Update config** → Edit `.metis/config.json` directly
- **Upgrade capability** → Overwrite capability file, update manifest version
- **Add custom skill** → Guide through `/add-metiskill` flow

Record applied suggestions in `.metis/learnings.json`:
```json
{
  "entries": [
    {
      "date": "2026-02-08",
      "type": "capability_added",
      "detail": "Added zustand capability — detected in package.json",
      "applied": true
    }
  ],
  "suggestions_applied": ["zustand-capability-2026-02-08"]
}
```

---

## Deep Analysis Flow (`/learn --deep`)

### Step 1: Spawn Haiku Explorer Agent (gather raw data)

<agent-prompt>
Task({
  description: "Deep learn: gather project data",
  prompt: `You are a data-gathering agent. Explore this project and collect structured information for analysis. Do NOT analyze or recommend — just gather and report facts.

Collect:
1. Read .metis/config.json, .metis/capabilities/manifest.json, .metis/learnings.json
2. Read CLAUDE.md (if exists)
3. Run: git log --oneline -30
4. Read the package manifest (package.json, pyproject.toml, go.mod, or Cargo.toml) — list ALL dependencies
5. List all directories in the source dirs
6. Find technology-specific config files: jest.config*, .eslintrc*, babel.config*, tsconfig.json, etc.
7. List all files in .maestro/ (if exists)
8. Read the first 20 lines of 5-10 representative source files to understand code patterns
9. Check which verify/test/lint commands actually work (run them, capture output)
10. Use WebSearch to discover:
    - Tools/libraries that complement the current stack
    - Better alternatives to current dependencies (if they exist)
    - Best practices for the project's technology combination
    Report raw findings only.

Output everything you find in a structured report with raw data. Do not filter or analyze — the orchestrator will do that.

## Rules
- DO NOT modify any files — this is a read-only exploration
- DO NOT create files outside .metis/
- Write your findings as your final response — do not create separate output files
- Stay within the project directory — do not explore system directories`,
  subagent_type: "Explore",
  model: "haiku",
  run_in_background: false,
  max_turns: 15
})
</agent-prompt>

### Step 2: Analyze (Opus — YOU do the thinking)

When the Haiku agent returns its raw data, YOU (Opus) perform the actual analysis:

1. **CAPABILITY GAPS** — Cross-reference dependencies against installed capabilities
   - What technologies does the code use that aren't covered?
   - Look for configuration files that suggest specific frameworks
   - Check if any capabilities should be added or removed

2. **CONFIG ACCURACY** — Based on the command test results
   - Are verify/test/lint commands working?
   - Are src_dirs covering all source directories?
   - Is max_agents appropriate for project size?

3. **AGENT PERFORMANCE** — Review learnings.json patterns
   - Recurring errors → what capability or skill would prevent them?
   - Import failures → missing path alias documentation?
   - Timeout issues → max_agents too high?

4. **WORKFLOW GAPS** — Based on git history and code patterns
   - Repetitive commit patterns → custom skill opportunity?
   - Manual verification steps → capability extension?
   - Testing gaps → new skill or capability?

5. **CAPABILITY QUALITY** — For each installed capability
   - Does it match how this project actually uses the technology?
   - Project-specific conventions that should be added?

### Step 3: Tool/Library Discovery

During deep analysis, search the web for tools that could benefit the project:

1. Based on the project's stack, search for complementary tools
2. Check if recurring error patterns would be solved by a different library
3. Look for tools that automate manual patterns found in the codebase

**The suggestion flow:**
1. Agent reports raw findings (library name, what it does, popularity)
2. Opus (you) evaluates: is this genuinely useful for THIS project?
3. Web search to validate: actively maintained? compatible? stable?
4. Only include in the learn report if it passes validation
5. Present as a suggestion, not a recommendation

### Step 4: Present Deep Report

Format YOUR analysis into an actionable report with clear categories, evidence, and prioritization. Include tool/library suggestions as a separate section with evidence and reasoning.

### Step 5: Apply (same as quick scan)

---

## Auto-Trigger (after swarm/task)

When `learning.auto_suggest` is true in config, the swarm and task skills should run a minimal version of the quick scan after completion. This is NOT a separate agent — it's a few grep/read checks done by the orchestrator directly:

1. Check if any new dependencies were added during the task
2. Check if agents encountered repeated errors (scan the task log)
3. If findings: show a brief "Metis suggests: ..." note

This adds ~5 seconds and zero cost (no agent spawned).

---

## learnings.json Schema

```json
{
  "entries": [
    {
      "date": "2026-02-08",
      "type": "capability_added|config_updated|skill_added|error_pattern|suggestion_dismissed",
      "detail": "Human-readable description",
      "applied": true,
      "source": "quick_scan|deep_analysis|auto_trigger"
    }
  ],
  "suggestions_applied": ["unique-suggestion-id-1"],
  "error_patterns": [
    {
      "pattern": "Cannot find module './utils/formatters'",
      "count": 3,
      "last_seen": "2026-02-08",
      "resolution": null
    }
  ]
}
```

## Key Rules

<rules>
- NEVER modify source code — this skill only modifies `.metis/` files
- Quick scan: orchestrator runs directly, no agents, < 10 seconds
- Deep analysis: ONE Haiku agent gathers data, Opus (you) reasons about it
- Always record learnings in learnings.json, even dismissed suggestions
- Don't suggest the same thing twice — check suggestions_applied before presenting
- Auto-trigger should be invisible if there's nothing to suggest
</rules>
