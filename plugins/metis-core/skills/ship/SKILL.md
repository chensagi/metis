---
name: ship
description: Ship current changes by creating a PR, waiting for CI checks to pass, and merging to main. Use when the user says "ship it", "create a PR and merge", "push this to main", or wants to finalize their changes.
argument-hint: [branch-name] [commit-message]
allowed-tools: Bash
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

### 1. Check for changes
```bash
git status
git diff --stat
```
If no changes, tell the user "Nothing to ship — no uncommitted changes found." and STOP. Do NOT proceed.

### 2. Create feature branch
```bash
git checkout -b claude/$0
```

### 3. Stage changes
Stage all modified and new files. Be specific — list each file by name. Do NOT use `git add .` or `git add -A`.

### 4. Commit
Create a commit with a descriptive message. Always include the Co-Authored-By trailer:
```
$ARGUMENTS

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

Use HEREDOC format for multi-line commit messages.

### 5. Push to remote
```bash
git push -u origin claude/$0
```

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
