---
name: ios-qa
description: Spec-driven visual QA that reads task specs and verifies each acceptance criterion through the UI. Opinionated — flags anything a real user would complain about. Fixes simple issues, escalates complex ones, stops on blockers.
argument-hint: <task# | smoke | full | --from-pr PR#|branch>
allowed-tools:
  - Skill
  - Write
  - Read
  - Grep
  - Glob
  - Edit
  - mcp__ios-simulator__ui_view
  - mcp__ios-simulator__ui_describe_all
  - mcp__ios-simulator__ui_tap
  - mcp__ios-simulator__ui_swipe
  - mcp__ios-simulator__screenshot
  - mcp__ios-simulator__get_booted_sim_id
  - mcp__ios-simulator__launch_app
  - Bash(curl:*)
  - Bash(sleep:*)
  - Bash(gh:*)
  - Bash(git:*)
disable-model-invocation: false
---

# ios-qa — Spec-Driven Visual QA

**Spec-driven QA: Read the spec → Verify each criterion through the UI → Flag what users would hate.**

## Configuration (read this first)

Before doing anything else, load the project config. Skills in this plugin are app-agnostic — they expect a config file or env vars.

**Load order:**

1. Read `.claude/ios-qa.json` if it exists.
2. Override any present key with env vars: `IOS_QA_BUNDLE_ID`, `IOS_QA_APP_NAME`, `IOS_QA_METRO_URL`, `IOS_QA_DEFAULT_BRANCH`.
3. If `bundleId` is still missing, stop with:

   ```
   ios-qa is not configured. Create .claude/ios-qa.json with at least
   { "bundleId": "...", "appName": "..." }. See the plugin README.
   ```

**Keys you'll use throughout this skill:**

| Key | Default | Used for |
|-----|---------|----------|
| `bundleId` | (required) | `mcp__ios-simulator__launch_app(bundle_id=…)` |
| `appName` | (required) | report headings, PR comments |
| `metroUrl` | `http://localhost:8081/status` | bundler readiness probe |
| `metroReadyMarker` | `packager-status:running` | substring to look for in response |
| `defaultBranch` | `main` | diff scope, rebase target |
| `taskDir` | `.metis/tasks` | spec lookup |
| `smokeScreens` | `[]` | smoke mode + on-branch baseline |
| `fileToScreenMap` | `{}` | PR/branch scope mapping |

Treat the config as immutable for the duration of one run. If a key is missing and has no default, mark the dependent feature as "skipped — not configured" in the report rather than crashing.

## Modes

1. **Spec mode** (`/ios-qa <task-number>`) — Reads the task spec, extracts acceptance criteria, and verifies each one through the simulator. Primary mode.
2. **General mode** (`/ios-qa`, `/ios-qa smoke`, `/ios-qa full`) — Scans screens without a spec. Still applies the User Complaint Filter.
3. **PR/Branch mode** (`/ios-qa --from-pr <PR#|branch>`) — Checks out a PR or branch, lets the bundler hot-reload, runs QA focused on changed screens.
4. **On-branch mode** (`/ios-qa --on-branch <branch> --screens <list>`) — Runs QA on a branch already checked out, scoped to a comma-separated screen list. Output goes to stdout only; never posts a PR comment.

All modes apply the **User Complaint Filter** — a hard blocker list of things that are objectively bad UX. If any are found, QA stops and demands a fix before proceeding.

```
1. LOAD SPEC — Read task file, extract acceptance criteria
2. PLAN — Map each criterion to screens and UI assertions
3. VERIFY — Navigate, screenshot, check each criterion pass/fail
4. COMPLAIN — Apply opinionated UX filter on every screen visited
5. FIX/ESCALATE — Fix simple issues, escalate complex ones
6. REPORT — Final spec verification matrix
```

### Spec Mode: `/ios-qa <task-number>`

Reads a completed task spec and verifies it was implemented correctly.

```
/ios-qa 130
/ios-qa 126
```

**How it works:**

