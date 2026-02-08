---
name: react-native
version: 0.1.0
description: React Native component patterns, native primitives, and StyleSheet conventions
requires: [typescript]
provides:
  - native-ui-components
  - stylesheet-patterns
  - react-hooks
commands:
  start_metro: "npx react-native start"
  run_ios: "npx react-native run-ios"
  run_android: "npx react-native run-android"
---

# React Native Capability

## Agent Instructions

This is a React Native project. Follow these conventions:

### Native Primitives

Use React Native primitives — NOT web HTML elements:
- `View` (not `div`)
- `Text` (not `span`/`p`)
- `TouchableOpacity` or `Pressable` (not `button`)
- `ScrollView` or `FlatList` (not scrollable `div`)
- `TextInput` (not `input`)
- `Image` (not `img`)
- `Modal` for overlay content (separate native view layer)

### StyleSheet Conventions

Always use `StyleSheet.create()` for styles — it provides performance optimization through object pooling:

```typescript
const styles = StyleSheet.create({
  container: { flex: 1, paddingHorizontal: 16 },
  text: { fontSize: 16, color: '#fff' },
});
```

- Use `flex` layout (React Native uses Flexbox by default, column direction)
- No CSS units — all numbers are density-independent pixels
- No `className` — use `style` prop directly
- For dynamic styles, combine static + dynamic: `style={[styles.base, { opacity }]}`

### Component Patterns

- Use functional components with hooks (no class components)
- Extract complex logic into custom hooks (`useXxx` naming)
- Use `SafeAreaView` from `react-native-safe-area-context` for notch handling
- Use `useCallback` for event handlers passed to child components
- Use `useMemo` for expensive computations
- Use `useRef` for mutable values that don't trigger re-renders

### Platform Specifics

- Check platform: `import { Platform } from 'react-native'` → `Platform.OS === 'ios'`
- Platform-specific files: `Component.ios.tsx` / `Component.android.tsx`
- Shadow (iOS) vs elevation (Android) for drop shadows

### Performance

- Use `FlatList` for long lists (not `ScrollView` with `.map()`)
- Set `keyExtractor` on all list components
- Avoid inline object/function creation in render (causes re-renders)
- Use `React.memo` for pure components that receive stable props
