# CLAUDE.md — SwiftClaw

macOS-first, Swift-native AI agent framework with MLX inference. Privacy-first, self-hosted, on-device primary.

## Quick Reference

```bash
swift build                        # Build all targets
swift build -c release             # Required for MLX (debug build can't load metallib)
swift run swiftclaw doctor         # Check system, MLX, model (pre-model checks only)
swift run swiftclaw tools          # List available tools
.build/release/swiftclaw run       # Run agent with MLX (requires mlx.metallib colocated — see Gotchas)
.build/release/swiftclaw run --backend http --api-url http://localhost:11434/v1  # HTTP/Ollama backend
.build/release/swiftclaw run --session my-session  # Create or resume a named session
.build/release/swiftclaw sessions list             # List saved sessions
.build/release/swiftclaw sessions show <id>        # Print conversation history
.build/release/swiftclaw sessions delete <id>      # Delete a session
.build/release/swiftclaw sessions export <id>      # Export session as LoRA training JSONL
swift test                         # Run all tests (145 tests)
```

## MLX Setup (one-time)

```bash
swift build -c release
# Find mlx version from Package.resolved, then:
pip install --target /tmp/mlx-metallib mlx==<version>
cp /tmp/mlx-metallib/mlx/core/mlx.metallib .build/release/
# Now run: .build/release/swiftclaw run
```

## Architecture

- **SwiftClawCore**: Agent runtime, session orchestration, tool protocol, model backend protocol, session store protocol, agent memory
- **SwiftClawMLX**: Concrete MLX backend using mlx-swift-lm (native, no Python)
- **SwiftClawHTTP**: OpenAI-compatible HTTP backend (Foundation-only, targets Ollama/OpenAI)
- **SwiftClawTools**: Built-in tools (system info, disk, processes, shell, file ops, env/datetime/clipboard); `SwiftClawToolFactory.allTools(config:)` for registration
- **SwiftClawPippin**: Pippin CLI wrappers (mail + memos); `PippinToolFactory.allTools()` returns empty if binary absent
- **swiftclaw**: CLI executable (ArgumentParser)

## Key Design Decisions

- Swift 6 strict concurrency (no `.swiftLanguageMode(.v5)`)
- Session is an actor (mutable conversation state), Agent is a struct (immutable config)
- Tool arguments are JSON strings (not `Any`) for Sendable safety
- ModelBackend protocol: MLX (on-device) and HTTP (OpenAI-compatible) backends
- Sessions persist to `~/.swiftclaw/sessions/<id>.json`; agent memory at `~/.swiftclaw/memory/<namespace>.json`; config at `~/.swiftclaw/config.json` (`SwiftClawConfig` — controls `FileSandbox` allowedPaths)
- Default model: `mlx-community/Qwen3.5-9B-MLX-4bit` (MLX); `qwen2.5:7b` (HTTP default)
- HTTP backend targets Ollama at `http://localhost:11434/v1` by default

## Conventions

- Protocol-based tools (no macros in MVP)
- `LocalizedError` enums for errors
- SPM library+executable split
- All types must be `Sendable`
- Issue tracking via `bd` — see `AGENTS.md` and `.beads/`

## Gotchas & Fixes

- **macOS `ps` has no `--sort`** — use `/bin/ps -a -x -m -o pid,user,%cpu,%mem,command` (GNU flags don't work)
- **Pipe deadlock with `Process`** — drain both pipes via `DispatchGroup` BEFORE `waitUntilExit()`; pipe buffer ~64KB
- **GCD pipe vars under Swift 6** — mark with `nonisolated(unsafe)` when mutated inside `DispatchQueue.global().async`
- **`Chat.Message` not Sendable** — use `@preconcurrency import MLXLMCommon` to downgrade error to warning
- **`ToolSpec` is in `Tokenizers`** — add `import Tokenizers` (from swift-transformers, a transitive dep of mlx-swift-lm)
- **`GenerateStopReason` has no `.toolCall`** — detect tool calls via `!collectedToolCalls.isEmpty`, not stop reason
- **ShellSandbox redirect pattern** — use `">"` not `">{"`; plain `>` catches all redirect forms
- **Use `ModelContainer` directly** — don't use `ChatSession`; SwiftClaw's `Session` actor owns the agentic loop
- **MLX requires release binary + colocated metallib** — `swift run` / debug builds fail with "Failed to load the default metallib". Must: (1) `swift build -c release`, (2) `cp <mlx.metallib> .build/release/`. Get metallib via `pip install --target /tmp/mlx-metallib mlx==<version>` where version matches `mlx-swift` in Package.resolved.
- **Model cache is `~/Library/Caches/models/<org>/<model>`** — e.g. `~/Library/Caches/models/mlx-community/Qwen3.5-9B-MLX-4bit`. Doctor checks this path directly (NOT HuggingFace's `models--` format).
- **Qwen3.5 tool calls parsed by `Qwen35ToolCallParser`** — `Sources/SwiftClawMLX/Qwen35ToolCallParser.swift` is a fallback that scans accumulated text for `<tool_call>` blocks when mlx-swift-lm doesn't emit native `.toolCall` events. `swift package update` is now safe — no checkout patches needed.
- **Tool Arguments: accept string-encoded integers** — the Qwen3.5 XML parser passes all parameter values as strings. Tool `Arguments` structs with `Int?` fields need a custom `Decodable` that accepts both `Int` and numeric `String`. See `ProcessListTool` and `ShellTool` for the pattern.
- **Qwen3.5 `<think>` blocks** — model streams reasoning content *without* an opening `<think>` tag; only `</think>` is emitted. Regex `<think>.*</think>` never matches. Filter: `if let r = text.range(of: "</think>") { text = String(text[r.upperBound...]) }` (in `ModelBackend` non-streaming extension).
- **`ToolCallFormat.json` is correct for Qwen3.5** — uses `<tool_call>{...}</tool_call>`. `.xmlFunction` is for Qwen3 **Coder** only. `ToolCallFormat.infer("qwen3_5")` returns nil, which correctly defaults to `.json`.
- **Qwen3.5 tool calls — text-injection (verified 2026-03-05)** — passing `UserInput.tools` or any `<tool_call>` token in the system message triggers EOS-after-think (model stops generating after `</think>`). `enable_thinking: false` also fails — generates 0 tokens. Working fix: `toolSpecs = nil`, inject tool descriptions as plain text with `<function=NAME>` format (no `<tool_call>` token); `Qwen35ToolCallParser` handles bare `<function=...>` blocks; `ModelBackend` strips them from response text.
- **Prefer `loadModelContainer(configuration:)`** over `loadModelContainer(id:)` — takes a `ModelConfiguration` so fields like `toolCallFormat` can be set before loading.
- **`list_directory` doesn't expand `~`** — `FileManager` won't expand tilde in paths; model must pass absolute paths or use the `shell` tool with `ls ~/...` instead.
- **E2E testing via piped stdin** — `echo "prompt"` closes stdin before the REPL reads it. Use `printf "prompt\n/quit\n" | .build/release/swiftclaw run` to include an explicit quit after the message.