1. Read `<taskDir>/done/<number>-*.md` (or `doing/`, then `todo/`)
2. Parse the acceptance-criteria checklist (lines matching `- [ ]` / `- [x]`)
3. Classify each criterion as **UI**, **Behavior**, **Code**, or **Non-verifiable**
4. For UI/Behavior criteria: navigate, screenshot, verify
5. For Code criteria: verify via Grep/Read (e.g., "All types pass tsc")
6. Output a pass/fail matrix at the end

### General Mode: `/ios-qa [full|smoke]`

```
/ios-qa            # default scan + opinionated checks
/ios-qa full       # every screen + scroll + sub-views
/ios-qa smoke      # app launches, tabs load, one modal
```

### PR/Branch Mode: `/ios-qa --from-pr <PR#|branch>`

Checks out a PR or branch, waits for the bundler to hot-reload, then runs targeted QA on the affected screens. Assumes the bundler is already running in another terminal.

```
/ios-qa --from-pr 185       # numeric → PR #185, posts report as PR comment
/ios-qa --from-pr feat/xyz  # branch name → output to terminal (no PR comment)
```

## Core Principles

1. **The spec is the test oracle.** In spec mode, acceptance criteria ARE your test cases. Don't invent extra checks.
2. **Be the user, not the developer.** Pretend you just downloaded this app. Does it look professional? Can you figure out what to do? Does anything look broken?
3. **Blockers stop everything.** Tier 1/2 issues halt the scan until fixed.
4. **Every screenshot gets analyzed.** Output a Mandatory Analysis Block after every `ui_view`.
5. **Verify every fix** with `ui_view` + `ui_describe_all` + analysis block.

## The User Complaint Filter

Things a real user would immediately notice and complain about. If you see ANY of these, it's a BLOCKER.

### Tier 1: Instant Uninstall (CRITICAL)

| Issue | What It Looks Like | Why Users Hate It |
|-------|-------------------|-------------------|
| **Broken layout** | Elements overlapping, content spilling off-screen, stacked cards | "This app is broken" |
| **Blank screen** | Nothing visible — no content, no loading indicator, no empty state | "Is this even working?" |
| **Unreadable text** | Too small, low contrast, same color as background, clipped | "I can't read anything" |
| **Dead buttons** | Tap something interactive and nothing happens | "Nothing works" |
| **Trapped state** | Modal or screen with no way to dismiss | "I'm stuck" |
| **Crash or freeze** | App stops responding | "Garbage app" |
| **Raw data values** | `NaN`, `undefined`, `null`, `[object Object]`, raw ISO dates | "This is a dev build" |

### Tier 2: One-Star Review (HIGH)

| Issue | What It Looks Like |
|-------|-------------------|
| **Placeholder content** | "Lorem ipsum", "TODO", "Test", "asdf" |
| **Inconsistent spacing** | 16px padding here, 8px there, 24px somewhere else |
| **Misaligned elements** | Text not vertically centered, icons at different heights |
| **Wrong empty state** | Empty list with no message — just blank space |
| **Truncated labels** | "FruitTe...", "$12,345.6" with the last digit missing |
| **Giant empty space** | Huge gap in the middle of a screen for no reason |
| **Scroll doesn't work** | Content continues below the fold but can't be scrolled to |
| **Inconsistent visual language** | Some rounded, some square; mixed icon styles; different cards |
| **Wrong numbers** | $0.00 for a real price, 0% change when the market clearly moved |

### Tier 3: Friction (MEDIUM)

| Issue | What It Looks Like |
|-------|-------------------|
| **Tiny touch targets** | Buttons smaller than 44×44pt |
| **No loading feedback** | Action triggered but no spinner, skeleton, or indication |
| **Inconsistent formatting** | Mixing "Jan 5" and "2020-01-05" on the same screen |
| **Orphaned elements** | A single item in a list, section header with nothing under it |
| **Scroll position reset** | Navigate away and back, scroll position lost |

### How to Apply the Filter

On EVERY screenshot, mentally ask:

> "If I just downloaded this app and saw this screen, what would I complain about?"

Tier 1 or 2 → BLOCKERS. Tier 3 → ISSUES.

## Mandatory Analysis Block

After every `ui_view` call, output this block BEFORE taking any other action:

