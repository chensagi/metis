---
name: maestro
version: 0.1.0
description: Maestro E2E test automation — YAML flows, testID conventions, debug output
requires: [ios-simulator]
provides:
  - e2e-testing
  - maestro-flows
  - ui-automation
commands:
  test_all: "maestro test .maestro/flows/"
  test_single: "maestro test {flow_path}"
  test_debug: "maestro test --debug-output {debug_dir} {flow_path}"
---

# Maestro Capability

## Agent Instructions

This project uses Maestro for E2E UI testing. Maestro automates mobile app interactions using YAML flow files.

### YAML Flow Structure

```yaml
appId: {bundle_id}
---
# 1. SETUP
- launchApp:
    clearState: true    # Optional: fresh start

# 2. NAVIGATE
- tapOn:
    id: "{testID}"      # Preferred: use testID
- tapOn:
    text: "Button Text"  # Fallback: use visible text

# 3. WAIT
- extendedWaitUntil:
    visible:
      id: "{testID}"
    timeout: 5000

# 4. ASSERT
- assertVisible:
    id: "{expected_element}"

# 5. SCREENSHOT
- takeScreenshot: verify-{name}
```

### testID Conventions

Always verify testIDs exist in the codebase before using them in flows:
```bash
grep -r "testID=" --include="*.tsx" --include="*.jsx" src/ app/
```

Common testID patterns (project-specific — check the codebase):
- Navigation: `tab-{name}`, `nav-{name}`
- Cards/Items: `{type}-card-{id}`, `{type}-item-{id}`
- Buttons: `{action}-button-{id}`
- Modals: `{name}-modal`
- Inputs: `{name}-input`

### Expo Development Build Handling

If the project uses Expo development builds, `clearState: true` triggers the Expo launcher screen. Handle it with this sequence:

```yaml
- launchApp:
    clearState: true
- extendedWaitUntil:
    visible: "http://localhost:8081"
    timeout: 10000
    optional: true
- tapOn:
    text: "http://localhost:8081"
    optional: true
- extendedWaitUntil:
    visible: "{app_name}"
    timeout: 30000
- extendedWaitUntil:
    visible: "Continue"
    timeout: 20000
- tapOn:
    text: "Continue"
- tapOn:
    point: "50%,10%"
```

Skip this sequence for production builds or when not using `clearState`.

### Running Tests

```bash
# Run all flows
maestro test .maestro/flows/

# Run a specific flow
maestro test .maestro/flows/smoke/home.yaml

# Run with debug output (screenshots + logs)
mkdir -p ~/.maestro/debug-output
maestro test --debug-output ~/.maestro/debug-output .maestro/flows/smoke/home.yaml
```

### Writing New Tests

1. Check `.maestro/` directory for existing testID documentation
2. Verify testIDs exist with `grep` before writing flows
3. Use `extendedWaitUntil` before assertions (async UI)
4. Set appropriate timeouts (5s for navigation, 30s for app launch)
5. Write flows to temporary paths for one-off verification: `/private/tmp/test-verify-*.yaml`

### Debugging Failures

- Use `--debug-output` to capture screenshots at each step
- Check that the app is running and simulator is booted
- Verify Metro/dev server is active on the expected port
- Common issue: testID doesn't exist or is on a hidden element
