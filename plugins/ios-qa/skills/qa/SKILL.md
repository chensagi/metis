---
name: qa
description: Enter/exit/refresh a QA session for a PR or branch. Stashes dirty work, checks out into a fresh `qa/*` branch, lets you commit fixes that can be cherry-picked back. Use `/qa <PR#|branch>` to enter, `/qa refresh` to pull latest, `/qa exit` to leave.
argument-hint: <PR# | branch | "exit" | "refresh">
allowed-tools:
  - Bash(git:*)
  - Bash(gh:*)
  - Bash(curl:*)
  - Bash(lsof:*)
  - Bash(pgrep:*)
  - Bash(cat:*)
  - Bash(echo:*)
  - Bash(rm:*)
  - Read
  - Glob
  - Grep
---

# QA Session Manager

Fast enter/exit/refresh QA workflow. Accepts PR numbers or branch names. Supports committing fixes during QA that can be cherry-picked back to the source branch.

## Configuration

Optional `.claude/ios-qa.json` keys:

| Key | Default | Used for |
|-----|---------|----------|
| `defaultBranch` | `main` | The branch you rebase QA onto and pull from |
| `metroUrl` | `http://localhost:8081/status` | Bundler probe |
| `metroReadyMarker` | `packager-status:running` | Substring for ready check |
| `typecheckCommand` | (none) | Optional command run on enter (e.g., `"npx tsc --noEmit"`) |
| `testCommand` | (none) | Optional command run on enter (e.g., `"npx jest --forceExit"`) |

If `typecheckCommand` / `testCommand` are absent, those checks are simply skipped.

## Arguments

`$ARGUMENTS` — one of:
- A **PR number** (e.g., `221`)
- A **branch name** (e.g., `feat/my-feature`)
- **`exit`** / `done` / `quit` / `q` — end the session, restore previous branch
- **`refresh`** / `pull` / `update` — pull latest from source, preserving QA commits

## State file

QA state lives in `/tmp/ios-qa-session` with 4 lines:
1. Previous branch name (to return on exit)
2. Stash status (`stashed` or `clean`)
3. Source remote branch (e.g., `origin/feat/my-feature`)
4. Source tip hash at QA entry (to distinguish source vs QA commits)

## CRITICAL: No command substitution

**NEVER use `$()` or backticks in Bash commands.** Claude Code prompts for any command containing `$()`, defeating `allowed-tools`. Instead:
- Use **separate tool calls** for each piece of information.
- Read tool outputs yourself, then use the values in subsequent commands.
- Use pipes (`|`) instead of variable capture where possible.

---

## REFRESH flow (`/qa refresh`)

If `$ARGUMENTS` is `refresh`, `pull`, or `update`:

### 1. Verify we're in a QA session

```bash
cat /tmp/ios-qa-session
```
```bash
git branch --show-current
```

If no state file or not on a `qa/*` branch, say "No active QA session" and stop.

Read the state file: line 3 is the source remote branch, line 4 is the original source tip hash.

### 2. Check for uncommitted changes

```bash
git status --porcelain
```

If there are uncommitted changes, ask the user to commit or discard before refreshing.

### 3. Identify QA commits (yours) vs source commits

```bash
git log --oneline <source-tip-hash>..HEAD
```

Save these hashes — they're your QA fixes to preserve.

### 4. Fetch latest source branch

```bash
git fetch origin
```
```bash
git rev-parse origin/<source-branch>
```

Note the new tip hash. If it matches the old, say "Already up to date" and stop.

### 5. Reset to new source and reapply QA commits

```bash
git reset --hard origin/<source-branch>
```

Rebase on default branch if needed:

```bash
git merge-base --is-ancestor <defaultBranch> HEAD && echo "based-on-default" || echo "needs-rebase"
```
```bash
git rebase <defaultBranch>
```

If QA commits exist from step 3, cherry-pick them back:

```bash
git cherry-pick <hash1> <hash2> ...
```

If cherry-pick conflicts, stop and report.

### 6. Update state file with new source tip

```bash
echo "<prev-branch>" > /tmp/ios-qa-session && echo "<stash-status>" >> /tmp/ios-qa-session && echo "origin/<source-branch>" >> /tmp/ios-qa-session && echo "<new-tip-hash>" >> /tmp/ios-qa-session
```

### 7. Report

- Number of new commits pulled from source
- Number of QA commits preserved
- Any conflicts encountered

Stop here for refresh flow.

---

## EXIT flow (`/qa exit`)

If `$ARGUMENTS` is `exit`, `done`, `quit`, or `q`:

### 1. Verify we're in a QA session

```bash
cat /tmp/ios-qa-session
```

If no state file or not on a `qa/*` branch, say "No active QA session" and stop.

Read line 3 (source branch) and line 4 (source tip hash).

### 2. Collect QA commits

