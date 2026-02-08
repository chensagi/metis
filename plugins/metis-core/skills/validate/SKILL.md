---
name: validate
description: Lint and validate SKILL.md and capability.md files in metis-core for convention compliance
argument-hint: [skill-name|capability-name|--all] (optional - validates specific item or everything)
allowed-tools: Bash, Read, Glob, Grep
---

# Validate — Convention Linter

You are executing the `/validate` command. This skill checks SKILL.md and capability.md files in `plugins/metis-core/` for convention compliance. It's read-only — no files are modified.

## Step 1: Determine Scope

**If `$ARGUMENTS` is `--all` or empty:**
- Validate ALL skills and ALL capabilities

**If `$ARGUMENTS` is a name:**
1. Check if `plugins/metis-core/skills/$ARGUMENTS/SKILL.md` exists → validate that skill
2. Else check if `plugins/metis-core/capabilities/$ARGUMENTS/capability.md` exists → validate that capability
3. If neither exists → report error and list available skills/capabilities

## Step 2: Load Registry

Read `plugins/metis-core/capabilities/registry.json` — needed for cross-reference validation in later steps.

Also glob for all skill directories (`plugins/metis-core/skills/*/SKILL.md`) and capability directories (`plugins/metis-core/capabilities/*/capability.md`) to build a complete inventory.

## Step 3: Validate Skills

For each SKILL.md in scope, check the following:

### 3a: Frontmatter Checks
- `name` field exists and matches the directory name → **FAIL** if missing or mismatched
- `description` field exists and is non-empty → **FAIL** if missing
- `allowed-tools` field exists and contains only valid tool names → **FAIL** if missing; **WARN** if contains unrecognized tools
- Valid tool names: `Bash`, `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Task`, `TaskOutput`, `WebSearch`, `WebFetch`
- If `disable-model-invocation: true` is present, skill is a dispatcher — check for 3-layer architecture section

### 3b: Structure Checks
- File has a title line (`# ...`) → **FAIL** if missing
- File contains `You are executing` intro line → **WARN** if missing
- File contains a `<rules>` block → **FAIL** if missing

### 3c: Architecture Checks
- No references to "2-layer" anywhere in the file → **FAIL** if found
- If skill has `disable-model-invocation: true` (dispatcher):
  - Must have a section about 3-layer architecture (L0/L1/L2) → **WARN** if missing
  - Must have `<agent-prompt>` block(s) → **WARN** if missing
- If skill has `<agent-prompt>` blocks:
  - Each should reference `Task(` format → **WARN** if not found
  - Each should include `model` parameter → **WARN** if not found
  - Each should include `subagent_type` parameter → **WARN** if not found

### 3d: Cross-Reference Checks
- Any capability names referenced in the skill (look for capability names from registry) — verify they exist in the registry → **WARN** if referencing non-existent capability
- Any skill names referenced (e.g., `/install`, `/task`) — verify the skill directory exists → **WARN** if referencing non-existent skill

## Step 4: Validate Capabilities

For each capability.md in scope, check the following:

### 4a: Frontmatter Checks
- `name` field exists and matches the directory name → **FAIL** if missing or mismatched
- `version` field exists and follows semver (`X.Y.Z`) → **FAIL** if missing or invalid
- `description` field exists and is non-empty → **FAIL** if missing
- `requires` field exists and is an array → **FAIL** if missing
- `provides` field exists and is an array with at least one tag → **FAIL** if missing or empty
- `commands` field exists → **WARN** if missing

### 4b: Structure Checks
- File has a `## Agent Instructions` section → **FAIL** if missing
- The `## Agent Instructions` section has content (not just the heading) → **WARN** if empty

### 4c: Cross-Reference Checks
- Each entry in `requires` array references a capability that exists in registry → **FAIL** if broken reference
- Capability is registered in `registry.json` → **FAIL** if not found
- Version in capability frontmatter matches version in `registry.json` → **WARN** if mismatched

## Step 5: Validate Registry

Check `plugins/metis-core/capabilities/registry.json` for consistency:

- **Orphan registry entries**: capability listed in registry but no directory/file exists → **FAIL**
- **Orphan directories**: capability directory exists with `capability.md` but not in registry → **WARN**
- **Path validity**: each registry entry's `path` field points to a file that exists → **FAIL** if not found

## Step 6: Present Report

Group results by file, sorted alphabetically. Use this format:

```
METIS VALIDATE
═══════════════════════════════════════════════════

Skills (N checked)
───────────────────────────────────────────────────
  ✓ PASS  install
  ✓ PASS  task
  ✗ FAIL  swarm
          - FAIL: <rules> block missing
          - WARN: agent-prompt missing model parameter
  ⚠ WARN  learn
          - WARN: "You are executing" intro missing

Capabilities (N checked)
───────────────────────────────────────────────────
  ✓ PASS  typescript
  ✗ FAIL  react-native
          - FAIL: version mismatch (0.1.0 in file vs 0.2.0 in registry)

Registry
───────────────────────────────────────────────────
  ✓ No orphan entries
  ⚠ 1 orphan directory: experimental/

Summary: N passed, N warnings, N failures
═══════════════════════════════════════════════════
```

**Severity guide:**
- **FAIL** — Must fix. Missing required fields, architecture violations, broken cross-references
- **WARN** — Should fix. Missing optional conventions, version mismatches, style issues
- **PASS** — All checks pass for this item

<rules>
- This skill is READ-ONLY — never modify any files
- This skill runs in the METIS REPO only (not in consumer projects)
- Report ALL issues found, don't stop at the first failure
- Validate frontmatter by reading file content and parsing the YAML between `---` markers
- When checking cross-references, only flag capability/skill names that appear in operational context (agent prompts, requires fields, etc.) — not casual mentions in prose descriptions
</rules>
