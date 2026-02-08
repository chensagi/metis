---
name: metis-manage
description: Internal dogfooding tool for managing the metis plugin — promote skills, sync plugin, check status. Not for end users.
argument-hint: [promote|demote|pull|sync|status|ship] <args>
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Metis Manage — Dogfooding Tool

You are executing the `/metis-manage` command. This is an internal tool for managing the metis plugin during development. It is NOT part of the shipped product.

## Commands

Parse `$ARGUMENTS` and route to the appropriate action:

| Command | Action |
|---------|--------|
| `promote <skill>` | Move a custom skill from `.metis/skills/` to `plugins/metis-core/skills/` (make it a core skill) |
| `demote <skill>` | Copy a core skill from `plugins/metis-core/skills/` to `.metis/skills/` for experimentation |
| `pull <url-or-path>` | Import a community capability from a git repo URL or local path into the registry |
| `sync` | Reinstall the plugin to pick up local changes |
| `status` | Show what's local vs plugin, what's changed |
| `ship [message]` | Stage all plugin changes, commit, push, create PR, merge |
| *(no args)* | Show this command list |

---

## `promote <skill>`

Move a custom project skill into the core plugin so it ships to all users.

### Steps

1. Verify `.metis/skills/{skill}/SKILL.md` exists — abort if not found
2. Verify `plugins/metis-core/skills/{skill}/` does NOT exist — abort with warning if it does (use `--force` to overwrite)
3. Read the custom skill's SKILL.md
4. Check it follows core skill conventions:
   - Has YAML frontmatter (name, description, argument-hint, allowed-tools)
   - Has a `## Bootstrap` section (for consumer skills) or explain why it's not needed
   - Has a `<rules>` block
   - Step numbering is consistent
5. Create `plugins/metis-core/skills/{skill}/` and copy the SKILL.md
6. Remove `.metis/skills/{skill}/` (the plugin version takes over)
7. Report:

```
PROMOTED: /{skill}
═══════════════════════════════════════════════════

From: .metis/skills/{skill}/SKILL.md (local)
To:   plugins/metis-core/skills/{skill}/SKILL.md (plugin)

Still needed:
  • Add to README.md skills table
  • Add to plugins/metis-core/README.md
  • Run /metis-manage ship to publish

═══════════════════════════════════════════════════
```

## `demote <skill>`

Copy a core skill to local for experimentation without modifying the plugin.

### Steps

1. Verify `plugins/metis-core/skills/{skill}/SKILL.md` exists
2. Copy the entire skill directory to `.metis/skills/{skill}/`
3. Note: the local version takes precedence when both exist (Claude Code checks `.metis/skills/` first)
4. Report that the local copy is now active and the plugin version is shadowed

## `pull <url-or-path>`

Import a community capability from a git repo URL or local path into the metis-core registry.

### Sources

- **Git URL:** `https://github.com/user/metis-capability-reanimated`
- **Local path:** `/path/to/capability.md`
- **Another metis repo:** `/path/to/other-metis/plugins/metis-core/capabilities/custom-thing/capability.md`

### Steps

1. **Fetch the source:**
   - Git URL → `git clone --depth 1 {url} /tmp/metis-pull-{name}`, find `capability.md`
   - Local path → read the file directly

2. **Validate the capability:**
   - YAML frontmatter exists with: `name`, `version`, `description`, `requires`, `provides`
   - `## Agent Instructions` section exists
   - Dependencies in `requires` exist in the metis registry
   - No name conflict with existing capabilities
   - If validation fails, show errors and stop

3. **Show preview:**
   ```
   PULL CAPABILITY — Preview
   ═══════════════════════════════════════════════════

   Source: {url_or_path}
   Name: {name} (v{version})
   Description: {description}
   Requires: {requires}
   Provides: {provides}

   Agent Instructions preview:
   {first 10 lines of ## Agent Instructions section}

   ═══════════════════════════════════════════════════
   ```

4. **Import** (after user approval):
   - Create `plugins/metis-core/capabilities/{name}/capability.md`
   - Update `plugins/metis-core/capabilities/registry.json`
   - Clean up temporary git clones

