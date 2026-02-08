---
name: rust
version: 0.1.0
description: Rust project conventions, Cargo, and tooling
requires: []
provides:
  - rust-toolchain
  - cargo
  - borrow-checker
commands:
  verify: "cargo check"
  build: "cargo build"
  test: "cargo test"
  lint: "cargo clippy"
  format: "cargo fmt"
---

# Rust Capability

## Agent Instructions

This is a Rust project. Follow these conventions:

### Compilation Gate

Every task MUST end with `cargo check` returning ZERO errors and ZERO warnings from `cargo clippy`. This is a hard gate.

### Project Structure

- `src/main.rs` — Binary entry point
- `src/lib.rs` — Library root
- `src/bin/` — Additional binaries
- `tests/` — Integration tests
- `Cargo.toml` — Package manifest and dependencies
- `Cargo.lock` — Dependency lockfile (commit for binaries, optional for libraries)

### Code Conventions

- Use `rustfmt` formatting (`cargo fmt`)
- Handle errors with `Result<T, E>` — use `?` operator for propagation
- Prefer `thiserror` for library errors, `anyhow` for application errors
- Use `clippy` lints — treat warnings as errors
- Lifetime annotations: only add when the compiler requires them
- Use `derive` macros: `Debug`, `Clone`, `PartialEq` as appropriate

### Ownership and Borrowing

- Prefer borrowing (`&T`) over cloning when possible
- Use `Arc<T>` for shared ownership across threads
- Use `Mutex<T>` or `RwLock<T>` for shared mutable state
- Avoid `unsafe` unless absolutely necessary — document why

### Testing

- Unit tests: `#[cfg(test)] mod tests { ... }` in the same file
- Integration tests: `tests/` directory
- Run: `cargo test` (all) or `cargo test test_name`
- Use `#[should_panic]` for expected panics

### Dependencies

- `cargo add package` to add dependencies
- Check `crates.io` for package availability
- Pin major versions in `Cargo.toml`