```bash
git log --format="%H %s" <source-tip-hash>..HEAD
```

Save the list with **full hashes** — these are the user's fixes.

### 3. Check for uncommitted changes

```bash
git status --porcelain
```

If dirty, ask whether to commit or discard before exiting.

### 4. Switch back

**Step A** — read state and current branch:

```bash
cat /tmp/ios-qa-session
```
```bash
git branch --show-current
```

Note previous branch (line 1) and stash status (line 2).

**Step B** — switch back, delete QA branch:

```bash
git checkout <prev-branch> && git branch -D <qa-branch>
```

**Step C** (only if stash status was `stashed`):

```bash
git stash pop
```

**Step D** — clean up:

```bash
rm /tmp/ios-qa-session
```

### 5. Cherry-pick report

If any QA commits were found in step 2, print:

```
## QA Commits (ready to cherry-pick)
<full-hash> <message>
<full-hash> <message>

To apply these to the source branch:
  git checkout <source-branch>
  git cherry-pick <hash1> <hash2> ...
```

**Important:** the QA branch is deleted, but commits remain reachable by hash until git GC (~2 weeks). Print full hashes.

If no QA commits, just say "No QA commits made."

---

## ENTER flow

### 1. Resolve the source branch

**If `$ARGUMENTS` is purely numeric (a PR number):**

```bash
gh pr view $ARGUMENTS --json headRefName,title,state --jq '{branch: .headRefName, title: .title, state: .state}'
```

Use `headRefName` as the source branch.

**Otherwise, treat as branch name:**

```bash
git fetch origin
```
```bash
git rev-parse --verify origin/<arg> 2>/dev/null
```

If nothing resolves, list open PRs and ask the user.

### 2. Handle dirty working tree + switch to default branch

**Step A** — get current branch and dirty status (parallel):

```bash
git branch --show-current
```
```bash
git status --porcelain
```

Dirty = `git status --porcelain` produced output.

**Step B** — stash if dirty (only if dirty):

```bash
git stash push -u -m "qa-auto-stash"
```

**Step C** — switch to default branch, fetch, fast-forward if behind:

```bash
git checkout <defaultBranch>
```
```bash
git fetch origin
```
```bash
git rev-parse <defaultBranch>
```
```bash
git rev-parse origin/<defaultBranch>
```

Compare hashes. Only if they differ:

```bash
git pull --ff-only origin <defaultBranch>
```

### 3. Create QA branch and rebase

```bash
git checkout -b qa/<short-description> --no-track origin/<source-branch>
```

Derive `<short-description>` from PR title or branch name. Keep it short (e.g., `auth-redirect`, `chart-fixes`).

Rebase only if needed:

```bash
git merge-base --is-ancestor <defaultBranch> HEAD && echo "based-on-default" || echo "needs-rebase"
```
```bash
git rebase <defaultBranch>
```

If rebase conflicts, stop and report.

### 4. Record source tip hash and write state

```bash
git rev-parse HEAD
```

Write all 4 lines:

```bash
echo "<prev-branch>" > /tmp/ios-qa-session && echo "<stash-status>" >> /tmp/ios-qa-session && echo "origin/<source-branch>" >> /tmp/ios-qa-session && echo "<head-hash>" >> /tmp/ios-qa-session
```

### 5. Run checks + bundler status (all in parallel)

Run as separate parallel tool calls. Skip any check whose command is not configured.

```bash
<typecheckCommand>           # only if configured
```
```bash
<testCommand>                # only if configured
```
```bash
curl -s <metroUrl>           # bundler health
```
```bash
git diff --name-only <defaultBranch>..HEAD -- ios/ android/ app.json package-lock.json Podfile.lock
```

### 6. Report

| Item | Status |
|------|--------|
| **Source** | PR #N or branch name — title |
| **QA Branch** | `qa/<name>` (local-only) |
| **Commits** | N commits from source |
| **Typecheck** | Pass / Fail / Skipped |
| **Tests** | N/N / Skipped |
| **Bundler** | Running / Not running |
| **Rebuild needed** | Yes (native changes) / No (JS-only, hot reload) |

Decision matrix for the bundler message:

| Bundler running? | Native changes? | Message |
|---|---|---|
| Yes | No | "JS-only changes — hot reload is live. Ready to QA." |
| Yes | Yes | "Native changes detected — needs rebuild." |
| No | No | "Bundler not running. Start it. No rebuild needed." |
| No | Yes | "Bundler not running + native changes. Full build needed." |

End with: **"QA session active. Edit freely, commit fixes, then `/qa exit` when done."**

## Example usage

```
/qa 221                      # Enter QA for PR #221
/qa feat/my-feature          # Enter QA for a branch
/qa refresh                  # Pull latest from source, keep QA commits
/qa exit                     # Exit QA, show cherry-pick summary
```