```
SCREEN: [screen name]
OBSERVED: [factual description of what the screenshot shows — not what you expect]
STRUCTURAL: [ui_describe_all summary — element count, key elements present/missing]
SPEC CHECK: [if in spec mode: which criteria this screen covers, pass/fail each]
BLOCKERS: [Tier 1 or 2 User Complaint items — or "none"]
ISSUES: [Tier 3 items or minor issues — or "none"]
ACTION: [what to do next]
```

**Rules:**
- OBSERVED must describe what you **actually see**, not what you expect.
- SPEC CHECK only in spec mode. List each criterion + status.
- BLOCKERS trigger an immediate stop — fix/escalate before continuing.
- If the screen scrolls, output a SECOND block for below-fold content.

## Spec Mode Workflow

> The phases below use pseudocode to describe the algorithm. Implement each step using Claude Code tools (Glob, Read, Grep, Bash, etc.).

### PHASE 0: Load Spec + Prerequisites

```python
# 1. Load config (see Configuration section)
config = load_config()
bundle_id = config["bundleId"]
task_dir = config.get("taskDir", ".metis/tasks")
metro_url = config.get("metroUrl", "http://localhost:8081/status")
metro_marker = config.get("metroReadyMarker", "packager-status:running")

# 2. Find and read the task spec
task_number = $ARGUMENTS  # e.g., "130"
spec = None
for sub in ["done", "doing", "todo"]:
    files = Glob(f"{task_dir}/{sub}/{task_number}-*.md")
    if files:
        spec = Read(files[0])
        break
if not spec:
    STOP(f"Task {task_number} not found in {task_dir}/")

# 3. Parse acceptance criteria
criteria = extract_checkboxes(spec)  # Lines matching "- [ ]" or "- [x]"

# 4. Classify each criterion
for criterion in criteria:
    criterion.type = classify(criterion)
    # "ui" → screenshot verification
    # "code" → Grep/Read verification
    # "behavior" → interaction + screenshot
    # "non-verifiable" → skip (e.g., "no performance issues")

# 5. Read Screen Designs section (if present) for expected layout
screen_designs = extract_screen_designs(spec)

# 6. Check prerequisites (bundler + simulator)
status = Bash(f"curl -s {metro_url}")
if metro_marker and metro_marker not in status:
    STOP(f"Bundler not ready at {metro_url}")
sim_id = mcp__ios-simulator__get_booted_sim_id()
mcp__ios-simulator__launch_app(bundle_id=bundle_id)
Bash("sleep 3")
```

### PHASE 1: Plan Verification

Map each criterion to a concrete verification plan. Group by screen to minimize navigation.

```python
criteria_plan = [
    {
        "criterion": "...",
        "type": "ui" | "behavior" | "code" | "non-verifiable",
        "verify": "what to look for / do",
        "screen": "Screen name",
        "prerequisite": "optional app state requirement",
    },
    ...
]

print("## Verification Plan")
print(f"Task: {task_number}")
print(f"Total criteria: {len(criteria)}")
print(f"  UI-verifiable: {count_by_type('ui')}")
print(f"  Behavior: {count_by_type('behavior')}")
print(f"  Code-only: {count_by_type('code')}")
print(f"  Non-verifiable: {count_by_type('non-verifiable')}")
```

### PHASE 2: Verify Each Criterion

```python
results = {}

for screen, screen_criteria in group_by_screen(criteria_plan):
    navigate_to_screen(screen)
    Bash("sleep 1")

    mcp__ios-simulator__ui_view()
    elements = mcp__ios-simulator__ui_describe_all()

    # Output Mandatory Analysis Block (with SPEC CHECK)

    for criterion in screen_criteria:
        if criterion.type == "ui":
            results[criterion.id] = verify_visual(criterion, elements, screenshot)
        elif criterion.type == "behavior":
            perform_interaction(criterion)
            Bash("sleep 1")
            mcp__ios-simulator__ui_view()
            results[criterion.id] = verify_visual(criterion, elements, screenshot)

    blockers = apply_complaint_filter(screenshot, elements)
    if blockers:
        for blocker in blockers:
            fix_or_escalate(blocker)

for criterion in code_only_criteria:
    if "tsc" in criterion.text:
        results[criterion.id] = "SKIP (run typecheck separately)"
    else:
        results[criterion.id] = verify_code(criterion)
```

