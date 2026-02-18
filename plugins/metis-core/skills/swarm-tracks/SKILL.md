---
name: swarm-tracks
description: Plan and set up multi-session parallel development using git worktrees — group tasks into independent tracks, generate setup scripts and session prompts
argument-hint: [status|teardown] (optional - check track status or clean up worktrees)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Swarm Tracks — Multi-Session Parallel Development

You are executing the `/swarm-tracks` command. This skill enables true parallel development by using git worktrees to run multiple Claude Code sessions simultaneously, each working on an independent track of tasks.

**How this differs from `/swarm`:**
- `/swarm` runs in a single session, spawning background agents — limited by context and concurrency
- `/swarm-tracks` sets up separate git worktrees so the user can open multiple terminal sessions, each running its own `/swarm` or `/task` — true parallelism with no shared context limits

Claude Code cannot spawn separate terminal sessions, so this skill **plans and generates scripts** — the user executes them manually.

## Bootstrap

<rules>
BEFORE DOING ANYTHING ELSE, check if `.metis/config.json` exists:
- **If it exists** → Read it, load capabilities, proceed
- **If `.metis/` does not exist** → STOP. Tell the user: "Run `/install` first to set up Metis for this project." Do NOT proceed.
</rules>

## Command Routing

Parse `$ARGUMENTS`:

| Argument | Action |
|----------|--------|
| *(empty)* | **Plan tracks** — full workflow below |
| `status` | **Check status** — show which worktrees exist and their progress |
| `teardown` | **Clean up** — remove worktrees and merge branches |

---

## Plan Tracks (default)

### Step 1: Analyze the Backlog

1. Read all task files in `.metis/tasks/todo/`
2. Read `.metis/tasks/project.md` if it exists (for existing dependency graph)
3. Build a dependency graph from `Blocked by:` and `Blocks:` fields
4. Identify independent task clusters — groups of tasks with no cross-dependencies

### Step 2: Group into Tracks

Partition tasks into 2-6 parallelizable tracks. Each track is a set of tasks that:
- Have no dependencies on tasks in other tracks
- Can be worked on independently without merge conflicts
- Touch different areas of the codebase (check Key Files for overlap)

**Track assignment algorithm:**

```
1. Build adjacency graph from Blocked by / Blocks fields
2. Find connected components — tasks linked by dependencies form a track
3. For independent tasks (no dependencies), assign to tracks by file proximity:
   - Group tasks that touch the same directories together
   - This minimizes merge conflicts between tracks
4. If any track has > 8 tasks, split by priority (high-priority tasks first)
5. If total tracks > 6, merge the smallest tracks
```

Name each track by its theme (e.g., "auth", "ui-polish", "data-pipeline", "engine").

### Step 3: Identify Merge Points

For tracks with inter-track dependencies:
1. Identify the earliest task in Track B that depends on a task in Track A
2. That dependency defines a **merge point** — Track A must merge before Track B can proceed past that task
3. Document merge points in the track plan

For fully independent tracks: no merge points needed — merge at the end.

### Step 4: Detect File Conflicts

Cross-reference Key Files across all tracks:

```
For each file mentioned in any task's Key Files:
  Count how many tracks touch that file
  If > 1 track → flag as CONFLICT RISK
```

Present conflict risks to the user. Options:
- Move conflicting tasks to the same track
- Accept the risk (manual merge resolution later)
- Reorder tasks so conflicting changes happen sequentially

### Step 5: Present the Track Plan

```
SWARM TRACKS
═══════════════════════════════════════════════════

{N} tasks grouped into {M} parallel tracks:

Track A: {theme}  ({N} tasks)
  Session prompt: "Work on {theme}: {task list}"
  Tasks:
    XX: {title} [priority] [complexity]
    XX: {title} [priority] [complexity] — blocked by XX
  Key directories: src/auth/, src/middleware/

Track B: {theme}  ({N} tasks)
  Session prompt: "Work on {theme}: {task list}"
  Tasks:
    XX: {title} [priority] [complexity]
    XX: {title} [priority] [complexity]
  Key directories: src/ui/, src/components/

Track C: {theme}  ({N} tasks)
  ...

─────────────────────────────────────────────────

Merge Strategy:
  Track A and B: independent — merge when done
  Track C: merge AFTER Track A (Task XX depends on Task YY)

File Conflict Risks:
  src/types/index.ts — touched by Track A (Task XX) and Track B (Task YY)
  Suggestion: Both tracks add types — low conflict risk, merge should be clean

═══════════════════════════════════════════════════
```

Use AskUserQuestion:
- "Looks good — generate scripts" → Proceed to Step 6
- "Adjust tracks" → User specifies changes (via free text)
- "Too risky, skip" → Exit without generating

### Step 6: Generate Setup Script

Write `scripts/setup-swarm.sh` in the project root:

```bash
#!/bin/bash
set -e

# Swarm Tracks Setup
# Generated by Metis /swarm-tracks
# Run this script to create git worktrees for parallel development

MAIN_BRANCH=$(git branch --show-current)

echo "Setting up swarm tracks from branch: $MAIN_BRANCH"
echo ""

# Create worktrees
{for each track}
echo "Creating worktree: track-{theme}..."
git worktree add ../$(basename $(pwd))-track-{theme} -b swarm/{theme} $MAIN_BRANCH
cp -r .metis ../$(basename $(pwd))-track-{theme}/.metis
echo "  Branch: swarm/{theme}"
echo "  Directory: ../$(basename $(pwd))-track-{theme}"
echo ""
{end for}

echo ""
echo "Worktrees created. Open a new terminal for each track:"
echo ""
{for each track}
echo "  Track {letter}: cd ../$(basename $(pwd))-track-{theme}"
echo "    Then run: /swarm    (or /task for interactive mode)"
echo ""
{end for}
echo "When all tracks are done, run: /swarm-tracks teardown"
```

