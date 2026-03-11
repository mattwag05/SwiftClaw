# Contributing to SwiftClaw

Thanks for your interest in contributing.

## Requirements

- macOS 15+, Apple Silicon
- Swift 6.2+
- Xcode 16+ (or Swift toolchain from swift.org)

## Setup

```bash
git clone https://github.com/mattwag05/SwiftClaw.git
cd SwiftClaw
swift build
swift test
```

For MLX inference (optional — requires Apple Silicon):

```bash
swift build -c release
# Find mlx version in Package.resolved, then:
pip install --target /tmp/mlx-metallib mlx==<version>
cp /tmp/mlx-metallib/mlx/core/mlx.metallib .build/release/
.build/release/swiftclaw doctor
```

## Project Layout

| Package | Purpose |
|---------|---------|
| `SwiftClawCore` | Agent runtime, session protocol, tool protocol, backend protocol |
| `SwiftClawMLX` | On-device MLX backend, LoRA training, adapter management |
| `SwiftClawHTTP` | OpenAI-compatible HTTP backend (Ollama, OpenAI) |
| `SwiftClawTools` | Built-in system tools (shell, files, clipboard, etc.) |
| `SwiftClawPippin` | Optional Pippin CLI integration (mail, memos) |
| `SwiftClawUI` | SwiftUI components |
| `swiftclaw` | CLI executable |
| `SwiftClawApp` | macOS SwiftUI app |

## Code Style

- Swift 6 strict concurrency — no `swiftLanguageMode(.v5)` escape hatches
- `Session` is an actor; `Agent` is a struct
- All public types must conform to `Sendable`
- `LocalizedError` enums for all error types
- Protocol-based tools (no macros)
- No force unwraps

## Testing

```bash
swift test                  # All 175 tests
swift test --filter CoreTests  # Specific target
```

Core tests use `MockBackend` — no model download required. Keep new tests isolated using temp directories for any store/file operations.

## Submitting Changes

1. Fork the repo and create a feature branch
2. Make your changes with tests
3. Run `swift test` — all tests must pass
4. Open a pull request with a clear description of the change and why

## Reporting Issues

Please open a GitHub issue with:
- macOS version and chip (M1/M2/M3/M4)
- Swift version (`swift --version`)
- Steps to reproduce
- Expected vs actual behavior
