# Changelog

All notable changes to SwiftClaw are documented here.

## [Unreleased] — 2026-03-14 audit pass

### Summary
5 issues identified, 5 fixed. 0 deferred. All 233 tests pass.

#### [security] `SwiftClawTools/EnvVarsTool.swift`
**Problem:** `env_vars` tool dumped all process environment variables to the LLM
without filtering, exposing API keys, tokens, passwords, and other credentials
stored in env vars (e.g. `OPENAI_API_KEY`, `AWS_SECRET_ACCESS_KEY`).
**Fix:** Added `sensitivePatterns` allowlist. Variable values whose names contain
`KEY`, `TOKEN`, `SECRET`, `PASSWORD`, `PASSWD`, `CREDENTIAL`, `AUTH`, `PRIVATE`,
`CERT`, or `SESSION` are replaced with `[REDACTED]` in both full-dump and
single-variable lookup responses.

#### [bug] `SwiftClawMemory/MemoryStore.swift` — `promote`
**Problem:** `promote(keys:)` inserted promoted entries into the `longTerm` layer
with `embedding = NULL` but never called `scheduleEmbedding`. Promoted memories
always received `semanticScore = 0.0` in subsequent searches, degrading retrieval
quality silently.
**Fix:** Added `scheduleEmbedding(key: key, layer: .longTerm)` after each promotion
transaction so embeddings are computed asynchronously in the background.

#### [bug] `SwiftClawCore/Session/Session.swift` + `SessionConfiguration.swift`
**Problem:** `Session.runLoop` hardcoded `topK: 10` and threshold `0.3` for memory
retrieval injection, ignoring `SwiftClawConfig.retrievalTopK` and
`SwiftClawConfig.retrievalThreshold` that users can set in `~/.swiftclaw/config.json`.
**Fix:** Added `retrievalTopK: Int` and `retrievalThreshold: Float` to
`SessionConfiguration` (defaults matching prior hardcoded values). Updated
`Session.runLoop` to use `config.retrievalTopK` / `config.retrievalThreshold`.
Updated `RunCommand` and `ChatViewModel` to populate these from `SwiftClawConfig`.
Also removed the internal score `(score: 0.xx)` suffix from injected memory text
to reduce LLM clutter.

#### [quality] `SwiftClawMemory/MemoryStore.swift` — `search`
**Problem:** Layer extraction for the access-count update loop called
`Self.entryFromRow($0.row).key` inside a linear scan per top-K result — O(n×k)
`MemoryEntry` allocations that were immediately discarded.
**Fix:** The `scored` tuple now carries `layerVal: String` captured once per
candidate during scoring. The downstream map becomes a simple field access.

#### [token] `SwiftClawCore/Memory/ContextCompressor.swift` — `estimateTokens`
**Problem:** Token estimate only counted `message.content.count / 4`, ignoring
`toolCalls[].arguments` (JSON strings) and `toolCalls[].name`. Tool-heavy sessions
with large argument payloads were systematically under-counted, causing the
compressor to trigger later than intended and risking context overflow.
**Fix:** `estimateTokens` now sums `content.count + toolCallChars` (where
`toolCallChars = Σ(arguments.count + name.count)`) before dividing by 4.

---

## [0.1.0] — 2026-03-11

Initial public release.

### Core Runtime (`SwiftClawCore`)
- Actor-based `Session` for safe concurrent conversation state
- `ModelBackend` protocol enabling pluggable inference backends
- `SwiftClawTool` protocol for custom tool definitions with JSON schema
- `ToolRegistry` for tool registration and dispatch
- `SessionStore` protocol + `FileSessionStore` for persistent sessions (`~/.swiftclaw/sessions/`)
- `AgentMemory` actor for persistent key-value agent memory (`~/.swiftclaw/memory/`)
- `ContextCompressor` and `MemoryConsolidator` for long-context handling
- `ToolApprovalDelegate` protocol for interactive tool approval flows
- `TraceExporter` for exporting sessions as LoRA training JSONL

### MLX Backend (`SwiftClawMLX`)
- Native on-device inference via `mlx-swift-lm` (no Python runtime)
- Streaming generation with `AsyncThrowingStream<StreamChunk, Error>`
- `Qwen35ToolCallParser` — fallback `<tool_call>` / `<function=...>` block parser for Qwen3.5
- `LoRATrainer` — train adapters from exported session JSONL via `MLXOptimizers`
- `AdapterStore` — adapter metadata lifecycle in `~/.swiftclaw/adapters/`
- `AdapterSelector` — scores adapters by tag overlap (60%), validation loss (25%), recency (15%)
- `EvalStore` — A/B eval result persistence in `~/.swiftclaw/evals/`

### HTTP Backend (`SwiftClawHTTP`)
- OpenAI-compatible HTTP backend targeting Ollama and OpenAI APIs
- SSE streaming parser (`SSEParser`)
- Foundation-only, no third-party networking dependencies

### Built-in Tools (`SwiftClawTools`)
- `shell` — sandboxed shell command execution
- `read_file` / `write_file` — file I/O with configurable sandbox paths
- `list_directory` / `find_files` — directory browsing
- `system_info` / `disk_space` / `process_list` — system introspection
- `date_time` / `env_vars` / `clipboard` — environment tools
- `SwiftClawToolFactory.allTools(config:)` for bulk registration

### Pippin Integration (`SwiftClawPippin`)
- Mail tools: `mail_list`, `mail_show`, `mail_search`, `mail_send`, `mail_mark`, `mail_move`
- Memos tools: `memos_list`, `memos_info`, `memos_transcribe`
- Gracefully returns empty tool list if `pippin` binary is absent

### macOS App (`SwiftClawApp`)
- SwiftUI app sharing the same `SessionStore` as the CLI
- Real-time streaming chat with thinking/reasoning display
- Collapsible sidebar with session list
- Tool call approval UI
- Quick settings popover (backend, model, sandbox)
- Suggestion chips for empty state

### CLI (`swiftclaw`)
- `run` — interactive REPL with session persistence, backend selection, adapter loading
- `sessions list/show/delete/export` — session management
- `train` — LoRA adapter training from exported sessions
- `adapters list/delete/tag` — adapter lifecycle
- `eval` — A/B evaluation between base model and adapters
- `tools` — list registered tools
- `doctor` — system diagnostics (MLX, model cache, config)

### Tests
- 175 tests across 5 targets
- `MockBackend` pattern for protocol-isolated core tests (no model download required)
