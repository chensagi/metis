# conductor

A budget-bounded orchestrator for Claude Code. Give it a goal; it frames the work, plans with [superpowers](https://github.com/obra/superpowers), dispatches isolated workers, verifies each result against a real oracle, and reports — under a hard budget, on whichever strong model you've selected.

Conductor is the successor to the **deprecated `metis` plugin**. It's a full rewrite, not a reorganization — see [ARCHITECTURE.md](ARCHITECTURE.md) for why.

## Requirements

- **The [superpowers](https://github.com/obra/superpowers) plugin — required.** Conductor delegates all engineering discipline (planning, TDD, review, worktrees) to it and stops if it's absent.
- A git repository — conductor branches and opens PRs; it never pushes to `main`.
- `gh` CLI for PR operations.

## Install

```
/plugin marketplace add chensagi/metis
/plugin install conductor@metis
```

Then, once per project:

```
/conductor:setup
```

## Use

```
/conductor add rate limiting to the public API
/conductor "fix the flaky auth tests" --budget workers=4,rounds=2
```

Conductor frames the goal, plans it, runs the work in isolated subagents, has fresh-context reviewers verify each piece against its oracle, and hands you a report — then a branch and PR for you to merge.

## How it's different from metis

| | metis (deprecated) | conductor |
|---|---|---|
| Cost lever | cheapest model that can do the job | effort dial + context isolation; strong model throughout |
| Layers | by model price (Opus / Sonnet / Haiku) | by role (orchestrator / isolated workers / verifier) |
| Discipline | re-encoded in each skill | delegated to superpowers (hard dependency) |
| Verification | implicit | a first-class role with a ground-truth oracle |
| Reasoning | agents narrate every step | set direction, check results |

## Status

Slice 1 — the orchestrator spine — is what ships here. The autonomous pipeline (triage → gated merge → decision console) and the project-awareness layer are planned; see [ARCHITECTURE.md](ARCHITECTURE.md).
