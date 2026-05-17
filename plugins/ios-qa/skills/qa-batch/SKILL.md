---
name: qa-batch
description: Batch QA open PRs — visual QA + deep code review, posts findings as PR comments, and auto-labels `ready` on clean PRs. Run before stepping away.
argument-hint: "[PR#...] [--dry-run] [--no-label]"
allowed-tools:
  - Skill
  - Read
  - Grep
  - Glob
  - Write
  - Edit
  - Bash(curl:*)
  - Bash(sleep:*)
  - Bash(gh:*)
  - Bash(git:*)
  - mcp__ios-simulator__get_booted_sim_id
disable-model-invocation: true
---

# qa-batch — Batch QA for Open PRs

**On-demand batch QA: kick off before stepping away. Come back to PR comments.**

`/qa-batch` iterates open PRs, runs visual QA + code review on each, and posts combined findings as PR comments. It does NOT apply fixes — it reports what it would fix and waits for your approval. Clean PRs (no blockers) are auto-labeled `ready`.

```
1. PREFLIGHT — Verify simulator + bundler running, clean git state
2. DISCOVER  — List open PRs, filter out already-reviewed + native-change
3. ITERATE   — For each PR: /ios-qa → deep code review → post comment → label if clean
4. SUMMARY   — Print batch results table
```

## Configuration

Reads the same `.claude/ios-qa.json` as the other skills. Fields used by qa-batch:

| Key | Default | Used for |
|-----|---------|----------|
| `bundleId` | (required by `/ios-qa`) | Passed through |
| `defaultBranch` | `main` | Diff scope |
| `metroUrl` | `http://localhost:8081/status` | Preflight |
| `metroReadyMarker` | `packager-status:running` | Preflight |
| `projectPitfalls` | `[]` | Code-review checklist entries unique to your project |

### `projectPitfalls`

A free-form list of project-specific checks to surface in the code-review comment. Each entry becomes a checkbox in the comment template. Use it to encode the project-specific gotchas a reviewer should always check. Examples:

```json
"projectPitfalls": [
  "No ES5 getters in persisted Zustand stores (breaks rehydration)",
  "Chart code: never fitContent() before setVisibleLogicalRange()",
  "Persistence uses MMKV, not AsyncStorage"
]
```

If the list is empty, the "Project-specific checks" section is omitted from review comments.

## Invocation

```bash
/qa-batch              # QA all open PRs
/qa-batch 241 242      # QA specific PRs only
/qa-batch --dry-run    # List what it would do, don't run
/qa-batch --no-label   # Skip auto-labeling
```

## Prerequisites

- iOS Simulator booted with your app running
- Bundler (Metro / equivalent) reachable at the configured `metroUrl`
- Clean git working tree
- `gh` CLI authenticated

---

## Workflow

> Pseudocode below. Implement each step with Claude Code tools — no inline Python execution.

> **No command substitution.** Never use `$()` or backticks. Use separate tool calls and read outputs in subsequent commands.

### PHASE 0: Preflight

```python
config = load_config()
metro_url = config.get("metroUrl", "http://localhost:8081/status")
metro_marker = config.get("metroReadyMarker", "packager-status:running")

# 1. Simulator booted?
sim_id = mcp__ios-simulator__get_booted_sim_id()
if not sim_id:
    STOP("No simulator running. Boot one first.")

# 2. Bundler running?
status = Bash(f"curl -s {metro_url}")
if metro_marker and metro_marker not in status:
    STOP(f"Bundler not running at {metro_url}.")

# 3. Clean git state?
dirty = Bash("git status --porcelain")
if dirty:
    STOP("Dirty working tree. Commit or stash before batch QA.")

# 4. Save restore point
original_branch = Bash("git branch --show-current").strip()

# 5. Clean up ALL stale -qa branches from previous runs
stale_branches = Bash("git branch --list '*-qa'")
# For each branch name in the output, run: Bash(f"git branch -D {name}")

# 6. Fetch latest
Bash("git fetch origin")

print(f"Preflight passed. On branch: {original_branch}")
```

### PHASE 1: Discover & Filter

