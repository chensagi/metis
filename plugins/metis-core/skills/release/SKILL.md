---
name: release
description: Create a new metis release — bump version, update registry, create git tag, and optionally push.
argument-hint: [major|minor|patch] ["release notes"]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Release — Version Management

You are executing the `/release` command. This skill creates a new versioned release of metis-core with a git tag. Run this **in the metis repo**.

## Flow

### Step 1: Determine Version Bump

**If argument provided:** Use it (major, minor, or patch)
**If no argument:** Ask the user:

| Bump | When | Example |
|------|------|---------|
| `patch` | Bug fixes, typo corrections, minor capability updates | 0.1.0 → 0.1.1 |
| `minor` | New capabilities, new skills, new profiles | 0.1.0 → 0.2.0 |
| `major` | Breaking changes to capability format, config schema, or skill APIs | 0.1.0 → 1.0.0 |

### Step 2: Read Current Version

1. Read `plugins/metis-core/.claude-plugin/plugin.json` → current version
2. Read `plugins/metis-core/capabilities/registry.json` → current registry version
3. Check latest git tag: `git describe --tags --abbrev=0 2>/dev/null || echo "no tags"`

### Step 3: Calculate New Version

Apply semver bump to the current version.

### Step 4: Show Release Summary

```
METIS RELEASE
═══════════════════════════════════════════════════

Version: {old} → {new}
Tag: v{new}

Changes since last release:
{git log --oneline since last tag}

Files changed:
{git diff --stat since last tag}

Capability versions:
  typescript    0.1.0
  react-native  0.1.0
  expo          0.1.0
  ...

═══════════════════════════════════════════════════

Proceed with release?
```

### Step 5: Apply Version Bump

1. Update `plugins/metis-core/.claude-plugin/plugin.json` → new version
2. Update `plugins/metis-core/capabilities/registry.json` → new registry version

### Step 6: Commit and Tag

```bash
git add plugins/metis-core/.claude-plugin/plugin.json plugins/metis-core/capabilities/registry.json
git commit -m "$(cat <<'EOF'
Release v{new}

{release notes}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
git tag -a v{new} -m "Release v{new}: {release notes}"
```

### Step 7: Optionally Push

Ask the user if they want to push:
```bash
git push origin main --tags
```

### Step 8: Report

```
RELEASED v{new}
═══════════════════════════════════════════════════

Tag: v{new}
Commit: {short_sha}
{pushed ? "Pushed to origin" : "Not pushed — run: git push origin main --tags"}

Consumer projects can upgrade:
  /install --update

═══════════════════════════════════════════════════
```

## Key Rules

<rules>
- This skill runs in the METIS REPO, not in consumer projects
- NEVER skip the version summary step — user must approve before tagging
- NEVER force-push or delete tags
- Tag format is always `v{X.Y.Z}` (e.g., `v0.2.0`)
- Include release notes in both the commit message and tag annotation
- Individual capability versions are NOT bumped automatically — they have their own versioning
</rules>