### PHASE 3: Fix / Escalate

Fix simple issues directly; escalate complex ones to `/ios-fixer`.

| Failure Type | Action |
|--------------|--------|
| Feature not implemented (no code exists) | Report as **NOT IMPLEMENTED** |
| Feature implemented but not rendered | Escalate to ios-fixer |
| Feature rendered but looks wrong (style) | Fix directly (Edit) |
| Feature rendered but data is wrong | Check store/hook logic → escalate if complex |
| User Complaint Blocker | Fix directly if simple, escalate if complex |

### PHASE 4: Report

```markdown
# QA Report: Task <number> — <title>

## Spec Verification

| # | Criterion | Type | Result | Notes |
|---|-----------|------|--------|-------|
| 1 | ... | UI | PASS | ... |
| 2 | ... | UI | FAIL | ... |

**Result: X/Y PASS, N FAIL, M SKIP**

## User Complaint Blockers Found

1. **CRITICAL: ...** — Fixed: [yes/no] → [description]

## Issues (non-blocking)

1. ... — Fixed: [yes/no]

## Screens Scanned: N
## Fixes Applied: N
## Escalated: N
```

## PR/Branch Mode Workflow

> Pseudocode below. Implement each step with Claude Code tools — no inline Python.

> **No command substitution.** Never use `$()` or backticks. Use separate tool calls and read outputs in subsequent commands.

### PHASE 0: Parse, Checkout & Sync

```python
config = load_config()
default_branch = config.get("defaultBranch", "main")
bundle_id = config["bundleId"]
metro_url = config.get("metroUrl", "http://localhost:8081/status")
metro_marker = config.get("metroReadyMarker", "packager-status:running")

# 1. Parse the --from-pr argument
raw_arg = $ARGUMENTS.replace("--from-pr", "").strip()  # "185", "#185", "feat/xyz"
raw_arg_clean = raw_arg.lstrip("#")
if raw_arg_clean.isdigit():
    pr_number = int(raw_arg_clean)
    is_pr = True
    pr_info = Bash(f"gh pr view {pr_number} --json title,body,headRefName,number,url")
    branch = pr_info["headRefName"]
    pr_title = pr_info["title"]
    pr_url = pr_info["url"]
else:
    branch = raw_arg
    is_pr = False
    pr_number = None

# 2. Skip-if-already-reviewed (no new commits since last QA comment)
if is_pr:
    last = Bash(f"gh api repos/:owner/:repo/issues/{pr_number}/comments --jq '[ .[] | select(.body | contains(\"ios-qa-bot\")) ] | last'")
    if last and last != "null":
        last_review_date = last["created_at"]
        pr_updated = Bash(f"gh pr view {pr_number} --json updatedAt --jq '.updatedAt'")
        if pr_updated <= last_review_date:
            print(f"PR #{pr_number} already reviewed (no new commits). Skipping.")
            STOP()
        else:
            print(f"PR #{pr_number} has new commits. Re-reviewing.")

# 3. Save current branch for restoration
original_branch = Bash("git branch --show-current").strip()

# 4. Create a -qa branch from the target
qa_branch = f"{branch}-qa"

# Delete ALL stale -qa branches from previous runs
stale_branches = Bash("git branch --list '*-qa'")
# For each line in stale_branches, run: Bash(f"git branch -D {name}")

Bash(f"git fetch origin {branch}")
Bash(f"git checkout -b {qa_branch} origin/{branch}")

# 5. Wait for the bundler to finish rebundling (poll, not blind sleep)
# Poll metro_url every second, up to 15 attempts.
# Look for metro_marker in the response (or skip the marker check if marker == "").
# After 15 failed attempts: STOP("Bundler did not become ready within 15 seconds")

# 6. Launch app and settle
sim_id = mcp__ios-simulator__get_booted_sim_id()
mcp__ios-simulator__launch_app(bundle_id=bundle_id)
Bash("sleep 2")
```

> **Error recovery:** If ANY phase below fails, ALWAYS skip to PHASE 3 cleanup. Never leave the repo on a `-qa` branch.

### PHASE 1: Determine Scope

