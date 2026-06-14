# ios-qa

Spec-driven visual QA for iOS apps. Reads your task specs, verifies each acceptance criterion through the simulator, and applies an opinionated User Complaint Filter — the kind of things a real user would notice and complain about.

Originally extracted from a production React Native / Expo project, generalized so any iOS app can plug in.

## What's in the bundle

| Skill | Command | Purpose |
|-------|---------|---------|
| `ios-qa` | `/ios-qa` | Spec-driven visual QA against a running simulator. Four modes: spec, general, PR/branch, on-branch. |
| `qa` | `/qa` | Lightweight QA session manager — enter/exit/refresh a PR, worktree, or branch with stash + return-branch handling. |
| `qa-batch` | `/qa-batch` | Iterate open PRs, run visual QA + code review on each, post findings as PR comments, auto-label clean PRs. |
| `ios-fixer` | `/ios-fixer` | Root-cause bug analyzer + fixer. Called by `ios-qa` when an issue is beyond a one-line style fix. |

## Requirements

### iOS Simulator MCP server (bundled)

The `ios-qa` and `ios-fixer` skills drive the simulator through MCP tools named `mcp__ios-simulator__*`. The plugin bundles the [`ios-simulator-mcp`](https://www.npmjs.com/package/ios-simulator-mcp) server via `.mcp.json` — Claude Code starts it automatically when you enable the plugin (`npx -y ios-simulator-mcp`). No separate `claude mcp add` step needed.

The bundled server exposes:

```
mcp__ios-simulator__get_booted_sim_id
mcp__ios-simulator__launch_app
mcp__ios-simulator__screenshot
mcp__ios-simulator__ui_view
mcp__ios-simulator__ui_describe_all
mcp__ios-simulator__ui_describe_point
mcp__ios-simulator__ui_tap
mcp__ios-simulator__ui_swipe
mcp__ios-simulator__ui_type
```

If you'd rather wire your own server, override the name `ios-simulator` in your project's `.mcp.json` — the skills only depend on the tool prefix.

### Tooling

- macOS with Xcode + the iOS Simulator
- `gh` CLI (used by `qa`, `qa-batch`, and PR mode of `ios-qa`)
- **idb (iOS Development Bridge)** — used by the bundled MCP server for UI interaction and element inspection. Install via:
  ```bash
  brew tap facebook/fb
  brew install idb-companion
  pip3 install fb-idb
  ```
- **cwebp** (optional, `brew install webp`) — for AI-optimized WebP evidence compression. Without it, the skill automatically falls back to JPEG via `sips` (ships with macOS).
- **Accessibility permission** (iPad mode only) — `rotate.sh` drives Simulator.app rotation via `osascript`; grant the terminal/app running Claude Code Accessibility permission once at System Settings → Privacy & Security → Accessibility.
- A bundler that supports hot reload (Metro/Expo, or your equivalent) running locally on the URL you configure
- The Metis plugin / `.metis/tasks/` directory if you want spec mode (`/ios-qa <task-number>`)

## Install

```bash
/plugin marketplace add chensagi/metis
/plugin install ios-qa@metis
```

## Configure

Create `.claude/ios-qa.json` in your project root. The skills read this file at runtime — without it, they'll prompt you to create one and stop.

```json
{
  "bundleId": "com.example.myapp",
  "appName": "MyApp",
  "metroUrl": "http://localhost:8081/status",
  "metroReadyMarker": "packager-status:running",
  "defaultBranch": "main",
  "taskDir": ".metis/tasks",
  "smokeScreens": ["Home", "Profile", "Settings"],
  "fileToScreenMap": {
    "src/screens/Home.tsx": "Home",
    "src/screens/Profile.tsx": "Profile",
    "src/components/Card.tsx": "Home"
  },
  "projectPitfalls": [],
  "iphoneSimulator": "iPhone 17 Pro Max",
  "ipadSimulator": "iPad Pro 13-inch (M5)",
  "rotationAllowList": []
}
```

### Field reference

| Field | Required | What it does |
|-------|----------|--------------|
| `bundleId` | yes | iOS bundle identifier — passed to `mcp__ios-simulator__launch_app`. |
| `appName` | yes | Human name used in reports and PR comments. |
| `metroUrl` | no | URL polled to check the bundler is up. Default `http://localhost:8081/status`. |
| `metroReadyMarker` | no | Substring that must appear in the bundler's response to consider it ready. Default `packager-status:running`. Set to `""` if any 200 response means ready. |
| `defaultBranch` | no | Base branch used for diff scope and rebase. Default `main`. |
| `taskDir` | no | Directory holding task specs (used by spec mode). Default `.metis/tasks`. |
| `smokeScreens` | no | Screens scanned in smoke mode and as a baseline in on-branch mode. |
| `fileToScreenMap` | no | Maps changed files (or glob-like patterns) to affected screens. Used by PR mode to scope the scan. The more accurate this is, the less work the skill does on each PR. |
| `projectPitfalls` | no | Free-form list of project-specific code-review checks. Each entry is shown as a checkbox in `qa-batch` review comments. Example: `"No ES5 getters in persisted Zustand stores"`. |
| `iphoneSimulator` | no | Simulator device name booted on default runs. Default `iPhone 17 Pro Max`. Must match a device in `xcrun simctl list devices`. |
| `ipadSimulator` | no | Simulator device name booted on `--device ipad` runs. Default `iPad Pro 13-inch (M5)`. |
| `rotationAllowList` | no | Screens allowed to rotate on iPad, e.g. `[{ "screen": "Detail modal", "reflowSurface": "chart WebView" }]`. Empty = everything locked portrait. See the skill's `ipad-policy.md`. |

### Env var fallback

If you'd rather not commit the config file, set these env vars instead (the skill checks env first, then the config file):

```
IOS_QA_BUNDLE_ID=com.example.myapp
IOS_QA_APP_NAME=MyApp
IOS_QA_METRO_URL=http://localhost:8081/status
IOS_QA_DEFAULT_BRANCH=main
```

`fileToScreenMap` and `smokeScreens` only come from the config file.

## Usage

### Verify a completed task

```
/ios-qa 130
```

Reads `.metis/tasks/done/130-*.md`, parses the acceptance-criteria checklist, navigates the simulator, and writes a pass/fail matrix.

### General scan

```
/ios-qa              # default scan + opinionated UX filter
/ios-qa smoke        # quick smoke: launch + each tab + one modal
/ios-qa full         # every screen including scroll + sub-views
```

### QA a pull request

```
/ios-qa --from-pr 185        # checkout PR 185, scope to changed screens, post report as PR comment
/ios-qa --from-pr feat/x     # same, for a branch name (no PR comment — output goes to terminal)
```

### iPad layout + rotation audit

```
/ios-qa --device ipad              # full run on the iPad simulator + orientation policy audit
/ios-qa 130 --device ipad          # spec mode on iPad
```

Every screen gets an extra rotation check: locked-portrait screens must not rotate, allow-listed screens must rotate AND reflow their content. Requires the one-time Accessibility permission (see Requirements).

### Evidence trail

```
/ios-qa --evidence-dir docs/qa-evidence/2026-06-12    # persist screenshot + element dump per screen
/ios-qa --evidence-dir <path> --full-res              # keep raw PNGs (for human review)
```

By default evidence is compressed to ~784 px WebP (JPEG fallback) — optimized for re-reading by AI in later sessions at ~4× lower token cost. Scheduled callers like `/qa-batch` use this to prove visual-QA claims after the fact.

### Batch PR review

```
/qa-batch                    # all open PRs
/qa-batch 241 242            # specific PRs
/qa-batch --dry-run          # plan without running
```

### Manual QA session (no simulator required)

```
/qa 221                      # check out PR 221 into a clean qa/* branch, stash dirty state
/qa refresh                  # pull latest from source, preserve your QA commits
/qa exit                     # cherry-pick summary + restore previous branch
```

## The User Complaint Filter

QA scans apply an opinionated filter that flags anything a real user would notice:

- **Tier 1 (Instant Uninstall):** broken layout, blank screens, raw values (`NaN`, `undefined`, `[object Object]`), dead buttons, trapped states, crashes.
- **Tier 2 (One-Star Review):** placeholder content, misaligned elements, wrong empty states, truncated labels, inconsistent visual language, wrong numbers.
- **Tier 3 (Friction):** tiny touch targets, no loading feedback, date format inconsistencies, scroll position resets.

Tier 1 and 2 issues are blockers — the skill stops and fixes or escalates before moving on.

## Notes for plugin authors

- `ios-qa` calls `Skill("ios-fixer", ...)` for escalations. If you disable `ios-fixer` in your install, complex bugs will be reported but not fixed.
- The skills never restart Expo, Metro, or the simulator process — all fixes go through Edit + hot reload.
- Branch restoration in `qa` and PR mode of `ios-qa` is mandatory — both skills always return to the original branch before exiting, even on failure.

## Differences from the original

This plugin is a generalized extract of an in-house QA suite. The main changes:

1. **App identity** (bundle ID, app name) moved to config, no longer hardcoded.
2. **File → Screen mapping** is project-supplied. The original shipped with a mapping table for one app; here it's empty by default with a few example entries in the README.
3. **GitHub repo** is auto-detected via `gh` CLI (`:owner/:repo`), so the skill works against whatever repo the user runs it in.
4. **Project-specific code-review pitfalls** were removed from `qa-batch` and replaced with the optional `projectPitfalls` config field — bring your own.
5. **Default branch** is configurable (the original was hardcoded to `main`).
6. **Metro readiness** check is configurable for non-Expo projects.
7. **Simulator device names** (`iphoneSimulator` / `ipadSimulator`) moved to config; device boot uses plain `xcrun simctl` instead of a project-local script.
8. **iPad rotation allow-list** moved to the `rotationAllowList` config key + a codebase discovery grep, replacing a hardcoded screen list.
9. **PR labels** (`rebuild-required` / `native-verified`) degrade gracefully — if the labels don't exist in your repo, the skill falls back to comment-only.

## Troubleshooting

### `idb` connection errors / missing dependencies
- Verify the companion is running: `idb list-targets`
- If target is missing, start/connect it: `idb connect <udid>` or restart the daemon: `idb kill && idb list-targets`
- Ensure python dependencies are correct: `pip3 install fb-idb` and `idb-companion` is up to date via Homebrew.