```python
args = $ARGUMENTS  # e.g., "241 242", "--dry-run", "--no-label", ""
dry_run = "--dry-run" in args
no_label = "--no-label" in args
pr_numbers = [int(x) for x in args.split() if x.isdigit()]

# 1. List open PRs
prs = Bash("gh pr list --state open --json number,title,headRefName,updatedAt,labels")

# 2. Filter if specific PRs requested
if pr_numbers:
    prs = [pr for pr in prs if pr["number"] in pr_numbers]

# 3. Classify each PR
for pr in prs:
    # a) Already reviewed? Check for marker in comments.
    last = Bash(f"gh api repos/:owner/:repo/issues/{pr['number']}/comments --jq '[.[] | select(.body | contains(\"ios-qa-bot\"))] | last'")
    if last and last != "null":
        last_review_date = last["created_at"]
        pr_updated = pr["updatedAt"]
        # ISO timestamps compare correctly as strings
        if pr_updated <= last_review_date:
            pr["skip"] = "already reviewed (no new commits)"
            continue

    # b) Native changes?
    changed = Bash(f"gh pr diff {pr['number']} --name-only")
    native_patterns = ["ios/", "android/", "app.json", "Podfile.lock", "package-lock.json"]
    if any(p in changed for p in native_patterns):
        pr["skip"] = "native changes"
        body = "<!-- ios-qa-bot -->\n⏭ QA skipped — native changes detected. Needs manual rebuild."
        Bash(f"gh pr comment {pr['number']} --body '{body}'")
        continue

    pr["skip"] = None

eligible = [pr for pr in prs if not pr.get("skip")]
skipped = [pr for pr in prs if pr.get("skip")]

# 4. Print plan
print("## QA Batch Plan\n")
print("| PR | Title | Status |")
print("|----|-------|--------|")
for pr in prs:
    if pr.get("skip"):
        print(f"| #{pr['number']} | {pr['title']} | SKIP — {pr['skip']} |")
    else:
        print(f"| #{pr['number']} | {pr['title']} | WILL QA |")
print(f"\nEligible: {len(eligible)} | Skipped: {len(skipped)}")

if dry_run:
    print("\n--dry-run flag set. No QA will be performed.")
    STOP()

if not eligible:
    print("\nNo eligible PRs to QA. Done.")
    STOP()

# 5. Sort oldest-first
eligible = sorted(eligible, key=lambda p: p["updatedAt"])
```

### PHASE 2: Iterate

```python
results = []

for pr in eligible:
    print(f"\n{'='*60}")
    print(f"QA: PR #{pr['number']} — {pr['title']}")
    print(f"{'='*60}\n")

    try:
        # --- Step 1: Visual QA ---
        # /ios-qa handles checkout → bundler poll → screenshot → UX filter → PR comment → restore
        Skill("ios-qa", args=f"--from-pr {pr['number']}")

        # Verify ios-qa restored the branch
        current = Bash("git branch --show-current")
        if current != original_branch:
            print(f"WARNING: branch not restored. On {current}, expected {original_branch}")
            Bash(f"git checkout {original_branch}")

        # --- Step 2: Deep Code Review ---
        diff = Bash(f"gh pr diff {pr['number']}")
        changed_files_list = Bash(f"gh pr diff {pr['number']} --name-only")

        # Analyze the diff for:
        #
        # GENERAL PATTERNS:
        # - State management: avoid full-store subscriptions, use selectors with shallow equality
        # - Hook composition: hooks call stores; components call hooks (not stores directly)
        # - Memoization: expensive filters/maps wrapped in useMemo/useCallback
        # - Routing conventions (e.g., file-based routing)
        # - Security: no raw user input in queries, no secret leakage
        # - Performance: unnecessary re-renders, missing memoization, oversized component files
        #
        # PROJECT-SPECIFIC CHECKS:
        # config.projectPitfalls — render each entry as a checkbox in the review comment.
        #
        # REVIEW DEPTH:
        # - Store changes: DEEP review
        # - Hook changes: DEEP review
        # - Component changes: MEDIUM review (logic > layout)
        # - Style-only changes: QUICK scan
        # - Test changes: check coverage, not style

        review_comment = format_code_review_comment(pr, changed_files_list, diff_analysis, config.get("projectPitfalls", []))

        # --- Step 3: Post Code Review Comment ---
        Bash(f"gh pr comment {pr['number']} --body '{review_comment}'")

        # --- Step 4: Auto-label `ready` if both passes are clean ---
        if no_label:
            pr["labeled"] = "skipped (--no-label)"
        else:
            ios_qa_body = Bash(f"gh api repos/:owner/:repo/issues/{pr['number']}/comments "
                               f"--jq '[.[] | select(.body | test(\"<!-- ios-qa-bot -->\")) "
                               f"| select(.body | test(\"<!-- ios-qa-bot-review -->\") | not)] | last | .body'")
            visual_clean = "None found" in ios_qa_body.split("### Blockers", 1)[-1].split("###", 1)[0]
            review_clean = "❌" not in review_comment
            already_labeled = "ready" in [l["name"] for l in pr["labels"]]

            if visual_clean and review_clean and not already_labeled:
                Bash(f"gh pr edit {pr['number']} --add-label ready")
                pr["labeled"] = "✓ ready"
            elif already_labeled:
                pr["labeled"] = "already had"
            else:
                pr["labeled"] = "blockers"

        results.append({"pr": pr, "status": "reviewed"})
        print(f"✓ PR #{pr['number']} — visual QA + code review posted ({pr['labeled']})")

    except Exception as e:
        results.append({"pr": pr, "status": f"failed: {e}"})
        print(f"✗ PR #{pr['number']} — failed: {e}")

    finally:
        # ALWAYS return to original branch
        current = Bash("git branch --show-current")
        if current != original_branch:
            Bash(f"git checkout {original_branch}")
        Bash(f"git branch -D {pr['headRefName']}-qa 2>/dev/null || true")
```