```python
# 1. Get changed files
if is_pr:
    changed_files = Bash(f"gh pr diff {pr_number} --name-only")
else:
    changed_files = Bash(f"git diff {default_branch} --name-only")

# 1b. Native changes? skip (can't hot-reload native code)
native_patterns = ["ios/", "android/", "app.json", "Podfile.lock", "package-lock.json"]
has_native = any(p in changed_files for p in native_patterns)
if has_native:
    if is_pr:
        body = "<!-- ios-qa-bot -->\n⏭ QA skipped — native changes detected. Needs manual rebuild before visual QA can run."
        Bash(f"gh pr comment {pr_number} --body '{body}'")
        print(f"PR #{pr_number} has native changes. Posted skip comment.")
    else:
        print("Branch has native changes. Skipping visual QA — needs rebuild.")
    GOTO_CLEANUP()

# 2. Map changed files to affected screens using fileToScreenMap from config
file_to_screen = config.get("fileToScreenMap", {})
affected_screens = []
for changed in changed_files:
    for pattern, screen in file_to_screen.items():
        if pattern in changed:  # substring match — simple and predictable
            if screen not in affected_screens:
                affected_screens.append(screen)

# 3. Extract task number from PR title/body or branch name
task_number = None
if is_pr:
    task_number = extract_task_number(pr_title, pr_info["body"], branch)
else:
    task_number = extract_task_number_from_branch(branch)

# 4. Decide QA mode
if task_number:
    qa_mode = "spec"
elif affected_screens:
    qa_mode = "general-targeted"
else:
    qa_mode = "smoke"  # fallback when no mapping matched
```

### PHASE 2: Run QA

```python
if qa_mode == "spec":
    report = run_spec_mode(task_number)
elif qa_mode == "general-targeted":
    report = run_general_mode(screens=affected_screens)
elif qa_mode == "smoke":
    report = run_general_mode(mode="smoke")
```

### PHASE 3: Deliver Report & Cleanup

> This phase MUST run even if earlier phases failed. Branch restoration is mandatory.

```python
# --- Report ---
has_fixes = Bash(f"git log origin/{branch}..HEAD --oneline")
if has_fixes:
    Bash(f"git push origin {qa_branch}")

if is_pr:
    comment_body = format_pr_comment(report, branch, affected_screens, qa_branch, has_fixes)
    # First line MUST be the marker for dedup
    Bash(f"gh pr comment {pr_number} --body '{comment_body}'")
    print(f"QA report posted to PR #{pr_number}: {pr_url}")
else:
    print(report)

# --- Cleanup (ALWAYS runs) ---
current_branch = Bash("git branch --show-current")
if current_branch != original_branch:
    Bash(f"git checkout {original_branch}")
print(f"Restored to {original_branch}")

if not has_fixes:
    Bash(f"git branch -D {qa_branch} 2>/dev/null || true")
    print(f"Cleaned up {qa_branch} (no fixes)")
else:
    print(f"QA fixes on branch: {qa_branch}")
```

## On-Branch Mode Workflow

For use by external orchestrators (e.g., a merge-train flow) or manual invocation: QA a branch already checked out, scoped to specific screens.

### PHASE 0: Verify Prereqs (No Checkout)

```python
config = load_config()
bundle_id = config["bundleId"]
metro_url = config.get("metroUrl", "http://localhost:8081/status")
metro_marker = config.get("metroReadyMarker", "packager-status:running")

# Example: "--on-branch fixup/2026-04-24 --screens Market,Portfolio"
branch = extract_flag_value($ARGUMENTS, "--on-branch")
screens_csv = extract_flag_value($ARGUMENTS, "--screens")
screens = [s.strip() for s in screens_csv.split(",")]

current = Bash("git branch --show-current").strip()
if current != branch:
    STOP(f"On-branch mode requires {branch} to be checked out. Currently on: {current}")

status = Bash(f"curl -s {metro_url}")
if metro_marker and metro_marker not in status:
    STOP(f"Bundler not ready at {metro_url}")
sim_id = mcp__ios-simulator__get_booted_sim_id()
if not sim_id:
    STOP("No simulator booted.")
mcp__ios-simulator__launch_app(bundle_id=bundle_id)
Bash("sleep 3")
```

