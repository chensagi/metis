# Integration Verification Checklist

Use this checklist when verifying cross-task integration. Read `.metis/config.json` for project-specific commands.

## 1. Compilation / Type Check (CRITICAL)

Run the project's `verify_command` from `.metis/config.json` and fix ALL errors. This is the most important check.

Examples by project type:
- TypeScript: `npx tsc --noEmit`
- Python: `python -m py_compile` or `mypy .`
- Go: `go build ./...`
- Rust: `cargo check`

## 2. Import Verification

For each module created or modified by the completed tasks:
- Verify all imports point to existing files
- Check that exported names match what consumers import
- Look for circular import chains between modules

## 3. Cross-Module Dependencies

Check integration points between tasks:
- Are modules using correct imports from sibling modules?
- Do public APIs match what consumers expect?
- Are shared types/interfaces used consistently?
- Are new modules registered/wired where needed (routes, configs, etc.)?

## 4. Type / Interface Consistency

- Verify shared types are used consistently across modules
- Check that new interfaces don't shadow or conflict with existing ones
- Ensure no duplicate type definitions

## 5. Run Tests

If test_command is configured in `.metis/config.json`, run tests for the verified modules:
```
${test_command} -- [relevant test files or patterns]
```

## 6. Wiring Verification

For each new file created by completed tasks:

- **Import check**: Is the file imported by at least one other file? (`grep -r "from.*filename"`)
- **Barrel export**: If the file is in a directory with an index.ts, is it re-exported?
- **Route registration**: If it's a route handler/endpoint, is it registered in the router?
- **Navigation config**: If it's a screen/page, is it added to the navigator/router config?
- **Service registration**: If it's a service/provider, is it initialized in the app bootstrap?
- **Config entries**: If it introduces new config options, are they added to the config schema?

Files that are legitimately standalone (tests, scripts, configs) can be excluded.
Mark any unconnected file as a FAILED wiring check.

## Output Format

Provide a structured report:

### PASSED
[List integration points that work correctly]

### WARNINGS
[Non-critical issues that should be addressed]

### FAILED
[Critical integration failures that block functionality]

### FIXES APPLIED
[Any fixes you made during verification]
