---
name: setup
description: Use once when adding conductor to a project. Verifies the superpowers plugin is installed (stops if not), creates a minimal .conductor/ config and memory dir, and points at the project's existing goal statement instead of duplicating it.
argument-hint: (no arguments)
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Bash(mkdir:*)
---

# conductor: setup

Make a project ready for `/conductor`. Keep this tiny — conductor's whole premise is that a strong model needs direction, not a manual.

- **Check superpowers.** Confirm the superpowers plugin is installed (its skills, e.g. `superpowers:brainstorming`, are available). If it's missing, stop and tell the user to install it — conductor will not run without it.
- **Write `.conductor/config.json`** with budget caps and effort defaults:
  ```json
  {
    "budget": { "workers": 8, "rounds": 3 },
    "effort": { "orchestrator": "high", "worker": "low" },
    "mechanicalLeafModel": "claude-haiku-4-5-20251001"
  }
  ```
  These are caps and defaults, not targets — `/conductor` reads them at the start of every run.
- **Create `.conductor/memory/`** for one-lesson-per-file notes, with a short `README.md` describing the format: one file per lesson, a one-line summary on the first line, deleted when it turns out wrong.
- **Find the goal, don't write one.** If the repo already states its purpose (a CLAUDE.md, a README mission, a product doc), record its path as `northStar` in the config. Only draft a one-paragraph north-star if none exists — and ask the user to confirm it. Never duplicate what the repo already says.
- **Report** what you created and the single command they need next: `/conductor <goal>`.
