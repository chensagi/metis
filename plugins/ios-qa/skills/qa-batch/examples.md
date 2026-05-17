# qa-batch Examples

## Example: 3 open PRs

### Setup

```
Open PRs:
  #243 — feat: profile redesign (JS-only, no previous QA)
  #242 — fix: session snapshot fields (JS-only, already reviewed, no new commits)
  #241 — fix: hide debug menu (native change — modifies app.json)

Simulator: booted, app running
Bundler: running on configured metroUrl
Branch: main (clean)
```

### Invocation

```bash
/qa-batch
```

### PHASE 0 output

```
Preflight passed. On branch: main
Cleaned up 1 stale -qa branch: feat-portfolio-expansion-qa
```

### PHASE 1 output

```
## QA Batch Plan

| PR | Title | Status |
|----|-------|--------|
| #243 | feat: profile redesign | WILL QA |
| #242 | fix: session snapshot fields | SKIP — already reviewed (no new commits) |
| #241 | fix: hide debug menu | SKIP — native changes |

Eligible: 1 | Skipped: 2
```

### PHASE 2 output

```
============================================================
QA: PR #243 — feat: profile redesign
============================================================

[/ios-qa --from-pr 243 runs: checkout → bundler poll → screenshot Profile,
 Settings, Edit Profile → User Complaint Filter → post visual QA comment → restore]

✓ Visual QA posted to PR #243

[Deep code review: reads gh pr diff 243, analyzes 8 changed files]

✓ Code review posted to PR #243

✓ PR #243 — visual QA + code review posted (✓ ready)
```

### PHASE 3 output

```
============================================================
QA Batch Complete
============================================================

| PR | Title | Result | Labeled |
|----|-------|--------|---------|
| #243 | feat: profile redesign | ✓ Reviewed | ✓ ready |
| #242 | fix: session snapshot fields | ⏭ already reviewed (no new commits) | — |
| #241 | fix: hide debug menu | ⏭ native changes | — |

**Batch stats:**
- PRs scanned: 3
- PRs reviewed: 1
- PRs skipped: 2
- PRs failed: 0

Visual QA reports + code reviews have been posted as comments on each PR.
Review them on GitHub, then apply fixes manually or re-run /qa-batch <PR#>.
```

## Example: Dry run

```bash
/qa-batch --dry-run
```

Output: Same as PHASE 1 above, plus:

```
--dry-run flag set. No QA will be performed.
```

## Example: Specific PRs

```bash
/qa-batch 243 241
```

Only processes PRs #243 and #241 (skipping #242 even if eligible). PR #241 would still be filtered out as native-change.
