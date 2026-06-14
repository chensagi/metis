---
name: ios-qa
description: Spec-driven visual QA that reads task specs and verifies each acceptance criterion through the UI. Opinionated — flags anything a real user would complain about. Fixes simple issues, escalates complex ones, stops on blockers.
argument-hint: <task# | smoke | full | --from-pr PR#|branch | --on-branch branch --screens list> [--device iphone|ipad] [--evidence-dir <path>] [--full-res]
allowed-tools:
  - Skill
  - Write
  - Read
  - Read(/tmp/*)
  - Read(/private/tmp/*)
  - Grep
  - Glob
  - Edit
  - mcp__ios-simulator__ui_view
  - mcp__ios-simulator__ui_describe_all
  - mcp__ios-simulator__ui_tap
  - mcp__ios-simulator__ui_swipe
  - mcp__ios-simulator__screenshot
  - mcp__ios-simulator__get_booted_sim_id
  - mcp__ios-simulator__launch_app
  - Bash(curl:*)
  - Bash(sleep:*)
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(xcrun:*)
  - Bash(open:*)
  - Bash(mkdir:*)
  - Bash(sips:*)
  - Bash(cwebp:*)
  - Bash(bash:*)
disable-model-invocation: false
---

# ios-qa — Spec-Driven Visual QA

**Spec-driven QA: Read the spec → Verify each criterion through the UI → Flag what users would hate.**

## Configuration (read this first)

Before doing anything else, load the project config. Skills in this plugin are app-agnostic — they expect a config file or env vars.

**Load order:**

1. Read `.claude/ios-qa.json` if it exists.
2. Override any present key with env vars: `IOS_QA_BUNDLE_ID`, `IOS_QA_APP_NAME`, `IOS_QA_METRO_URL`, `IOS_QA_DEFAULT_BRANCH`.
3. If `bundleId` is still missing, stop with:

   ```
   ios-qa is not configured. Create .claude/ios-qa.json with at least
   { "bundleId": "...", "appName": "..." }. See the plugin README.
   ```

**Keys you'll use throughout this skill:**

| Key | Default | Used for |
|-----|---------|----------|
| `bundleId` | (required) | `mcp__ios-simulator__launch_app(bundle_id=…)` |
| `appName` | (required) | report headings, PR comments |
| `metroUrl` | `http://localhost:8081/status` | bundler readiness probe |
| `metroReadyMarker` | `packager-status:running` | substring to look for in response |
| `defaultBranch` | `main` | diff scope, rebase target |
| `taskDir` | `.metis/tasks` | spec lookup |
| `smokeScreens` | `[]` | smoke mode + on-branch baseline |
| `fileToScreenMap` | `{}` | PR/branch scope mapping |
| `iphoneSimulator` | `iPhone 17 Pro Max` | device booted on default runs |
| `ipadSimulator` | `iPad Pro 13-inch (M5)` | device booted on `--device ipad` runs |
| `rotationAllowList` | `[]` | screens that may rotate on iPad (see [ipad-policy.md](ipad-policy.md)) |

Treat the config as immutable for the duration of one run. If a key is missing and has no default, mark the dependent feature as "skipped — not configured" in the report rather than crashing.

## Modes

1. **Spec mode** (`/ios-qa <task-number>`) — Reads the task spec, extracts acceptance criteria, and verifies each one through the simulator. Primary mode.
2. **General mode** (`/ios-qa`, `/ios-qa smoke`, `/ios-qa full`) — Scans screens without a spec. Still applies the User Complaint Filter.
3. **PR/Branch mode** (`/ios-qa --from-pr <PR#|branch>`) — Checks out a PR or branch, lets the bundler hot-reload, runs QA focused on changed screens.
4. **On-branch mode** (`/ios-qa --on-branch <branch> --screens <list>`) — Runs QA on a branch already checked out, scoped to a comma-separated screen list. Output goes to stdout only; never posts a PR comment.

All modes apply the **User Complaint Filter** — a hard blocker list of things that are objectively bad UX. If any are found, QA stops and demands a fix before proceeding.

```
1. LOAD SPEC — Read task file, extract acceptance criteria
2. PLAN — Map each criterion to screens and UI assertions
3. VERIFY — Navigate, screenshot, check each criterion pass/fail
4. COMPLAIN — Apply opinionated UX filter on every screen visited
5. FIX/ESCALATE — Fix simple issues, escalate complex ones
6. REPORT — Final spec verification matrix
```

### Flags (combinable with any mode)

| Flag | Effect |
|------|--------|
| `--device iphone\|ipad` | Which simulator to boot. Default `iphone`. `ipad` adds the orientation Verify step on every screen — see **iPad Mode**. |
| `--evidence-dir <path>` | Persist a screenshot + element dump per scanned screen — see **Evidence Persistence**. |
| `--full-res` | With `--evidence-dir`: keep raw PNGs instead of AI-optimized compression (for human review). |

### Spec Mode: `/ios-qa <task-number>`

Reads a completed task spec and verifies it was implemented correctly.

```
/ios-qa 130
/ios-qa 126
```

**How it works:**

1. Read `<taskDir>/done/<number>-*.md` (or `doing/`, then `todo/`)
2. Parse the acceptance-criteria checklist (lines matching `- [ ]` / `- [x]`)
3. Classify each criterion as **UI**, **Behavior**, **Code**, or **Non-verifiable**
4. For UI/Behavior criteria: navigate, screenshot, verify
5. For Code criteria: verify via Grep/Read (e.g., "All types pass tsc")
6. Output a pass/fail matrix at the end

### General Mode: `/ios-qa [full|smoke]`

```
/ios-qa            # default scan + opinionated checks
/ios-qa full       # every screen + scroll + sub-views
/ios-qa smoke      # app launches, tabs load, one modal
```

### PR/Branch Mode: `/ios-qa --from-pr <PR#|branch>`

Checks out a PR or branch, waits for the bundler to hot-reload, then runs targeted QA on the affected screens. Assumes the bundler is already running in another terminal.

```
/ios-qa --from-pr 185       # numeric → PR #185, posts report as PR comment
/ios-qa --from-pr feat/xyz  # branch name → output to terminal (no PR comment)
```

## Core Principles

1. **The spec is the test oracle.** In spec mode, acceptance criteria ARE your test cases. Don't invent extra checks.
2. **Be the user, not the developer.** Pretend you just downloaded this app. Does it look professional? Can you figure out what to do? Does anything look broken?
3. **Blockers stop everything.** Tier 1/2 issues halt the scan until fixed.
4. **Every screenshot gets analyzed.** Output a Mandatory Analysis Block after every `ui_view`.
5. **Verify every fix** with `ui_view` + `ui_describe_all` + analysis block.

## The User Complaint Filter

Things a real user would immediately notice and complain about. If you see ANY of these, it's a BLOCKER.

### Tier 1: Instant Uninstall (CRITICAL)

| Issue | What It Looks Like | Why Users Hate It |
|-------|-------------------|-------------------|
| **Broken layout** | Elements overlapping, content spilling off-screen, stacked cards | "This app is broken" |
| **Blank screen** | Nothing visible — no content, no loading indicator, no empty state | "Is this even working?" |
| **Unreadable text** | Too small, low contrast, same color as background, clipped | "I can't read anything" |
| **Dead buttons** | Tap something interactive and nothing happens | "Nothing works" |
| **Trapped state** | Modal or screen with no way to dismiss | "I'm stuck" |
| **Crash or freeze** | App stops responding | "Garbage app" |
| **Raw data values** | `NaN`, `undefined`, `null`, `[object Object]`, raw ISO dates | "This is a dev build" |
| **Rotation leaked from locked screen** *(iPad mode)* | After `rotate.sh right`, a screen NOT on the rotation allow-list actually rotates (width > height in `ui_describe_all`) | "Half the UI is off-screen in landscape" |
| **Reflow surface ignores rotation** *(iPad mode)* | An allow-listed screen rotates but its main content surface (e.g., a chart WebView) keeps its portrait width | "The content is a tiny square on my big screen" |

### Tier 2: One-Star Review (HIGH)

| Issue | What It Looks Like |
|-------|-------------------|
| **Placeholder content** | "Lorem ipsum", "TODO", "Test", "asdf" |
| **Inconsistent spacing** | 16px padding here, 8px there, 24px somewhere else |
| **Misaligned elements** | Text not vertically centered, icons at different heights |
| **Wrong empty state** | Empty list with no message — just blank space |
| **Truncated labels** | "FruitTe...", "$12,345.6" with the last digit missing |
| **Giant empty space** | Huge gap in the middle of a screen for no reason |
| **Scroll doesn't work** | Content continues below the fold but can't be scrolled to |
| **Inconsistent visual language** | Some rounded, some square; mixed icon styles; different cards |
| **Wrong numbers** | $0.00 for a real price, 0% change when the market clearly moved |
| **Modal/sheet misposition on iPad** *(iPad mode)* | A modal/sheet renders phone-sized, floating in the center of the iPad screen with huge gutters, or anchored in a way that only makes sense on a phone |
| **Fixed-width column with huge gutters on iPad** *(iPad mode)* | Content column hardcoded at ~320–400 px in the middle of a 13" iPad screen, most of the screen empty background |

### Tier 3: Friction (MEDIUM)

| Issue | What It Looks Like |
|-------|-------------------|
| **Tiny touch targets** | Buttons smaller than 44×44pt |
| **No loading feedback** | Action triggered but no spinner, skeleton, or indication |
| **Inconsistent formatting** | Mixing "Jan 5" and "2020-01-05" on the same screen |
| **Orphaned elements** | A single item in a list, section header with nothing under it |
| **Scroll position reset** | Navigate away and back, scroll position lost |

### How to Apply the Filter

On EVERY screenshot, mentally ask:

> "If I just downloaded this app and saw this screen, what would I complain about?"

Tier 1 or 2 → BLOCKERS. Tier 3 → ISSUES.

## Mandatory Analysis Block

After every `ui_view` call, output this block BEFORE taking any other action:

```
SCREEN: [screen name]
OBSERVED: [factual description of what the screenshot shows — not what you expect]
STRUCTURAL: [ui_describe_all summary — element count, key elements present/missing]
SPEC CHECK: [if in spec mode: which criteria this screen covers, pass/fail each]
BLOCKERS: [Tier 1 or 2 User Complaint items — or "none"]
ISSUES: [Tier 3 items or minor issues — or "none"]
ACTION: [what to do next]
```

**Rules:**
- OBSERVED must describe what you **actually see**, not what you expect.
- SPEC CHECK only in spec mode. List each criterion + status.
- BLOCKERS trigger an immediate stop — fix/escalate before continuing.
- If the screen scrolls, output a SECOND block for below-fold content.
- iPad mode adds a ROTATION line — see **iPad Mode → Orientation Verify step**.

## Evidence Persistence

When invoked with `--evidence-dir <path>`, ios-qa writes a tamper-evident audit trail for every screen it scans. Scheduled callers (e.g., `/qa-batch`) use this to prove their visual-QA claims after the fact — without it, the recorded verdict is unverifiable.

**Setup (once per run, in PHASE 0):**

```python
evidence_dir = extract_flag_value($ARGUMENTS, "--evidence-dir")  # None if not passed
if evidence_dir:
    Bash(f"mkdir -p {evidence_dir}")
    screen_counter = {}  # screen-slug -> int, for disambiguating repeat visits
```

**Per screen — after every `ui_view` scan, in ANY mode** (Spec Mode PHASE 2, each stop of a
General/Smoke scan, On-Branch targeted scans):

```python
if evidence_dir:
    # `screen` = the screen name you're scanning. Spec mode: from group_by_screen.
    # General mode: the configured smokeScreens / fileToScreenMap name (e.g.
    # "Home", "Settings"). Smoke mode: "App launches" -> the screen it actually
    # opened on; "Each tab" -> one capture per tab, named by tab. Never invent
    # new names for the same screen across visits — the suffix counter handles repeats.
    slug = re.sub(r'[^a-z0-9]+', '-', screen.lower()).strip('-')
    screen_counter[slug] = screen_counter.get(slug, 0) + 1
    suffix = "" if screen_counter[slug] == 1 else f"-{screen_counter[slug]}"
    raw = f"/tmp/qa-raw-{slug}{suffix}.png"        # full-res original stays in /tmp
    mcp__ios-simulator__screenshot(output_path=raw)
    compress_evidence(raw, f"{evidence_dir}/{slug}{suffix}")   # skip if --full-res:
                                                   # then save the PNG to evidence_dir directly
    Write(f"{evidence_dir}/{slug}{suffix}.describe.json", json.dumps(elements, indent=2))
```

Capturing the raw PNG to `/tmp` and compressing INTO the evidence dir means no `rm` is ever
needed, and the full-res original survives the run — free source material for forensic crops.
`/tmp` is wiped by the OS on reboot; do NOT add your own cleanup step.

If `--evidence-dir` is not set, skip persistence entirely — the inline screenshot in model context is the only capture (default behavior, no extra disk I/O).

**Hard rule:** if `--evidence-dir` is set and any screenshot or describe write fails, that's a blocker — write `status: evidence_persist_failed` to the report and stop. A run with a half-written evidence dir is worse than no evidence dir at all (looks like proof, isn't). Compression failure is NOT a blocker — keep the full-res PNG and move on (evidence intact, just bigger).

### AI-Optimized Compression

Evidence screenshots exist to be re-read by AI in later sessions (batch audits, regression
comparisons, "what did this screen look like" questions). Full-res simulator PNGs are the wrong
storage format for that consumer, for two researched reasons:

1. **The vision API discards extra resolution anyway.** Claude downscales images to ≤1568 px on
   the long edge (~1.15 MP) before tokenizing — a 1320×2868 sim PNG is silently reduced ~55% at
   read time. Anthropic's own guidance: pre-resize, since larger inputs only add latency.
2. **Vision tokens scale with pixel area** (≈ w×h/750). A full-res shot costs ~1,500 tokens per
   read; a 784 px copy costs ~380. Compressed evidence lets a future session hold ~4× more
   screens in context.

Empirically validated on a production dark-UI app: at 784 px every price, percentage, chip, and
tab label stays legible — even the comma in "1,614" survives. Legibility floor is ~560 px / q50;
below that, small grey-on-dark labels become guesswork.

`compress_evidence(raw, dest)` — `raw` is the full-res /tmp capture, `dest` is the
evidence-dir path WITHOUT extension. Substitute both concrete paths before running (no shell
variables left in the command; no `#` comments in the block, per the Bash safety rule). Use
`--resampleWidth 784` instead when the shot is landscape (iPad rotation captures): the resample
flag targets the LONG edge. The `||` chain IS the cwebp-missing fallback — `cwebp` exiting 127
(not installed) falls through to the sips JPEG branch; no existence check needed.

```bash
sips --resampleHeight 784 /tmp/qa-raw-home.png --out /tmp/qa-784-home.png
cwebp -q 70 /tmp/qa-784-home.png -o <dest>.webp || sips -s format jpeg -s formatOptions 60 /tmp/qa-784-home.png --out <dest>.jpg
```

Format choice, from testing both: **WebP q70 beats JPEG q60** on flat dark UI — 2.5× smaller
(~16 KB vs ~42 KB per screen) AND cleaner (no JPEG ringing around thin glyphs like commas and
percent signs). JPEG is the dependency-free fallback (`sips` ships with macOS but cannot write
WebP; `cwebp` is Homebrew). Both formats are natively supported by the Claude API and the Read
tool. Measured cost: ~60 ms per image — negligible even across a full multi-screen sweep.

**Rules:**
- **Forensic crops come from the raw, never the compressed file.** If a finding needs
  pixel-level zoom (glyph ambiguity, 1-px misalignment), crop from the full-res `/tmp` capture
  and save the crop as lossless PNG in the evidence dir (`<slug>-crop-<what>.png`) — /tmp is
  wiped on reboot, the evidence dir is the durable record. Lossy artifacts destroy zoom-ability
  permanently.
- Never resize below 560 px on the long edge or quality below 50 — and never below 200 px on
  either edge (degrades model performance per Anthropic docs).
- `--full-res` flag skips compression entirely (keep raw PNGs) for runs where a human will
  inspect the evidence in an image viewer.
- `.describe.json` files are untouched — they are already the cheap, lossless ground truth for
  text content; the image only needs to carry layout and rendering. If the MCP
  `ui_describe_all` tool is unavailable (script-fallback environments), persist the FULL
  element tree from `idb ui describe-all --json` — not a summarized subset that drops
  StaticText/GenericElement labels.

## iPad Mode

`--device ipad` runs QA against the simulator named by the `ipadSimulator` config key (default `iPad Pro 13-inch (M5)`). Default runs (`--device iphone` or no flag) use `iphoneSimulator` (default `iPhone 17 Pro Max`) and behave exactly as before.

The flag adds three things on top of the iPhone workflow:
1. Device-aware **boot** in PHASE 0.
2. An **orientation Verify step** that runs after the portrait analysis block on every screen.
3. **Device + Rotation columns** in the report.

It also widens scope detection: any change touching orientation, rotation-reflow surfaces, or modals/sheets forces a FULL iPad pass (Global-change trigger, below).

The allow-list of screens that *may* rotate comes from the `rotationAllowList` config key, validated against the codebase by the discovery procedure in [ipad-policy.md](ipad-policy.md). Every screen not on the list must stay portrait on iPad.

### Device boot (referenced from PHASE 0 of every mode)

Replaces the lone `mcp__ios-simulator__get_booted_sim_id()` call. Boot logic for both devices:

```python
# Decide target device from the --device flag + config
device_flag = extract_flag_value($ARGUMENTS, "--device") or "iphone"
target_name = {
    "iphone": config.get("iphoneSimulator", "iPhone 17 Pro Max"),
    "ipad":   config.get("ipadSimulator", "iPad Pro 13-inch (M5)"),
}[device_flag]

# If the wrong simulator type is booted, boot the target. Otherwise reuse it.
booted = mcp__ios-simulator__get_booted_sim_id()
booted_info = Bash("xcrun simctl list devices booted") if booted else ""
if target_name not in booted_info:
    Bash(f'xcrun simctl boot "{target_name}"')   # errors clearly if no such simulator exists
    Bash("open -a Simulator")                    # bring the Simulator UI forward for screenshots
    Bash("sleep 5")                              # let the device finish booting

# Launch app. If launch fails with "app not installed", bail with a clear
# message: "<target_name> has never built the app — rebuild against it first
# (e.g., `npx expo run:ios` or your project's build command), then re-run."
# This mirrors the PR-mode native-changes guard.
mcp__ios-simulator__launch_app(bundle_id=bundle_id)
Bash("sleep 3")
```

### Orientation Verify step (referenced from PHASE 2 of every mode)

Runs **after** the existing portrait analysis block for the screen, **before** moving to the next screen. Skip entirely on `--device iphone` runs.

`rotate.sh` ships next to this SKILL.md — resolve it from this skill's base directory (shown when the skill loads) and call it with `bash`.

```python
# Determine the policy for this screen
is_rotation_allowed = screen in config.get("rotationAllowList", [])

# Rotate right and re-observe
Bash(f"bash {skill_dir}/rotate.sh right")
Bash("sleep 1")
mcp__ios-simulator__ui_view()
elements_rotated = mcp__ios-simulator__ui_describe_all()

# Output a SECOND analysis block — same format as the below-fold case — with
# a ROTATION line stating expected vs actual policy.
# e.g. ROTATION: locked-portrait, actual locked ✓
# or:  ROTATION: locked-portrait, actual rotated ✗ → Tier 1 blocker
# or:  ROTATION: allowed, reflow surface resized ✓
# or:  ROTATION: allowed, reflow surface width unchanged → Tier 1 blocker

w, h = elements_rotated.frame_size  # from ui_describe_all root frame
device_rotated = w > h

if is_rotation_allowed:
    # Allow-list screen MUST rotate AND reflow its contents
    if not device_rotated:
        blocker("Allow-list screen did not rotate when expected.")
    else:
        # Verify the rotation contract: the screen's main content surface
        # (chart, WebView, media view — see ipad-policy.md) must report a
        # width close to the new landscape width, not its old portrait width.
        verify_reflow(elements, elements_rotated)
else:
    # Locked-portrait screen MUST stay portrait
    if device_rotated:
        blocker("Rotation leaked from locked-portrait screen (Tier 1).")

# Restore portrait for the next screen
Bash(f"bash {skill_dir}/rotate.sh left")
Bash("sleep 1")
```

The `blocker(...)` call hands off to the same Loop Control path as a User Complaint Blocker — pause scanning, attempt a fix or escalate, verify, then resume.

### Global-change trigger — orientation / iPad layout

Add to the PR/Branch Mode PHASE 1 scope-detection logic. If the changed-file list matches any of these, force a FULL scan **on iPad runs** (a single touched modal can break layouts across the whole iPad surface, so the targeted-screen heuristic isn't safe):

- Any call site of `ScreenOrientation.*` / `OrientationLock` / `unlockAsync` (re-run the discovery grep in `ipad-policy.md`).
- `ios/**/Info.plist` keys `UISupportedInterfaceOrientations*` (any variant).
- `app.json` / `app.config.*` keys `ios.orientation`, `ios.requireFullScreen`, `ios.supportsTablet`, or orientation-mask extras.
- Any component implementing an allow-listed screen or its reflow surface (per `rotationAllowList` + `ipad-policy.md`).
- Any modal/sheet component: files matching `*Modal*` or `*Sheet*`.

### Report columns (referenced from PHASE 4 and the PR Comment Template)

Add a **Device** line to the report header (e.g., `**Device:** iPad Pro 13-inch (M5)`).

Extend the verification table per screen with two extra columns:

| # | Criterion | Type | Device | Rotation policy | Rotation actual | Result | Notes |

- **Device**: `iPhone` or `iPad`. Constant per run today (single-device runs), but the column makes future iPhone+iPad batch runs trivial.
- **Rotation policy**: `allowed` or `locked` per `rotationAllowList`.
- **Rotation actual**: `locked ✓`, `rotated ✓`, `leaked ✗`, or `didn't rotate ✗`.

On iPhone runs, omit the *Rotation policy* and *Rotation actual* columns. On iPad runs, every row carries them — that's the orientation policy audit.

### One-time setup (Accessibility permission)

`rotate.sh` uses `osascript` to send Cmd+Arrow to Simulator.app. macOS blocks synthetic keystrokes unless the parent app has Accessibility permission. Grant it once at `System Settings → Privacy & Security → Accessibility` for whatever terminal or app runs Claude Code. The script self-diagnoses the missing-permission error and prints the same hint.

## Spec Mode Workflow

> The phases below use pseudocode to describe the algorithm. Implement each step using Claude Code tools (Glob, Read, Grep, Bash, etc.).

### PHASE 0: Load Spec + Prerequisites

```python
# 1. Load config (see Configuration section)
config = load_config()
bundle_id = config["bundleId"]
task_dir = config.get("taskDir", ".metis/tasks")
metro_url = config.get("metroUrl", "http://localhost:8081/status")
metro_marker = config.get("metroReadyMarker", "packager-status:running")

# 2. Find and read the task spec
task_number = $ARGUMENTS  # e.g., "130"
spec = None
for sub in ["done", "doing", "todo"]:
    files = Glob(f"{task_dir}/{sub}/{task_number}-*.md")
    if files:
        spec = Read(files[0])
        break
if not spec:
    STOP(f"Task {task_number} not found in {task_dir}/")

# 3. Parse acceptance criteria
criteria = extract_checkboxes(spec)  # Lines matching "- [ ]" or "- [x]"

# 4. Classify each criterion
for criterion in criteria:
    criterion.type = classify(criterion)
    # "ui" → screenshot verification
    # "code" → Grep/Read verification
    # "behavior" → interaction + screenshot
    # "non-verifiable" → skip (e.g., "no performance issues")

# 5. Read Screen Designs section (if present) for expected layout
screen_designs = extract_screen_designs(spec)

# 6. Evidence persistence setup — see "Evidence Persistence" (no-op without --evidence-dir)

# 7. Check prerequisites (bundler + simulator)
status = Bash(f"curl -s {metro_url}")
if metro_marker and metro_marker not in status:
    STOP(f"Bundler not ready at {metro_url}")
# Device boot: see "iPad Mode → Device boot" — handles both --device iphone
# (default) and --device ipad, boots the target simulator if the wrong type
# is booted, and bails with a clear "rebuild needed" message if the app
# isn't installed on the target.
boot_device_and_launch_app()
```

### PHASE 1: Plan Verification

Map each criterion to a concrete verification plan. Group by screen to minimize navigation.

```python
criteria_plan = [
    {
        "criterion": "...",
        "type": "ui" | "behavior" | "code" | "non-verifiable",
        "verify": "what to look for / do",
        "screen": "Screen name",
        "prerequisite": "optional app state requirement",
    },
    ...
]

print("## Verification Plan")
print(f"Task: {task_number}")
print(f"Total criteria: {len(criteria)}")
print(f"  UI-verifiable: {count_by_type('ui')}")
print(f"  Behavior: {count_by_type('behavior')}")
print(f"  Code-only: {count_by_type('code')}")
print(f"  Non-verifiable: {count_by_type('non-verifiable')}")
```

### PHASE 2: Verify Each Criterion

```python
results = {}

for screen, screen_criteria in group_by_screen(criteria_plan):
    navigate_to_screen(screen)
    Bash("sleep 1")

    mcp__ios-simulator__ui_view()
    elements = mcp__ios-simulator__ui_describe_all()

    # Output Mandatory Analysis Block (with SPEC CHECK)

    # Evidence persistence: capture screenshot + describe.json for this
    # screen — see "Evidence Persistence" (no-op without --evidence-dir).
    persist_evidence(screen, elements)

    for criterion in screen_criteria:
        if criterion.type == "ui":
            results[criterion.id] = verify_visual(criterion, elements, screenshot)
        elif criterion.type == "behavior":
            perform_interaction(criterion)
            Bash("sleep 1")
            mcp__ios-simulator__ui_view()
            results[criterion.id] = verify_visual(criterion, elements, screenshot)

    blockers = apply_complaint_filter(screenshot, elements)
    if blockers:
        for blocker in blockers:
            fix_or_escalate(blocker)

    # iPad mode only: enforce orientation policy for this screen.
    # See "iPad Mode → Orientation Verify step". Skipped on iphone runs.
    if device == "ipad":
        run_orientation_verify(screen, elements)  # rotates, asserts policy, restores portrait

for criterion in code_only_criteria:
    if "tsc" in criterion.text:
        results[criterion.id] = "SKIP (run typecheck separately)"
    else:
        results[criterion.id] = verify_code(criterion)
```

### PHASE 3: Fix / Escalate

Fix simple issues directly; escalate complex ones to `/ios-fixer`.

| Failure Type | Action |
|--------------|--------|
| Feature not implemented (no code exists) | Report as **NOT IMPLEMENTED** |
| Feature implemented but not rendered | Escalate to ios-fixer |
| Feature rendered but looks wrong (style) | Fix directly (Edit) |
| Feature rendered but data is wrong | Check store/hook logic → escalate if complex |
| User Complaint Blocker | Fix directly if simple, escalate if complex |

### PHASE 4: Report

```markdown
# QA Report: Task <number> — <title>

**Device:** <iphoneSimulator or ipadSimulator name>

## Spec Verification

| # | Criterion | Type | Result | Notes |
|---|-----------|------|--------|-------|
| 1 | ... | UI | PASS | ... |
| 2 | ... | UI | FAIL | ... |

**Result: X/Y PASS, N FAIL, M SKIP**

## User Complaint Blockers Found

1. **CRITICAL: ...** — Fixed: [yes/no] → [description]

## Issues (non-blocking)

1. ... — Fixed: [yes/no]

## Screens Scanned: N
## Fixes Applied: N
## Escalated: N
```

On iPad runs, add the *Rotation policy* / *Rotation actual* columns — see **iPad Mode → Report columns**.

## PR/Branch Mode Workflow

> Pseudocode below. Implement each step with Claude Code tools — no inline Python.

> **No command substitution.** Never use `$()` or backticks. Use separate tool calls and read outputs in subsequent commands.

### PHASE 0: Parse, Checkout & Sync

```python
config = load_config()
default_branch = config.get("defaultBranch", "main")
bundle_id = config["bundleId"]
metro_url = config.get("metroUrl", "http://localhost:8081/status")
metro_marker = config.get("metroReadyMarker", "packager-status:running")

# 1. Parse the --from-pr argument
raw_arg = $ARGUMENTS.replace("--from-pr", "").strip()  # "185", "#185", "feat/xyz"
raw_arg_clean = raw_arg.lstrip("#")
if raw_arg_clean.isdigit():
    pr_number = int(raw_arg_clean)
    is_pr = True
    pr_info = Bash(f"gh pr view {pr_number} --json title,body,headRefName,number,url")
    branch = pr_info["headRefName"]
    pr_title = pr_info["title"]
    pr_url = pr_info["url"]
else:
    branch = raw_arg
    is_pr = False
    pr_number = None

# 2. Skip-if-already-reviewed (no new commits since last QA comment)
if is_pr:
    last = Bash(f"gh api repos/:owner/:repo/issues/{pr_number}/comments --jq '[ .[] | select(.body | contains(\"ios-qa-bot\")) ] | last'")
    if last and last != "null":
        last_review_date = last["created_at"]
        pr_updated = Bash(f"gh pr view {pr_number} --json updatedAt --jq '.updatedAt'")
        if pr_updated <= last_review_date:
            print(f"PR #{pr_number} already reviewed (no new commits). Skipping.")
            STOP()
        else:
            print(f"PR #{pr_number} has new commits. Re-reviewing.")

# 3. Save current branch for restoration
original_branch = Bash("git branch --show-current").strip()

# 4. Create a -qa branch from the target
qa_branch = f"{branch}-qa"

# Delete ALL stale -qa branches from previous runs
stale_branches = Bash("git branch --list '*-qa'")
# For each line in stale_branches, run: Bash(f"git branch -D {name}")

Bash(f"git fetch origin {branch}")
Bash(f"git checkout -b {qa_branch} origin/{branch}")

# 5. Wait for the bundler to finish rebundling (poll, not blind sleep)
# Poll metro_url every second, up to 15 attempts.
# Look for metro_marker in the response (or skip the marker check if marker == "").
# After 15 failed attempts: STOP("Bundler did not become ready within 15 seconds")

# 6. Launch app and settle
# Device boot: see "iPad Mode → Device boot" — applies to PR/Branch mode too.
# On --device ipad runs, the target sim is booted before launch.
boot_device_and_launch_app()
Bash("sleep 2")
```

> **Error recovery:** If ANY phase below fails, ALWAYS skip to PHASE 3 cleanup. Never leave the repo on a `-qa` branch.

### PHASE 1: Determine Scope

```python
# 1. Get changed files
if is_pr:
    changed_files = Bash(f"gh pr diff {pr_number} --name-only")
else:
    changed_files = Bash(f"git diff {default_branch} --name-only")

# 1b. Native changes? Can't hot-reload native code — label and skip.
native_patterns = ["ios/", "android/", "app.json", "app.config.", "Podfile.lock", "package-lock.json"]
has_native = any(p in changed_files for p in native_patterns)
if has_native:
    if is_pr:
        # Don't leave a silent skip — label `rebuild-required` so the PR stays
        # trackable and has an exit (unless a human already verified via
        # `native-verified`). Idempotent on both labels.
        pr_labels = Bash(f"gh pr view {pr_number} --json labels --jq '.labels[].name'")
        if "native-verified" in pr_labels:
            print(f"PR #{pr_number} has native changes but is native-verified — skipping visual QA, no relabel.")
        elif "rebuild-required" not in pr_labels:
            # If the label doesn't exist in this repo, `gh pr edit` fails —
            # fall back to comment-only (don't treat as a run failure).
            Bash(f"gh pr edit {pr_number} --add-label rebuild-required")
            Bash(f"gh pr comment {pr_number} --body '<!-- ios-qa-bot -->\n⏭ Visual QA skipped — native changes detected. Labeled `rebuild-required`: rebuild the app against the simulator and verify manually, then add `native-verified` to release it.'")
    else:
        print("Branch has native changes. Skipping visual QA — needs rebuild.")
    GOTO_CLEANUP()

# 2. Map changed files to affected screens using fileToScreenMap from config
file_to_screen = config.get("fileToScreenMap", {})
affected_screens = []
for changed in changed_files:
    for pattern, screen in file_to_screen.items():
        if pattern in changed:  # substring match — simple and predictable
            if screen not in affected_screens:
                affected_screens.append(screen)

# 2b. iPad runs only: orientation/iPad-layout trigger. If any changed file
# matches the cues in "iPad Mode → Global-change trigger" (orientation call
# sites, Info.plist/app.json orientation keys, allow-listed screens, modals/
# sheets), force a FULL scan — a single touched modal can break layouts
# across the whole iPad pass, so the targeted-screen heuristic isn't safe.
if device == "ipad" and matches_orientation_trigger(changed_files):
    qa_mode = "general-full"

# 3. Extract task number from PR title/body or branch name
task_number = None
if is_pr:
    task_number = extract_task_number(pr_title, pr_info["body"], branch)
else:
    task_number = extract_task_number_from_branch(branch)

# 4. Decide QA mode (unless the iPad trigger already forced general-full)
if task_number:
    qa_mode = "spec"
elif affected_screens:
    qa_mode = "general-targeted"
else:
    qa_mode = "smoke"  # fallback when no mapping matched
```

### PHASE 2: Run QA

```python
if qa_mode == "spec":
    report = run_spec_mode(task_number)
elif qa_mode == "general-targeted":
    report = run_general_mode(screens=affected_screens)
elif qa_mode == "general-full":
    report = run_general_mode(mode="full")
elif qa_mode == "smoke":
    report = run_general_mode(mode="smoke")
```

### PHASE 3: Deliver Report & Cleanup

> This phase MUST run even if earlier phases failed. Branch restoration is mandatory.

```python
# --- Report ---
has_fixes = Bash(f"git log origin/{branch}..HEAD --oneline")
if has_fixes:
    Bash(f"git push origin {qa_branch}")

if is_pr:
    comment_body = format_pr_comment(report, branch, affected_screens, qa_branch, has_fixes)
    # First line MUST be the marker for dedup
    Bash(f"gh pr comment {pr_number} --body '{comment_body}'")
    print(f"QA report posted to PR #{pr_number}: {pr_url}")
else:
    print(report)

# --- Cleanup (ALWAYS runs) ---
current_branch = Bash("git branch --show-current")
if current_branch != original_branch:
    Bash(f"git checkout {original_branch}")
print(f"Restored to {original_branch}")

if not has_fixes:
    Bash(f"git branch -D {qa_branch} 2>/dev/null || true")
    print(f"Cleaned up {qa_branch} (no fixes)")
else:
    print(f"QA fixes on branch: {qa_branch}")
```

## On-Branch Mode Workflow

For use by external orchestrators (e.g., a merge-train flow) or manual invocation: QA a branch already checked out, scoped to specific screens.

### PHASE 0: Verify Prereqs (No Checkout)

```python
config = load_config()
bundle_id = config["bundleId"]
metro_url = config.get("metroUrl", "http://localhost:8081/status")
metro_marker = config.get("metroReadyMarker", "packager-status:running")

# Example: "--on-branch fixup/2026-04-24 --screens Market,Portfolio"
branch = extract_flag_value($ARGUMENTS, "--on-branch")
screens_csv = extract_flag_value($ARGUMENTS, "--screens")
screens = [s.strip() for s in screens_csv.split(",")]

current = Bash("git branch --show-current").strip()
if current != branch:
    STOP(f"On-branch mode requires {branch} to be checked out. Currently on: {current}")

status = Bash(f"curl -s {metro_url}")
if metro_marker and metro_marker not in status:
    STOP(f"Bundler not ready at {metro_url}")
# Device boot: see "iPad Mode → Device boot". On-branch mode usually inherits
# whatever sim the caller booted, but it still respects an explicit --device
# flag and reboots if the type mismatches.
boot_device_and_launch_app()
Bash("sleep 3")
```

### PHASE 1: Targeted Scan

```python
# Always include the smoke baseline before targeted screens
smoke_screens = config.get("smokeScreens", [])
all_screens = list(dict.fromkeys(smoke_screens + screens))  # dedupe, preserve order

for screen in all_screens:
    navigate_to_screen(screen)
    Bash("sleep 1")
    mcp__ios-simulator__ui_view()
    elements = mcp__ios-simulator__ui_describe_all()
    # Output Mandatory Analysis Block
    # Evidence persistence: persist_evidence(screen, elements) — see "Evidence Persistence"
    # Apply User Complaint Filter
    # Tier 1/2 blockers: fix directly, commit on current branch
    # Complex issues: escalate to ios-fixer
    # iPad mode only: run the Orientation Verify step from "iPad Mode" —
    # rotate, assert policy, restore portrait, log result.
```

### PHASE 2: Deliver Report

```python
report = format_report(results, screens_scanned=all_screens, fixes_applied=fixes)
print(report)

default_branch = config.get("defaultBranch", "main")
fixes_committed = Bash(f"git log origin/{default_branch}..HEAD --oneline").strip()
if fixes_committed:
    print(f"\n{len(fixes_committed.splitlines())} fix commit(s) on {branch}:")
    print(fixes_committed)

# Caller owns branch state. Do NOT checkout away. Do NOT push.
```

**Differences from PR/Branch mode:**

| Aspect | PR/Branch | On-branch |
|--------|-----------|-----------|
| Checkout | Creates `<branch>-qa` | None — assumes already checked out |
| Scope | Auto-detected from changed files | Caller-provided via `--screens` |
| Report | PR comment (if PR) | stdout only |
| Branch restoration | Yes | No — caller manages |
| Fix push | Optional | Never |

## PR Comment Template

```markdown
<!-- ios-qa-bot -->
## QA Report — <appName>

**Branch:** `<branch-name>`
**Device:** `<iphoneSimulator or ipadSimulator name>`
**Screens tested:** <comma-separated list>
**Mode:** <spec (task #N) | general-targeted | general-full | smoke>

### Results

<spec verification table OR screen-by-screen scan>

### Blockers

<numbered list of Tier 1/2 blockers, or "None found">

### Issues (non-blocking)

<numbered list of Tier 3 issues, or "None found">

### Summary

**Result:** X/Y PASS, N FAIL, M SKIP
**Screens scanned:** N
**Fixes applied:** N (describe each briefly)
**Escalated:** N

<if fixes were pushed: include this section>
### QA Fixes Branch

Fixes have been pushed to `<branch>-qa`. Cherry-pick or merge to apply:

    git cherry-pick <commit1> <commit2> ...
    # or
    git merge <branch>-qa
</if>

---
*Automated QA by ios-qa*
```

## Fixing Issues on the QA Branch

The `-qa` branch is your workspace. **Fix everything. Don't just report — fix.**

1. **Fix it** — read the code, understand the bug, write the fix.
2. **Verify it** — screenshot after hot-reload to confirm.
3. **Continue** — keep going until done or blocked.
4. **Commit** — each fix gets its own commit with a descriptive message.

Only escalate to `ios-fixer` if the bug is genuinely beyond a targeted style fix (e.g., native module crash, complex animation issue).

**QA is not done until the entire flow works end-to-end.** Don't stop at the first blocker — fix it, verify, keep going.

After QA completes:
- Push the `-qa` branch.
- Post a PR comment summarizing what was fixed (not just what was found).
- The PR author cherry-picks or merges.

## General Mode Workflow

When no task number is given, scan screens and apply the User Complaint Filter.

**Smoke** (`/ios-qa smoke`): launch + each tab + one detail screen.
**Default** (`/ios-qa`): smokeScreens + opinionated checks.
**Full** (`/ios-qa full`): every screen + scroll + sub-views.

Both default and full modes derive the scan list from `smokeScreens` + any extra screens implied by the configured `fileToScreenMap`. If neither is configured, fall back to: launch, then walk through whatever tabs and top-level screens are visible.

Evidence persistence and the iPad Orientation Verify step apply to every stop of a General/Smoke scan, exactly as in Spec Mode PHASE 2.

### File → Screen Mapping

The mapping lives in your project's `.claude/ios-qa.json`:

```json
{
  "fileToScreenMap": {
    "src/screens/Home.tsx": "Home",
    "src/screens/Market.tsx": "Market",
    "src/components/Card.tsx": "Home",
    "src/stores/marketStore.ts": "Market"
  }
}
```

Substring match against the changed-file path. The first matching pattern wins; if a file matches multiple, both screens are added. The skill stays consistent if the mapping is empty — it just falls back to smoke mode.

## Spec Parsing Rules

Task specs in `<taskDir>` are expected to follow a consistent markdown format.

### Acceptance Criteria

Lines matching `- [ ]` or `- [x]` under the `## Acceptance Criteria` heading. Parse the text after the checkbox; each line is one criterion.

### Screen Designs

ASCII-art blocks under `## Screen Designs` or `## Visual Design`. Use as **expected layout references** when comparing against actual screenshots.

### Technical Details

The `## Technical Details` section, if present, lists files created/modified. Use to:
- Know where to Grep if a feature looks missing.
- Know what components to expect in the UI tree.

### Requirements

The `## Requirements` section is human-readable and more detailed than acceptance criteria. Cross-reference for ambiguous criteria.

## Classifying Criteria

| Type | Example | How to Verify |
|------|---------|---------------|
| **UI** | "Settings screen accessible from profile" | Navigate + screenshot |
| **Behavior** | "Save button persists changes and dismisses sheet" | Tap + verify resulting screen |
| **Code** | "All types pass `tsc --noEmit`" | Run typecheck or Grep |
| **Data** | "Current user's row highlighted in list" | Requires specific app state — try to set up, or SKIP |
| **Non-verifiable** | "No performance issues" | Can't verify in screenshot — SKIP |

If you can't set up the required state, SKIP with a clear note rather than guessing.

## Opinionated Checks on EVERY Screen

### The 30-Second Test

For each screen, answer 5 questions in 30 seconds. If any answer is "no", it's a problem:

1. **Can I tell what this screen is for?**
2. **Can I read everything?**
3. **Do I know what to do next?**
4. **Does this look finished?**
5. **Does this match the rest of the app?**

### Comparison Checks

When scanning multiple screens, compare:
- **Card consistency** — same border radius, padding, shadow, font sizes
- **Section spacing** — uniform gaps (or deliberately varied)
- **Header style** — same font size, weight, position
- **Empty state pattern** — same style of empty-state message
- **Number formatting** — same currency, percent, date format throughout

## Safety Guards

**NEVER RESTART THE BUNDLER OR SIMULATOR**
- Scanning is read-only (navigate + screenshot + describe).
- All fixes via code edits that hot-reload.
- Never touch the bundler, Metro, or simulator process.
- Exception: `--device` runs may BOOT a not-yet-running simulator (see iPad Mode) — but never shut one down or restart one.

**Loop Control:**
- Loop if re-scan finds fewer issues than previous scan (progress).
- Stop if re-scan finds same or more issues (no progress).
- Absolute cap: 5 re-scan loops.
- Stop immediately if a fix introduces a NEW issue.

**Code Safety:**
- Direct fixes are targeted single-Edit operations.
- Every fix is verified with `ui_view` + `ui_describe_all` + analysis block.
- Complex bugs are escalated to `ios-fixer`.

**Bash Safety:**
- NEVER use `#` comments inside inline shell/Python one-liners passed to Bash — the `#` after a newline triggers permission prompts.
- If you need complex logic, write a small temp script first, then execute.
- Keep Bash commands simple and single-purpose.

**Spec Safety:**
- Never modify the task spec file (it's the test oracle).
- If a criterion is ambiguous, note it — don't interpret generously.
- If a feature isn't implemented, say so directly — don't soften it.

## Examples

See [examples.md](examples.md) for three worked examples: Spec Mode, PR Mode, and General Mode runs.

## When to Use Each Skill

| Situation | Use This |
|-----------|----------|
| Verify a completed task through the UI | `/ios-qa <task-number>` |
| General visual QA + opinionated checks | `/ios-qa` or `/ios-qa full` |
| Quick health check | `/ios-qa smoke` |
| QA a PR and post findings as PR comment | `/ios-qa --from-pr 185` |
| QA a branch (no PR comment) | `/ios-qa --from-pr feat/xyz` |
| QA a branch already checked out, scoped to screens | `/ios-qa --on-branch feat/x --screens "Home,Market"` |
| Audit iPad layout + rotation policy | `/ios-qa --device ipad` |
| Iterate every open PR | `/qa-batch` |
| Enter/exit a manual QA session | `/qa <PR# \| branch>` |
| Deep-dive a specific bug | `/ios-fixer "description"` |
