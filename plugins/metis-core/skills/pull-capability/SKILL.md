---
name: pull-capability
description: Pull a community capability from a git repo URL or local path into the metis-core registry. Validates format and registers it.
argument-hint: [url-or-path] (git repo URL or local path to a capability.md file)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Pull Capability — Community Import

You are executing the `/pull-capability` command. This skill imports a capability from an external source (git repo or local file) into the metis-core registry. Run this **in the metis repo**.

## Sources

### From a Git Repo URL

The repo should contain a `capability.md` file at the root or in a standard location:
```
https://github.com/user/metis-capability-reanimated
```

### From a Local Path

A path to a `capability.md` file:
```
/path/to/my-capability/capability.md
```

### From Another Metis Repo

A path to another metis repo's capability:
```
/path/to/other-metis/plugins/metis-core/capabilities/custom-thing/capability.md
```

## Flow

### Step 1: Fetch the Source

**Git URL:**
```bash
git clone --depth 1 {url} /tmp/metis-pull-{name}
```
Find `capability.md` in the cloned repo.

**Local path:**
Read the file directly.

### Step 2: Validate the Capability

Read the file and verify:

1. **YAML frontmatter exists** with required fields:
   - `name` (string, lowercase-hyphens)
   - `version` (string, semver format)
   - `description` (string)
   - `requires` (array of strings)
   - `provides` (array of strings)

2. **`## Agent Instructions` section exists** — this is the core content

3. **Dependencies are satisfiable** — all items in `requires` must either:
   - Already exist in the metis registry, OR
   - Be included in the same pull (if pulling multiple capabilities)

4. **No name conflict** — the name doesn't clash with an existing capability

If validation fails, show the errors and stop.

### Step 3: Show Preview

```
PULL CAPABILITY — Preview
═══════════════════════════════════════════════════

Source: {url_or_path}

Name: {name}
Version: {version}
Description: {description}
Requires: {requires}
Provides: {provides}

Agent Instructions preview:
{first 10 lines of ## Agent Instructions section}

═══════════════════════════════════════════════════

Import this capability into the metis registry?
```

### Step 4: Import

1. Create `plugins/metis-core/capabilities/{name}/capability.md` — copy the validated file
2. Update `plugins/metis-core/capabilities/registry.json` — add the entry
3. Clean up temporary files (if cloned from git)

### Step 5: Optionally Add to Profiles

Ask the user if this capability should be added to any profiles (same as `/add-capability`).

### Step 6: Report

```
CAPABILITY IMPORTED
═══════════════════════════════════════════════════

Name: {name} (v{version})
Source: {url_or_path}
File: plugins/metis-core/capabilities/{name}/capability.md
Registry: updated

Next steps:
  - Review and edit the capability file if needed
  - Run /release to include in next version
  - Consumer projects: /install --update to get it

═══════════════════════════════════════════════════
```

## Validation Errors

Common issues and how they're reported:

```
VALIDATION FAILED
═══════════════════════════════════════════════════

  ✗ Missing required frontmatter field: "provides"
  ✗ Dependency "flutter" not found in metis registry
  ✓ Name "reanimated" is available
  ✓ YAML frontmatter is valid
  ✓ ## Agent Instructions section exists

Fix these issues in the source file and try again.
═══════════════════════════════════════════════════
```

## Key Rules

<rules>
- This skill runs in the METIS REPO, not in consumer projects
- ALWAYS validate before importing — reject malformed capabilities
- NEVER auto-add to profiles without asking
- Clean up temporary git clones after import
- Preserve the original version from the source (don't reset to 0.1.0)
- If the capability already exists, ask: overwrite, skip, or merge?
</rules>