### Step 7: Generate Track Documentation

Write `scripts/SWARM_TRACKS.md` in the project root:

```markdown
# Swarm Tracks

*Generated by Metis on YYYY-MM-DD*

## Tracks

### Track A: {theme}
- **Branch:** `swarm/{theme}`
- **Directory:** `../{project}-track-{theme}`
- **Tasks:** {XX, XX, XX}
- **Session prompt:** "{detailed prompt for this track}"
- **Key directories:** {dirs}

### Track B: {theme}
...

## Merge Strategy

{merge order and merge points}

## Session Prompts

Copy-paste these into each Claude Code session:

### Track A: {theme}
```
You are working on Track A: {theme}.
Your tasks (in order): {task numbers and titles}.
{dependency instructions if any}

IMPORTANT:
- Only modify files in: {key directories}
- Do NOT touch files outside your track's scope
- If you need to modify a shared file, note it for manual merge
```

### Track B: {theme}
...

## File Conflict Risks

| File | Tracks | Risk Level | Notes |
|------|--------|------------|-------|

## Teardown

When all tracks are complete:
```bash
/swarm-tracks teardown
```
Or manually:
```bash
git worktree remove ../project-track-{theme}
git branch -d swarm/{theme}
```
```

### Step 8: Report

```
SWARM TRACKS READY
═══════════════════════════════════════════════════

Generated:
  scripts/setup-swarm.sh    — Run to create worktrees
  scripts/SWARM_TRACKS.md   — Track docs and session prompts

Next steps:
  1. Run: bash scripts/setup-swarm.sh
  2. Open {N} terminal windows
  3. In each terminal, cd to the track directory and run /swarm or /task
  4. When done: /swarm-tracks teardown

═══════════════════════════════════════════════════
```

---

## Check Status (`/swarm-tracks status`)

1. List existing git worktrees: `git worktree list`
2. For each worktree that matches the `track-*` pattern:
   - Check the branch name
   - Count tasks in `.metis/tasks/todo/`, `doing/`, `done/` in that worktree
   - Show progress

```
SWARM TRACKS STATUS
═══════════════════════════════════════════════════

Track A: {theme}  [swarm/{theme}]
  Directory: ../{project}-track-{theme}
  Progress: {done}/{total} tasks complete
  Status: {active|idle|done}

Track B: {theme}  [swarm/{theme}]
  Directory: ../{project}-track-{theme}
  Progress: {done}/{total} tasks complete
  Status: {active|idle|done}

Main branch: {branch}
  Tasks here: {N} todo / {N} doing / {N} done

═══════════════════════════════════════════════════

{If all tracks done:}
All tracks complete. Run /swarm-tracks teardown to merge and clean up.
```

---

## Teardown (`/swarm-tracks teardown`)

Guide the user through merging track branches and cleaning up worktrees.

### Step 1: Check Track Status

1. List worktrees: `git worktree list`
2. For each track worktree, check if tasks remain in `todo/` or `doing/`
3. If any track has incomplete work → warn the user before proceeding

### Step 2: Present Merge Plan

```
SWARM TRACKS TEARDOWN
═══════════════════════════════════════════════════

Merge order (respecting dependencies):

  1. swarm/{theme-a} → main  ({N} commits)
  2. swarm/{theme-b} → main  ({N} commits, rebase on updated main)
  3. swarm/{theme-c} → main  ({N} commits, rebase on updated main)

Incomplete tracks (will NOT be merged):
  swarm/{theme-d} — 2 tasks still in todo/

═══════════════════════════════════════════════════

Proceed with merge?
```

Use AskUserQuestion:
- "Merge all complete tracks" → Execute merge sequence
- "Just clean up worktrees" → Remove worktrees without merging
- "Cancel" → Exit

### Step 3: Execute Merge

For each track in merge order:

```bash
# Switch to main
git checkout main

# Merge the track branch
git merge swarm/{theme} --no-ff -m "Merge swarm track: {theme}"

# Remove the worktree
git worktree remove ../project-track-{theme}

# Delete the branch
git branch -d swarm/{theme}
```

If merge conflicts occur:
1. Stop and show the conflict
2. Let the user resolve manually
3. After resolution, continue with remaining tracks

### Step 4: Clean Up

```bash
# Remove generated scripts
rm -f scripts/setup-swarm.sh scripts/SWARM_TRACKS.md

# Prune worktree list
git worktree prune
```

Report completion:

```
TEARDOWN COMPLETE
═══════════════════════════════════════════════════

Merged {N} tracks into main.
Removed {N} worktrees and branches.
Cleaned up generated scripts.

All track work is now on main.

═══════════════════════════════════════════════════
```

---

## Rules

<rules>
- NEVER automatically execute the setup script — always present it for user review first
- NEVER merge branches without explicit user approval
- NEVER force-delete branches (use -d, not -D) — let git protect unmerged work
- Always check for incomplete tasks before teardown — warn about data loss
- Track branches use the `swarm/` prefix for easy identification
- Copy `.metis/` to each worktree so tasks and config are available
- Generated scripts go in `scripts/` — create the directory if needed
- Session prompts must include explicit file scope boundaries to minimize conflicts
- If the backlog has < 4 tasks, suggest using regular `/swarm` instead — worktree overhead isn't worth it
</rules>
