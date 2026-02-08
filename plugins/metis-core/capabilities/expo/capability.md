---
name: expo
version: 0.1.0
description: Expo CLI, Metro bundler, OTA updates, and development builds
requires: [react-native]
provides:
  - expo-cli
  - metro-bundler
  - ota-updates
  - expo-router
commands:
  start: "npx expo start"
  run_ios: "npx expo run:ios"
  run_android: "npx expo run:android"
  prebuild: "npx expo prebuild"
  prebuild_clean: "npx expo prebuild --clean"
  doctor: "npx expo-doctor"
  fix_versions: "npx expo install --fix"
---

# Expo Capability

## Agent Instructions

This project uses Expo. Follow these conventions:

### Development Workflow

- `npx expo start` — Start Metro bundler (hot reload works for JS changes)
- `npx expo run:ios` — Build and run on iOS simulator
- `npx expo run:android` — Build and run on Android emulator
- Metro hot reload handles most JS/React code changes automatically

### Native Rebuild Triggers

A native rebuild (`npx expo run:ios` or `npx expo prebuild --clean`) is required after:
- `git checkout <branch>` (different native binary may be needed)
- `npm install` (new/updated native modules)
- `git pull` when `Podfile.lock` changed
- Direct `ios/` or `android/` folder changes
- `app.json` native settings changes (plugins, permissions, bundle ID)

**JS-only changes do NOT need a rebuild** — Metro hot reload handles them.

### OTA vs Native Changes

| Change Type | Rebuild? | OTA Works? |
|-------------|----------|------------|
| JS/React code | No | Yes |
| app.json config | Yes | No |
| New native dependency | Yes | No |
| ios/ folder changes | Yes | No |

### Native Mismatch Symptoms

If you see these errors, a native rebuild is needed:
- `RCTDeviceInfo` crashes
- "Native module X is not installed"
- Cryptic "method not found" errors

### Expo Router (if used)

If the project uses Expo Router (check `app/` directory):
- Directory structure = routes (no route config file)
- `_layout.tsx` = layout wrapper for each directory
- `(parentheses)` = route group (doesn't appear in URL)
- `index.tsx` = default route for directory
- Use `useRouter()` for navigation, `usePathname()` for current path
- Every route file must `export default` a React component

### Troubleshooting

- `npx expo-doctor` — Check for version mismatches and common issues
- `npx expo install --fix` — Auto-fix dependency version mismatches
- Clear cache: `watchman watch-del-all && rm -rf .expo`
