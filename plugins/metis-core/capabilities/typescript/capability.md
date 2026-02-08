---
name: typescript
version: 0.1.0
description: TypeScript compilation, type checking, and project conventions
requires: []
provides:
  - type-checking
  - compilation-verification
commands:
  verify: "npx tsc --noEmit"
  verify_quick: "npx tsc --noEmit 2>&1 | head -30"
---

# TypeScript Capability

## Agent Instructions

This project uses TypeScript. Follow these conventions:

### Compilation Gate

Every task MUST end with `npx tsc --noEmit` returning ZERO errors. This is a hard gate — do not finish with errors.

When you encounter TypeScript errors:
1. Run `npx tsc --noEmit 2>&1 | head -30` to see the first batch
2. Fix errors in dependency order (types first, then implementations)
3. Re-run until clean

### Type Conventions

- Use explicit types for function parameters and return values
- Prefer `interface` for object shapes, `type` for unions/intersections
- Export shared types from dedicated type files (e.g., `types/`, `types.ts`)
- Use `unknown` instead of `any` — narrow with type guards
- Use `readonly` for immutable data structures

### Import Conventions

- Use named imports: `import { Thing } from './module'`
- Group imports: external packages first, then internal modules, then relative paths
- Use path aliases if configured in `tsconfig.json` (check `paths` field)

### Common Patterns

- Use `satisfies` for type-safe object literals: `const config = { ... } satisfies Config`
- Use discriminated unions for variant types
- Use `as const` for literal type inference
- Avoid type assertions (`as`) — prefer type guards
