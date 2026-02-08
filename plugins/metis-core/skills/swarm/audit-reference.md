# Swarm Audit — Detailed Reference

## Why Audit Exists

Background agents can finish or crash without delivering a notification (API errors, rate limits, session interruptions). This leaves `.metis/agents.json` showing "running" agents that are actually done. The audit command detects and corrects this.

## Audit Procedure

1. Read `.metis/agents.json`
2. For each agent listed as `"running"`:
   a. Read the **last ~200 lines** of its `output_file` using `tail`
   b. Determine actual status using these heuristics (check in order):
      - **Crashed/Error:** Output contains `API Error`, `rate limit`, `error`, or `was stopped` → move to `needs_review`
      - **Completed:** Output contains `## Summary`, `## Implementation Summary`, `Implementation Summary`, or `Acceptance Criteria` → move to `completed`
      - **Completed (alt):** The last JSON message in the output file has `"role":"assistant"` with a `"text"` content block (not a tool_use) → likely finished, move to `completed`
      - **Still running:** Output file is being actively written to (check with `stat` — modified within last 2 minutes) → keep as `running`
      - **Stale/Dead:** Output file hasn't been modified in 5+ minutes and doesn't match completion patterns → move to `needs_review` with note "Agent appears stale"
   c. For tasks moved to `completed`, verify files were actually created:
      - Check the task spec for expected files/directories
      - Run `ls` or `Glob` on the expected paths
      - If no files found → move to `needs_review` instead with note "Marked complete but no files found"
   d. For tasks confirmed as `completed`, run the full completion lifecycle:
      - Move task file: `git mv .metis/tasks/doing/${filename} .metis/tasks/done/${filename}`
      - Git commit the task individually (see "Git Commits" in SKILL.md)
3. Update `.metis/agents.json` with corrected statuses
4. Display an audit report showing what changed

## Output Format

```
SWARM AUDIT REPORT
=================================================

Checked N agents listed as "running":

  Task XX: Task Title
  - Was: running → Now: completed
  - Evidence: Found "Implementation Summary" in output
  - Files verified: src/path/to/files/ (N files)
  - Moved: .metis/tasks/doing/XX-*.md → .metis/tasks/done/
  - Committed: "Task XX: Task Title — complete"

  Task YY: Another Task
  - Was: running → Now: needs_review
  - Evidence: "API Error: 400" found in output
  - Files found: 1 of ~3 expected
  - Task file stays in .metis/tasks/doing/

agents.json updated. N commits created.
=================================================
```

## When to Use

- When you suspect agents finished without notification
- At the start of a new session to reconcile stale state
- Before running `/swarm` to ensure accurate task state
- When `.metis/agents.json` feels "off" or outdated
