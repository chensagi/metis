---
name: zustand
version: 0.1.0
description: Zustand state management with optional MMKV persistence
requires: [react-native]
provides:
  - state-management
  - store-patterns
  - persistence
commands: {}
---

# Zustand Capability

## Agent Instructions

This project uses Zustand for state management. Follow these conventions:

### Store Pattern

```typescript
import { create } from 'zustand';

interface MyState {
  // State
  items: Item[];
  isLoading: boolean;

  // Actions
  addItem: (item: Item) => void;
  removeItem: (id: string) => void;
  reset: () => void;
}

export const useMyStore = create<MyState>()((set, get) => ({
  // Initial state
  items: [],
  isLoading: false,

  // Actions (immutable updates)
  addItem: (item) => set((state) => ({
    items: [...state.items, item],
  })),

  removeItem: (id) => set((state) => ({
    items: state.items.filter(i => i.id !== id),
  })),

  reset: () => set({ items: [], isLoading: false }),
}));
```

### Key Conventions

- **Naming**: `use{Name}Store` for the hook, `{Name}State` for the interface
- **File location**: Check project structure — commonly `src/stores/` or `src/state/`
- **Immutable updates**: Always spread or filter — never mutate state directly
- **Actions inside store**: Define actions as part of the store, not as external functions
- **Selectors**: Use selectors for performance: `const items = useMyStore(s => s.items)`

### Persistence (MMKV)

If the project uses MMKV for persistence, stores may use the `persist` middleware:

```typescript
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { zustandMMKVStorage } from './mmkvStorage';

export const useMyStore = create<MyState>()(
  persist(
    (set, get) => ({
      // ... same as above
    }),
    {
      name: 'my-store',
      storage: zustandMMKVStorage,
    }
  )
);
```

- Check for `mmkvStorage.ts` or similar adapter files
- MMKV is 30x faster than AsyncStorage
- Never access MMKV directly in components — always go through store hooks

### Snapshot Pattern

Some stores support save/restore via snapshots:

```typescript
// In store:
getSnapshot: () => {
  const state = get();
  return { field1: state.field1, field2: state.field2 };
},
loadFromSnapshot: (snapshot) => {
  set({ ...snapshot });
},
```

### What NOT to Do

- Don't create new stores for trivial state — use local `useState` instead
- Don't put UI state (modal open/close) in global stores unless it needs to be shared
- Don't subscribe to entire store: `useMyStore()` re-renders on ANY change
- Always use selectors: `useMyStore(s => s.specificField)`