### PHASE 1: Targeted Scan

```python
# Always include the smoke baseline before targeted screens
smoke_screens = config.get("smokeScreens", [])
all_screens = list(dict.fromkeys(smoke_screens + screens))  # dedupe, preserve order

for screen in all_screens:
    navigate_to_screen(screen)
    Bash("sleep 1")
    mcp__ios-simulator__ui_view()
    elements = mcp__ios-simulator__ui_describe_all()
    # Output Mandatory Analysis Block
    # Apply User Complaint Filter
    # Tier 1/2 blockers: fix directly, commit on current branch
    # Complex issues: escalate to ios-fixer
```

### PHASE 2: Deliver Report

```python
report = format_report(results, screens_scanned=all_screens, fixes_applied=fixes)
print(report)

default_branch = config.get("defaultBranch", "main")
fixes_committed = Bash(f"git log origin/{default_branch}..HEAD --oneline").strip()
if fixes_committed:
    print(f"\n{len(fixes_committed.splitlines())} fix commit(s) on {branch}:")
    print(fixes_committed)

# Caller owns branch state. Do NOT checkout away. Do NOT push.
```

**Differences from PR/Branch mode:**

| Aspect | PR/Branch | On-branch |
|--------|-----------|-----------|
| Checkout | Creates `<branch>-qa` | None — assumes already checked out |
| Scope | Auto-detected from changed files | Caller-provided via `--screens` |
| Report | PR comment (if PR) | stdout only |
| Branch restoration | Yes | No — caller manages |
| Fix push | Optional | Never |

## PR Comment Template

```markdown
<!-- ios-qa-bot -->
## QA Report — <appName>

**Branch:** `<branch-name>`
**Screens tested:** <comma-separated list>
**Mode:** <spec (task #N) | general-targeted | smoke>

### Results

<spec verification table OR screen-by-screen scan>

### Blockers

<numbered list of Tier 1/2 blockers, or "None found">

### Issues (non-blocking)

<numbered list of Tier 3 issues, or "None found">

### Summary

**Result:** X/Y PASS, N FAIL, M SKIP
**Screens scanned:** N
**Fixes applied:** N (describe each briefly)
**Escalated:** N

<if fixes were pushed: include this section>
### QA Fixes Branch

Fixes have been pushed to `<branch>-qa`. Cherry-pick or merge to apply:

    git cherry-pick <commit1> <commit2> ...
    # or
    git merge <branch>-qa
</if>

---
*Automated QA by ios-qa*
```

## Fixing Issues on the QA Branch

The `-qa` branch is your workspace. **Fix everything. Don't just report — fix.**

1. **Fix it** — read the code, understand the bug, write the fix.
2. **Verify it** — screenshot after hot-reload to confirm.
3. **Continue** — keep going until done or blocked.
4. **Commit** — each fix gets its own commit with a descriptive message.

Only escalate to `ios-fixer` if the bug is genuinely beyond a targeted style fix (e.g., native module crash, complex animation issue).

**QA is not done until the entire flow works end-to-end.** Don't stop at the first blocker — fix it, verify, keep going.

After QA completes:
- Push the `-qa` branch.
- Post a PR comment summarizing what was fixed (not just what was found).
- The PR author cherry-picks or merges.

## General Mode Workflow

When no task number is given, scan screens and apply the User Complaint Filter.

**Smoke** (`/ios-qa smoke`): launch + each tab + one detail screen.
**Default** (`/ios-qa`): smokeScreens + opinionated checks.
**Full** (`/ios-qa full`): every screen + scroll + sub-views.

Both default and full modes derive the scan list from `smokeScreens` + any extra screens implied by the configured `fileToScreenMap`. If neither is configured, fall back to: launch, then walk through whatever tabs and top-level screens are visible.

### File → Screen Mapping

The mapping lives in your project's `.claude/ios-qa.json`:

```json
{
  "fileToScreenMap": {
    "src/screens/Home.tsx": "Home",
    "src/screens/Market.tsx": "Market",
    "src/components/Card.tsx": "Home",
    "src/stores/marketStore.ts": "Market"
  }
}
```

