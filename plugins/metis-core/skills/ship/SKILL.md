---
name: ship
description: Ship current changes by creating a PR, waiting for CI checks to pass, and merging to main. Use when the user says "ship it", "create a PR and merge", "push this to main", or wants to finalize their changes.
argument-hint: [branch-name] [commit-message]
allowed-tools: Bash, AskUserQuestion
---

# Ship Changes to Main

Create a PR for current changes, wait for CI checks to pass, and merge to main.

## Arguments
- `$0` - Branch name (will be prefixed with `claude/`)
- `$1` onwards - Commit message (short description of changes)

<rules>
- NEVER force-push or use --force
- NEVER merge a PR with failing CI checks — STOP and show the user the failure details
- NEVER use `git add .` or `git add -A` — always stage specific files by name
- NEVER skip the CI wait step
- ALWAYS use HEREDOC format for commit messages
- ALWAYS include Co-Authored-By trailer in commits
</rules>

## Workflow

Execute these steps in order:

### 0. Pre-check

Verify the environment is ready:
```bash
git rev-parse --is-inside-work-tree
which gh
git remote get-url origin
```
If any of these fail, STOP and tell the user what's missing (not a git repo, `gh` CLI not installed, or no remote configured).

### 1. Detect current state

Determine where we're starting from:

```bash
git branch --show-current
git status
git diff --stat
```

**Case A: On main (or detached HEAD) with uncommitted changes**
- Stash or carry changes to the new branch
- `git checkout -b claude/$0` — uncommitted changes come along automatically
- If checkout fails due to conflicts, `git stash && git checkout -b claude/$0 && git stash pop`

**Case B: Already on a feature branch (e.g., `claude/something`)**
- Use the existing branch — do NOT create a new one
- Check for uncommitted changes and stage/commit them (Steps 3-4)
- If the branch already has commits ahead of main, those are included in the PR

**Case C: No changes AND no commits ahead of main**
- Tell the user "Nothing to ship — no uncommitted changes or commits found." and STOP

### 2. Create feature branch (Case A only)

Only if we're on main/detached HEAD:
```bash
git checkout -b claude/$0
```

### 3. Stage changes

If there are uncommitted changes, stage all modified and new files. Be specific — list each file by name. Do NOT use `git add .` or `git add -A`.

If all changes are already committed (Case B with no uncommitted changes), skip to Step 5.

### 4. Commit
Create a commit with a descriptive message. Always include the Co-Authored-By trailer:
```
$ARGUMENTS

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

Use HEREDOC format for multi-line commit messages.

### 5. Rebase over main and push

Before pushing, rebase over main to ensure the branch is up to date and the PR will be conflict-free:

```bash
git fetch origin main
git rebase origin/main
```

If the rebase has conflicts, STOP. Show the user which files conflict and ask how to proceed. Do NOT force through conflicts.

Then push:
```bash
git push -u origin HEAD
```

If the branch was already pushed and the rebase rewrote history, the push will fail. In that case, ask the user before force-pushing — do NOT force-push automatically.

### 6. Create Pull Request
Use `gh pr create` with:
- Title: The commit message (first line)
- Body: Include summary bullets and test plan checklist

```bash
gh pr create --title "..." --body "$(cat <<'EOF'
## Summary
- [bullet points of changes]

## Test plan
- [ ] [testing checklist]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### 7. Wait for CI checks
```bash
gh pr checks <pr-number> --watch
```
Wait for all checks to pass. If checks fail, STOP. Show the user the failing check names and details. Do NOT attempt to merge. Ask the user how to proceed.

### 8. Report PR ready
Show the PR URL and CI status. Then ask the user:

Use `AskUserQuestion` with options:
- "Merge now" — proceed to merge immediately
- "Don't merge" — leave the PR open for manual review

Do NOT merge unless the user explicitly chooses "Merge now".

### 9. Merge the PR (only if user approved)
```bash
gh pr merge <pr-number> --merge --delete-branch
```

### 10. Sync local main
```bash
git checkout main && git pull --ff-only origin main
```

### 11. Report success
Show the merged PR URL and confirm the changes are now on main. Suggest `/clear` to start a fresh conversation.

## Example Usage
```
/ship enable-dark-mode Add dark mode toggle to settings
```

This creates branch `claude/enable-dark-mode`, commits with message "Add dark mode toggle to settings", creates PR, waits for CI, merges, and syncs.
