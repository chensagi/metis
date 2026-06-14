#!/usr/bin/env bash
# Rotate the booted iOS Simulator via the macOS Simulator.app menu shortcut.
#
# Usage:
#   rotate.sh left   # Cmd+Left  (rotate 90° counter-clockwise)
#   rotate.sh right  # Cmd+Right (rotate 90° clockwise)
#
# Why this exists: `xcrun simctl` has no rotate command. The Simulator only
# rotates via its own UI / keyboard shortcuts, so we drive it with AppleScript.
# Cmd+Arrow maps to "Rotate Left" / "Rotate Right" in Simulator → Device.
# The rotation only takes effect if the booted device's Info.plist permits the
# target orientation (e.g., portrait-locked phones won't rotate — which is
# exactly the property the ios-qa skill asserts).
#
# One-time setup: macOS blocks synthetic keystrokes without Accessibility
# permission (osascript error 1002). Grant it once in:
#   System Settings → Privacy & Security → Accessibility → enable the
#   terminal or app that runs Claude Code (Terminal, iTerm, Claude Code).
# This script detects the missing-permission error and points there.
set -euo pipefail

dir="${1:-right}"
case "$dir" in
  left)  key=123 ;;  # 123 = Left Arrow
  right) key=124 ;;  # 124 = Right Arrow
  *) echo "Usage: $0 left|right" >&2; exit 2 ;;
esac

err=$(
  osascript \
    -e 'tell application "Simulator" to activate' \
    -e "tell application \"System Events\" to key code $key using command down" \
    2>&1
) || rc=$?
rc=${rc:-0}

if [ $rc -ne 0 ]; then
  if echo "$err" | grep -q "1002"; then
    cat >&2 <<'MSG'
rotate.sh: macOS blocked synthetic keystrokes (Accessibility permission missing).

Grant it once:
  System Settings → Privacy & Security → Accessibility
  Enable the parent terminal/app of this shell (Terminal, iTerm, Claude Code, etc.)
  Then re-run.
MSG
  else
    echo "$err" >&2
  fi
  exit $rc
fi
