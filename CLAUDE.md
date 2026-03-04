# CLAUDE.md — SwiftClaw

macOS-first, Swift-native AI agent framework with MLX inference. Privacy-first, self-hosted, on-device primary.

## Quick Reference

```bash
swift build                        # Build all targets
swift run swiftclaw doctor         # Check system, MLX, model
swift run swiftclaw tools          # List available tools
swift run swiftclaw run            # Interactive Sysop Agent
swift test                         # Run all tests
```

## Architecture

- **SwiftClawCore**: Agent runtime, session orchestration, tool protocol, model backend protocol
- **SwiftClawMLX**: Concrete MLX backend using mlx-swift-lm (native, no Python)
- **SwiftClawTools**: Built-in tools (system info, disk, processes, sandboxed shell)
- **swiftclaw**: CLI executable (ArgumentParser)

## Key Design Decisions

- Swift 6 strict concurrency (no `.swiftLanguageMode(.v5)`)
- Session is an actor (mutable conversation state), Agent is a struct (immutable config)
- Tool arguments are JSON strings (not `Any`) for Sendable safety
- ModelBackend protocol enables future HTTP/pi-mono backends
- Default model: `mlx-community/Qwen3.5-9B-MLX-4bit`

## Conventions

- Protocol-based tools (no macros in MVP)
- `LocalizedError` enums for errors
- SPM library+executable split
- All types must be `Sendable`