Substring match against the changed-file path. The first matching pattern wins; if a file matches multiple, both screens are added. The skill stays consistent if the mapping is empty — it just falls back to smoke mode.

## Spec Parsing Rules

Task specs in `<taskDir>` are expected to follow a consistent markdown format.

### Acceptance Criteria

Lines matching `- [ ]` or `- [x]` under the `## Acceptance Criteria` heading. Parse the text after the checkbox; each line is one criterion.

### Screen Designs

ASCII-art blocks under `## Screen Designs` or `## Visual Design`. Use as **expected layout references** when comparing against actual screenshots.

### Technical Details

The `## Technical Details` section, if present, lists files created/modified. Use to:
- Know where to Grep if a feature looks missing.
- Know what components to expect in the UI tree.

### Requirements

The `## Requirements` section is human-readable and more detailed than acceptance criteria. Cross-reference for ambiguous criteria.

## Classifying Criteria

| Type | Example | How to Verify |
|------|---------|---------------|
| **UI** | "Tournament screen accessible from lobby" | Navigate + screenshot |
| **Behavior** | "Enter Tournament starts game with fixed parameters" | Tap + verify resulting screen |
| **Code** | "All types pass `tsc --noEmit`" | Run typecheck or Grep |
| **Data** | "Player's own entry highlighted in leaderboard" | Requires specific app state — try to set up, or SKIP |
| **Non-verifiable** | "No performance issues" | Can't verify in screenshot — SKIP |

If you can't set up the required state, SKIP with a clear note rather than guessing.

## Opinionated Checks on EVERY Screen

### The 30-Second Test

For each screen, answer 5 questions in 30 seconds. If any answer is "no", it's a problem:

1. **Can I tell what this screen is for?**
2. **Can I read everything?**
3. **Do I know what to do next?**
4. **Does this look finished?**
5. **Does this match the rest of the app?**

### Comparison Checks

When scanning multiple screens, compare:
- **Card consistency** — same border radius, padding, shadow, font sizes
- **Section spacing** — uniform gaps (or deliberately varied)
- **Header style** — same font size, weight, position
- **Empty state pattern** — same style of empty-state message
- **Number formatting** — same currency, percent, date format throughout

## Safety Guards

**NEVER RESTART THE BUNDLER OR SIMULATOR**
- Scanning is read-only (navigate + screenshot + describe).
- All fixes via code edits that hot-reload.
- Never touch the bundler, Metro, or simulator process.

**Loop Control:**
- Loop if re-scan finds fewer issues than previous scan (progress).
- Stop if re-scan finds same or more issues (no progress).
- Absolute cap: 5 re-scan loops.
- Stop immediately if a fix introduces a NEW issue.

**Code Safety:**
- Direct fixes are targeted single-Edit operations.
- Every fix is verified with `ui_view` + `ui_describe_all` + analysis block.
- Complex bugs are escalated to `ios-fixer`.

**Bash Safety:**
- NEVER use `#` comments inside inline shell/Python one-liners passed to Bash — the `#` after a newline triggers permission prompts.
- If you need complex logic, write a small temp script first, then execute.
- Keep Bash commands simple and single-purpose.

**Spec Safety:**
- Never modify the task spec file (it's the test oracle).
- If a criterion is ambiguous, note it — don't interpret generously.
- If a feature isn't implemented, say so directly — don't soften it.

## Examples

See [examples.md](examples.md) for three worked examples: Spec Mode, PR Mode, and General Mode runs.

## When to Use Each Skill

| Situation | Use This |
|-----------|----------|
| Verify a completed task through the UI | `/ios-qa <task-number>` |
| General visual QA + opinionated checks | `/ios-qa` or `/ios-qa full` |
| Quick health check | `/ios-qa smoke` |
| QA a PR and post findings as PR comment | `/ios-qa --from-pr 185` |
| QA a branch (no PR comment) | `/ios-qa --from-pr feat/xyz` |
| QA a branch already checked out, scoped to screens | `/ios-qa --on-branch feat/x --screens "Home,Market"` |
| Iterate every open PR | `/qa-batch` |
| Enter/exit a manual QA session | `/qa <PR# \| branch>` |
| Deep-dive a specific bug | `/ios-fixer "description"` |
