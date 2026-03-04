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

## Gotchas & Fixes

- **macOS `ps` has no `--sort`** — use `/bin/ps -a -x -m -o pid,user,%cpu,%mem,command` (GNU flags don't work)
- **Pipe deadlock with `Process`** — drain both pipes via `DispatchGroup` BEFORE `waitUntilExit()`; pipe buffer ~64KB
- **GCD pipe vars under Swift 6** — mark with `nonisolated(unsafe)` when mutated inside `DispatchQueue.global().async`
- **`Chat.Message` not Sendable** — use `@preconcurrency import MLXLMCommon` to downgrade error to warning
- **`ToolSpec` is in `Tokenizers`** — add `import Tokenizers` (from swift-transformers, a transitive dep of mlx-swift-lm)
- **`GenerateStopReason` has no `.toolCall`** — detect tool calls via `!collectedToolCalls.isEmpty`, not stop reason
- **ShellSandbox redirect pattern** — use `">"` not `">{"`; plain `>` catches all redirect forms
- **Use `ModelContainer` directly** — don't use `ChatSession`; SwiftClaw's `Session` actor owns the agentic loop
