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

## Workflow

Execute these steps in order:

### 1. Check for changes
```bash
git status
git diff --stat
```
If no changes, inform the user and stop.

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
Wait for all checks to pass. If checks fail, inform the user.

### 8. Merge the PR
```bash
gh pr merge <pr-number> --merge --delete-branch
```

### 9. Sync local main
```bash
git checkout main && git fetch origin && git reset --hard origin/main
```

### 10. Report success
Show the merged PR URL and confirm the changes are now on main.

## Example Usage
```
/ship enable-dark-mode Add dark mode toggle to settings
```

This creates branch `claude/enable-dark-mode`, commits with message "Add dark mode toggle to settings", creates PR, waits for CI, merges, and syncs.
