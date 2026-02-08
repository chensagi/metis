---
name: go
version: 0.1.0
description: Go project conventions, modules, and tooling
requires: []
provides:
  - go-runtime
  - go-modules
  - go-toolchain
commands:
  verify: "go build ./..."
  test: "go test ./..."
  lint: "golangci-lint run"
  format: "gofmt -w ."
  vet: "go vet ./..."
---

# Go Capability

## Agent Instructions

This is a Go project. Follow these conventions:

### Project Structure

- `cmd/` — Application entry points
- `internal/` — Private packages (not importable by external code)
- `pkg/` — Public library packages
- `go.mod` — Module definition and dependencies
- `go.sum` — Dependency checksums (always commit this)

### Compilation Gate

Every task MUST end with `go build ./...` returning ZERO errors. This is a hard gate.

### Code Conventions

- Use `gofmt` formatting (non-negotiable in Go)
- Error handling: always check and handle errors — never ignore with `_`
- Use `context.Context` for cancellation and timeouts
- Prefer interfaces at the consumer, not the provider
- Use `errors.Is()` and `errors.As()` for error checking
- Receiver naming: short, consistent (e.g., `s` for `*Server`)

### Testing

- Test files: `*_test.go` in the same package
- Table-driven tests are the standard pattern
- Run: `go test ./...` (all packages) or `go test ./pkg/specific/`
- Use `testify` if it's a dependency, otherwise standard `testing` package

### Dependencies

- `go get package@version` to add dependencies
- `go mod tidy` to clean up unused dependencies
- Always commit both `go.mod` and `go.sum`

### Common Patterns

- Functional options for configurable constructors
- Interface-based dependency injection
- `struct` embedding for composition
- Channel-based concurrency patterns
