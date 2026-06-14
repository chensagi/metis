# iPad Orientation Policy

Companion to [SKILL.md](SKILL.md) — used by ios-qa when running with `--device ipad`.

## The policy in one sentence

**On iPad, every screen stays portrait except the screens your project explicitly allow-lists — rotation anywhere else is a Tier 1 blocker.**

The allow-list lives in your project's `.claude/ios-qa.json`:

```json
{
  "rotationAllowList": [
    { "screen": "Detail modal", "reflowSurface": "chart WebView" }
  ]
}
```

- `screen` — the screen name as used in `smokeScreens` / `fileToScreenMap`.
- `reflowSurface` (optional) — the element that must visibly resize after rotation. If set, the Orientation Verify step asserts its width reflows to the landscape width; an unchanged width is a Tier 1 blocker.

An empty or missing `rotationAllowList` means **everything is locked portrait** — the safest default and correct for most phone-first apps.

## Why iPad rotation needs policing at all

A typical Expo/React Native phone-first app is portrait-locked on iPhone by `UISupportedInterfaceOrientations`, but iPad is different:

- If `app.json` declares `ios.supportsTablet: true`, the generated `UISupportedInterfaceOrientations~ipad` usually permits **all four** orientations (so the system *can* deliver landscape if the app asks for it).
- That makes iPad rotation a *runtime* decision. The only thing keeping screens portrait is a runtime lock (e.g., `expo-screen-orientation`'s `lockAsync(PORTRAIT_UP)`), often re-applied when a landscape-capable screen closes.
- If that lock is missed, dropped, or never set on a cold-start screen, the screen rotates freely and any layout that assumes portrait breaks.

Check your project's actual posture as part of discovery — don't assume: read `app.json` (`ios.supportsTablet`, `orientation`) and `ios/**/Info.plist` (`UISupportedInterfaceOrientations*`).

## Discovery procedure (run at the start of every iPad QA run)

Re-derive the allow-list from the codebase instead of trusting the config blindly:

```bash
grep -rn -E "OrientationLock|unlockAsync|lockAsync|ScreenOrientation" src/ app/ \
  | grep -v -E "node_modules|\.test\."
```

Cross-check the results against `rotationAllowList`:

- **Every `unlockAsync()` (or landscape-permitting `lockAsync`) call site should correspond to one allow-list entry.** Trace each call site to the screen/modal that mounts it.
- **Grep finds an unlock site with no allow-list entry** → STOP and ask the user: either it's a deliberate product decision missing from the config (add it), or it's a rotation leak waiting to happen (file it as a finding). A new allow-list entry is a *deliberate* decision, not something for the QA skill to silently accept.
- **Allow-list names a screen with no unlock site in code** → the entry is stale; report it and treat the screen as locked.
- **Grep returns nothing and the allow-list is empty** → the whole app is locked portrait; every screen gets the locked-portrait verification only.

## What a rotation-allowed verification looks like

For each allow-list entry:

1. Navigate to the screen / open the modal in portrait.
2. Take portrait `ui_view` + `ui_describe_all`. Confirm `height > width`.
3. `bash <skill-dir>/rotate.sh right`, then `sleep 1`.
4. Take landscape `ui_view` + `ui_describe_all`. Confirm `width > height` — an allow-listed screen that does NOT rotate is a blocker too (`didn't rotate ✗`).
5. If the entry has a `reflowSurface`: confirm it reflowed — its bounds in `ui_describe_all` should report a width close to the new screen width, not the old portrait width. **An unchanged width after rotation is a Tier 1 blocker.** Modal chrome (close button, header) must remain visible.
6. `rotate.sh left` to return to portrait. Confirm.
7. Close/leave the screen → confirm the device returned to portrait and **stays portrait on the next screen** (the re-lock on exit is part of the contract).

## What a locked-portrait verification looks like (everything else)

1. Navigate to the screen. Take portrait `ui_view` + `ui_describe_all`.
2. `rotate.sh right`, `sleep 1`.
3. Take a second `ui_view` + `ui_describe_all`. The reported dimensions should be unchanged (`height > width` still).
4. If the screen actually rotated (`width > height` now), that's Tier 1: **"rotation leaked from locked-portrait screen."** File it as a blocker per Loop Control.
5. `rotate.sh left` to restore the simulator's requested orientation (the device didn't rotate, but Simulator.app remembers the requested rotation in its own state).

## Worked example (from the app this skill was extracted from)

A stock-trading app had exactly one rotation-allowed surface: a stock-detail modal containing a chart WebView. One hook (`useLandscapeChart`) owned all `ScreenOrientation.*` calls — `unlockAsync()` on modal mount, `lockAsync(PORTRAIT_UP)` on close. Its config:

```json
{
  "rotationAllowList": [
    { "screen": "Stock Detail modal", "reflowSurface": "chart WebView" }
  ]
}
```

The discovery grep returned two files: the hook and its single consumer. The two recurring bug classes the verification catches: (1) the chart WebView keeping its portrait width inside a rotated modal, and (2) the portrait re-lock being dropped on close so the *next* screen rotated freely.

## One-time setup

`rotate.sh` (ships next to SKILL.md) uses `osascript` to send Cmd+Arrow into Simulator.app. On modern macOS this requires **Accessibility permission** for whichever app runs Claude Code (Terminal, iTerm, or Claude Code itself). Grant it once at:

`System Settings → Privacy & Security → Accessibility`

The script self-diagnoses the missing-permission case (error 1002) and prints the same instructions.
