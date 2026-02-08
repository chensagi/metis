---
name: ios-simulator
version: 0.1.0
description: iOS Simulator interaction — screenshots, simctl commands, app installation
requires: [react-native]
provides:
  - simulator-screenshots
  - simctl-commands
  - visual-verification
commands:
  screenshot: "xcrun simctl io booted screenshot /private/tmp/sim-{name}.png"
  list_devices: "xcrun simctl list devices | grep Booted"
  list_booted: "xcrun simctl list devices booted"
  install_app: "xcrun simctl install booted {app_path}"
  open_url: "xcrun simctl openurl booted {url}"
  status_bar: "xcrun simctl status_bar booted override --time '9:41'"
---

# iOS Simulator Capability

## Agent Instructions

This project targets the iOS Simulator. You can interact with it for visual verification.

### Screenshot Workflow

Use screenshots for before/after verification of UI changes:

```bash
# Take a screenshot
xcrun simctl io booted screenshot /private/tmp/sim-before.png

# ... make changes, wait for hot reload ...

# Take after screenshot
xcrun simctl io booted screenshot /private/tmp/sim-after.png
```

Read the screenshot files to visually verify changes. The simulator must be booted — check with:
```bash
xcrun simctl list devices | grep Booted
```

### Verification Pattern

For UI changes, follow this pattern:
1. Take BEFORE screenshot → verify current state
2. Apply changes (code edit, hot reload)
3. Take AFTER screenshot → verify changes applied correctly
4. Compare: does the after screenshot show the expected changes?

### Common simctl Commands

```bash
# Boot a specific device
xcrun simctl boot "iPhone 16 Pro"

# Install an app
xcrun simctl install booted path/to/app.app

# Open a deep link
xcrun simctl openurl booted "myapp://path"

# Override status bar (for clean screenshots)
xcrun simctl status_bar booted override --time "9:41" --batteryLevel 100

# Reset a device (clear all data)
xcrun simctl erase booted
```

### Requirements

- Xcode must be installed with iOS Simulator
- At least one simulator must be booted before taking screenshots
- For development builds, the app must be installed and running
- Metro/dev server must be active for hot reload to work

### Troubleshooting

- "No booted devices" → Boot a simulator: `xcrun simctl boot "iPhone 16 Pro"`
- Screenshot is black → App may not be in foreground, try `xcrun simctl launch booted {bundle_id}`
- Old screenshot → Wait for hot reload to complete before capturing
