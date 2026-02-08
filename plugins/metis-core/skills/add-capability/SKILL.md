---
name: add-capability
description: Add a new capability to the metis-core registry. Creates the capability file, updates registry.json, and optionally adds it to profiles.
argument-hint: [capability-name] ["description"]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Add Capability — Registry Management

You are executing the `/add-capability` command. This skill creates a new capability in the metis-core registry. Run this **in the metis repo** (not in a consumer project).

## Flow

### Step 1: Gather Details

**If arguments provided:**
- First word = capability name (lowercase, hyphens)
- Rest = description

**If no arguments:**
Use `AskUserQuestion` to ask:
1. Capability name (slug format)
2. Description (one line)
3. What technologies/tools does it cover?
4. Does it require other capabilities? (list names)
5. What commands does it provide? (verify, test, etc.)

### Step 2: Check for Conflicts

1. Read `plugins/metis-core/capabilities/registry.json`
2. Verify the name doesn't conflict with existing capabilities
3. Check if a similar capability already exists (grep for the technology name)

### Step 3: Create Capability Directory and File

Create `plugins/metis-core/capabilities/{name}/capability.md`:

```markdown
---
name: {name}
version: 0.1.0
description: {description}
requires: [{dependencies}]
provides:
  - {feature-tag-1}
  - {feature-tag-2}
commands:
  {command_name}: "{command}"
---

# {Name} Capability

## Agent Instructions

{Instructions that will be injected into agent prompts when this capability is active}
```

### Step 4: Update Registry

Add the new capability to `plugins/metis-core/capabilities/registry.json`:

```json
"{name}": {
  "version": "0.1.0",
  "description": "{description}",
  "requires": [{dependencies}],
  "path": "{name}/capability.md"
}
```

### Step 5: Optionally Add to Profiles

Ask the user if this capability should be added to any existing profiles:
- Show the list of profiles
- For each selected profile, add to either `capabilities` (required) or `optional_capabilities`

### Step 6: Report

```
CAPABILITY ADDED
═══════════════════════════════════════════════════

Name: {name}
Version: 0.1.0
File: plugins/metis-core/capabilities/{name}/capability.md
Registry: updated
Profiles: {list of profiles updated, or "none"}

Next steps:
  - Edit the capability file to refine Agent Instructions
  - Run /release to tag a new version with this capability
  - Consumer projects: /install --update to get the new capability

═══════════════════════════════════════════════════
```

## Key Rules

<rules>
- This skill runs in the METIS REPO, not in consumer projects
- Capability names must be lowercase with hyphens
- Always start at version 0.1.0 for new capabilities
- The `requires` field must reference capabilities that exist in the registry
- The `## Agent Instructions` section is required — it's what agents actually read
</rules>