### Code Review Comment Template

```markdown
<!-- ios-qa-bot-review -->
## Code Review

**PR:** #<number> — <title>
**Files reviewed:** <count>

### Assessment

| File | Verdict | Notes |
|------|---------|-------|
| `path/to/file.ts` | OK | Brief assessment |
| `path/to/other.tsx` | ⚠ | Non-blocking concern |
| `path/to/store.ts` | ❌ | Critical issue |

Verdict key: OK = no issues, ⚠ = non-blocking concern, ❌ = should fix before merge

### Issues

1. **[Category]:** `file.ts:42` — Description. Suggested fix.
2. **[Category]:** `other.tsx:15` — Description. Suggested fix.

Categories: Performance, Security, Edge Case, Pattern Violation, Project Pitfall, Logic Bug

<if config.projectPitfalls is non-empty:>
### Project-specific checks

- [ ] <projectPitfalls[0]>
- [ ] <projectPitfalls[1]>
- [ ] <projectPitfalls[2]>

(Only include checks relevant to the changed files. Mark checked or flagged.)
</if>

### Suggested Fixes

> Fixes have NOT been applied. Review and apply manually.

1. Description + code snippet if helpful
2. Description

---
*Code review by qa-batch · <date>*
```

The review comment uses `<!-- ios-qa-bot-review -->` (note `-review` suffix) as its marker — distinct from the visual QA marker `<!-- ios-qa-bot -->`. This allows independent dedup of visual QA and code review.

### PHASE 3: Summary

```python
reviewed = [r for r in results if r["status"] == "reviewed"]
failed = [r for r in results if r["status"].startswith("failed")]

print(f"\n{'='*60}")
print("QA Batch Complete")
print(f"{'='*60}\n")

print("| PR | Title | Result | Labeled |")
print("|----|-------|--------|---------|")
for r in results:
    pr = r["pr"]
    label = pr.get("labeled", "—")
    if r["status"] == "reviewed":
        print(f"| #{pr['number']} | {pr['title']} | ✓ Reviewed | {label} |")
    else:
        print(f"| #{pr['number']} | {pr['title']} | ✗ {r['status']} | — |")
for pr in skipped:
    print(f"| #{pr['number']} | {pr['title']} | ⏭ {pr['skip']} | — |")

print(f"\n**Batch stats:**")
print(f"- PRs scanned: {len(prs)}")
print(f"- PRs reviewed: {len(reviewed)}")
print(f"- PRs skipped: {len(skipped)}")
print(f"- PRs failed: {len(failed)}")

if failed:
    print(f"\n**Failed PRs:**")
    for r in failed:
        print(f"- #{r['pr']['number']}: {r['status']}")

print(f"\nVisual QA reports + code reviews have been posted as comments on each PR.")
print(f"Review them on GitHub, then apply fixes manually or re-run /qa-batch <PR#>.")
```

## Context cost management

For batches of 5+ PRs, accumulated `/ios-qa` output and diff analysis can bloat context.

**Strategy:**
- After each PR completes, summarize the result in 2-3 lines and move on. The full findings live in the PR comments.
- If you notice context pressure (slow responses, tool calls taking longer), skip the deep code review for remaining PRs and post visual-QA-only comments. Note this in the summary table.
- The visual QA is the higher-value check. If you must drop one, drop the code review.

## Safety guards

**Branch safety:**
- NEVER leave the repo on a `-qa` branch. Always restore `original_branch` in `finally`.
- If `git checkout {original_branch}` fails, stop the batch immediately and report.
- Clean up ALL `-qa` branches at the start (PHASE 0) and after each PR.

**Simulator safety:**
- Never restart the bundler or simulator.
- If the simulator becomes unresponsive, skip the current PR and continue.

**GitHub safety:**
- Post at most 2 comments per PR (1 visual QA, 1 code review).
- Never close, approve, or request changes — only informational comments.
- Never push code. Fixes are suggestions only.
- `ready` label is **add-only**. Never remove it — manual unlabel is the user's signal.

**Bash safety:**
- NEVER use `$()` or backticks.
- Never use `#` comments inside inline shell one-liners.
- Keep Bash commands simple and single-purpose.

See [examples.md](examples.md) for sample runs.
