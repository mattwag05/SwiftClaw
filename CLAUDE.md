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
.build/release/swiftclaw train --name <n> --sessions <id1,id2> --iterations 100  # Train LoRA adapter
.build/release/swiftclaw adapters list             # List trained adapters
.build/release/swiftclaw adapters delete <name>    # Delete an adapter
.build/release/swiftclaw run --adapter ~/.swiftclaw/adapters/<name>  # Run with LoRA adapter (MLX only)
.build/release/swiftclaw run --auto-adapter        # Auto-select best adapter by loss+recency
.build/release/swiftclaw adapters tag <name> --add "coding,swift" --remove "old"
.build/release/swiftclaw eval "prompt" --adapter-b <name>  # A/B eval (base vs adapter); prompts for winner [A/B/tie/skip]
.build/release/swiftclaw eval "prompt" --adapter-a <n1> --adapter-b <n2>  # Adapter vs adapter A/B
# Eval results saved to ~/.swiftclaw/evals/<epoch>.json
swift test                         # Run all tests (159 tests)
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
  - `LoRATrainer`: trains adapters from JSONL session exports via MLXOptimizers; stored in `~/.swiftclaw/adapters/`
  - `AdapterStore`: adapter metadata and lifecycle management
  - `AdapterSelector`: scores/selects adapters (tag overlap 60%, val loss 25%, recency 15%)
  - `EvalStore`: persists A/B eval results to `~/.swiftclaw/evals/`
- **SwiftClawHTTP**: OpenAI-compatible HTTP backend (Foundation-only, targets Ollama/OpenAI)
- **SwiftClawTools**: Built-in tools (system info, disk, processes, shell, file ops, env/datetime/clipboard); `SwiftClawToolFactory.allTools(config:)` for registration
- **SwiftClawPippin**: Pippin CLI wrappers (mail + memos); `PippinToolFactory.allTools()` returns empty if binary absent
- **swiftclaw**: CLI executable (ArgumentParser)
- **SwiftClawApp**: SwiftUI target — macOS app wrapper around SwiftClawCore; uses `@Observable` agent state; shares the same session store as the CLI

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

### Swift 6 Concurrency

- **GCD pipe vars under Swift 6** — mark with `nonisolated(unsafe)` when mutated inside `DispatchQueue.global().async`
- **`Chat.Message` not Sendable** — use `@preconcurrency import MLXLMCommon` to downgrade error to warning
- **`ISO8601DateFormatter` is not `Sendable`** — can't use as `static let` in a `Sendable` struct under Swift 6; use Unix timestamp strings or `nonisolated(unsafe)` if the instance is read-only after init.
- **Actor mutation from `Task { [weak self] }`** — can't mutate actor properties directly in a nonisolated closure. Use a private actor-isolated helper: `private func setX(_ v: T) { x = v }` called with `await self.setX(v)`.
- **`AsyncThrowingStream` cancellation** — capture the backing `Task` and wire `continuation.onTermination = { _ in task.cancel() }` so dropping the stream cancels the underlying work.
- **Cancel-then-await race** — `Task.cancel()` sets a flag but doesn't interrupt a suspended `for try await` loop immediately. Set UI state (e.g. `isGenerating = false`) eagerly at the cancel call site; don't rely on the async path to clear it.

### MLX & Model Loading

- **MLX requires release binary + colocated metallib** — `swift run` / debug builds fail with "Failed to load the default metallib". Must: (1) `swift build -c release`, (2) `cp <mlx.metallib> .build/release/`. Get metallib via `pip install --target /tmp/mlx-metallib mlx==<version>` where version matches `mlx-swift` in Package.resolved.
- **Model cache is `~/Library/Caches/models/<org>/<model>`** — e.g. `~/Library/Caches/models/mlx-community/Qwen3.5-9B-MLX-4bit`. Doctor checks this path directly (NOT HuggingFace's `models--` format).
- **Prefer `loadModelContainer(configuration:)`** over `loadModelContainer(id:)` — takes a `ModelConfiguration` so fields like `toolCallFormat` can be set before loading.
- **Use `ModelContainer` directly** — don't use `ChatSession`; SwiftClaw's `Session` actor owns the agentic loop.
- **`ToolSpec` is in `Tokenizers`** — add `import Tokenizers` (from swift-transformers, a transitive dep of mlx-swift-lm)
- **`GenerateStopReason` has no `.toolCall`** — detect tool calls via `!collectedToolCalls.isEmpty`, not stop reason.

### Qwen3.5 Model

- **Qwen3.5 tool calls parsed by `Qwen35ToolCallParser`** — `Sources/SwiftClawMLX/Qwen35ToolCallParser.swift` is a fallback that scans accumulated text for `<tool_call>` blocks when mlx-swift-lm doesn't emit native `.toolCall` events. `swift package update` is now safe — no checkout patches needed.
- **Tool Arguments: accept string-encoded integers** — the Qwen3.5 XML parser passes all parameter values as strings. Tool `Arguments` structs with `Int?` fields need a custom `Decodable` that accepts both `Int` and numeric `String`. See `ProcessListTool` and `ShellTool` for the pattern.
- **Qwen3.5 `<think>` blocks** — model streams reasoning content *without* an opening `<think>` tag; only `</think>` is emitted. Regex `<think>.*</think>` never matches. Filter: `if let r = text.range(of: "</think>") { text = String(text[r.upperBound...]) }` (in `ModelBackend` non-streaming extension).
- **`ToolCallFormat.json` is correct for Qwen3.5** — uses `<tool_call>{...}</tool_call>`. `.xmlFunction` is for Qwen3 **Coder** only. `ToolCallFormat.infer("qwen3_5")` returns nil, which correctly defaults to `.json`.
- **Qwen3.5 tool calls — text-injection (verified 2026-03-05)** — passing `UserInput.tools` or any `<tool_call>` token in the system message triggers EOS-after-think (model stops generating after `</think>`). `enable_thinking: false` also fails — generates 0 tokens. Working fix: `toolSpecs = nil`, inject tool descriptions as plain text with `<function=NAME>` format (no `<tool_call>` token); `Qwen35ToolCallParser` handles bare `<function=...>` blocks; `ModelBackend` strips them from response text.

### Testing & Tools

- **macOS `ps` has no `--sort`** — use `/bin/ps -a -x -m -o pid,user,%cpu,%mem,command` (GNU flags don't work)
- **Pipe deadlock with `Process`** — drain both pipes via `DispatchGroup` BEFORE `waitUntilExit()`; pipe buffer ~64KB
- **ShellSandbox redirect pattern** — use `">"` not `">{"`; plain `>` catches all redirect forms
- **E2E testing via piped stdin** — `echo "prompt"` closes stdin before the REPL reads it. Use `printf "prompt\n/quit\n" | .build/release/swiftclaw run` to include an explicit quit after the message.
- **Test isolation pattern for stores** — use `init(param: URL? = nil)` where `nil` = real home dir and non-nil = test temp dir; matches `FileSessionStore(baseDir:)`. Don't add `__testInit` factory methods.
- **`OutputFormatting.swift` is the shared CLI utility file** — add small `swiftclaw`-target helpers there (e.g. `col()`, `parseTags()`); it's the target's utils module.
- **`list_directory` doesn't expand `~`** — `FileManager` won't expand tilde in paths; model must pass absolute paths or use the `shell` tool with `ls ~/...` instead.