5. **Optionally add to profiles** — ask if it should be added to any existing profiles

6. **Report:**
   ```
   CAPABILITY IMPORTED
   ═══════════════════════════════════════════════════

   Name: {name} (v{version})
   Source: {url_or_path}
   File: plugins/metis-core/capabilities/{name}/capability.md

   Still needed:
     • Run /metis-manage ship to publish
     • Consumer projects: /install --update to get it

   ═══════════════════════════════════════════════════
   ```

---

## `sync`

Reinstall the plugin after making local changes to `plugins/metis-core/`.

### Steps

1. Show what changed since last sync:
   ```bash
   git diff --name-only plugins/metis-core/
   ```
2. Tell the user to run:
   ```
   /plugin install metis@metis
   ```
   (This must be run by the user — the skill cannot invoke plugin commands)
3. After reinstall, verify skills are registered by listing `.claude/plugins/cache/metis/` contents

## `status`

Show the current state of skills across local and plugin.

### Steps

1. Glob `plugins/metis-core/skills/*/SKILL.md` → list core skills
2. Glob `.metis/skills/*/SKILL.md` → list local/custom skills
3. Check for shadows (local skill with same name as core skill)
4. Check for uncommitted changes in `plugins/metis-core/`:
   ```bash
   git status plugins/metis-core/ --short
   ```
5. Report:

```
METIS STATUS
═══════════════════════════════════════════════════

Core Skills (plugins/metis-core/skills/):
  help  install  migrate  task  swarm  triage
  ship  learn  add-metiskill  scaffold-skill
  validate  add-capability  release

Local Skills (.metis/skills/):
  create-tasks  metis-manage

Shadows (local overrides core):
  (none)

Uncommitted Plugin Changes:
  (none — or list of changed files)

═══════════════════════════════════════════════════
```

## `ship [message]`

Stage all metis-related changes, create a PR, and merge. A shortcut for the common dogfooding flow.

### Steps

1. Check for changes:
   ```bash
   git status --short
   ```
2. If no changes, inform and stop
3. Create a branch:
   ```bash
   git checkout -b claude/metis-{timestamp}
   ```
   Use a short timestamp like `0209-1` for readability
4. Stage all relevant files — be specific:
   - `plugins/metis-core/` changes
   - `.metis/` changes (config, capabilities, skills — NOT agents.json/learnings.json/tasks/)
   - `README.md`, `CLAUDE.md` if changed
   - `.claude/settings.json` if changed
5. Commit with message from args or auto-generate from changed files:
   ```
   {message or auto-generated}

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
   ```
6. Push and create PR:
   ```bash
   git push -u origin {branch}
   gh pr create --title "{message}" --body "..."
   ```
7. Merge immediately (no CI to wait for):
   ```bash
   gh pr merge {number} --merge --delete-branch
   ```
8. Sync local main:
   ```bash
   git checkout main && git pull origin main
   ```
9. Report the merged PR URL

---

## No Arguments

If run with no arguments, show the available commands:

```
METIS MANAGE — Dogfooding Tool
═══════════════════════════════════════════════════

Commands:
  /metis-manage promote <skill>       Move local skill → core plugin
  /metis-manage demote <skill>        Copy core skill → local for experiments
  /metis-manage pull <url-or-path>    Import community capability into registry
  /metis-manage sync                  Reinstall plugin after changes
  /metis-manage status                Show local vs plugin skills
  /metis-manage ship [message]        Stage, commit, PR, merge all changes

═══════════════════════════════════════════════════
```

## Rules

<rules>
- This skill is for internal dogfooding ONLY — never promote this skill itself to the plugin
- promote: always check conventions before promoting (frontmatter, rules block, bootstrap)
- promote: always remind to update both READMEs after promoting
- demote: never delete the core version — only copy to local
- ship: never use git add -A — stage specific files
- ship: always include Co-Authored-By trailer
- ship: never push to main directly — always PR workflow
- pull: always validate capability format before importing — reject malformed files
- pull: never auto-add to profiles without asking
- pull: clean up temporary git clones after import
</rules>
