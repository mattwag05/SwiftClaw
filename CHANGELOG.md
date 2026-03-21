# Changelog

All notable changes to SwiftClaw are documented here.

## [4.5] — 2026-03-21

### Security hardening + token counting + parallel tools + audit fixes

**[security]** `ShellSandbox.swift` — added `"../"` and `"/.."` to `dangerousPatterns`; path traversal arguments (e.g. `cat ../../../etc/passwd`) now throw `dangerousPattern` before the allowlist check. Two new tests confirm rejection.

**[security]** `EnvVarsTool.swift` — all env var lookups (bulk dump and single-variable) now redact variables whose names contain credential patterns (`KEY`, `SECRET`, `TOKEN`, `PASSWORD`, `PASSWD`, `CREDENTIAL`, `PRIVATE`, `AUTH`, `ACCESS`, `SESSION`, `CERT`, `SIGNING`). One new test validates bulk redaction.

**[bug]** `MemoryConsolidator.swift` — removed malformed-LLM fallback that stored raw model output as a fact when JSON decoding failed. Malformed responses are now silently dropped, preventing garbage entries in the memory store. Updated `consolidatorFallsBackOnInvalidJSON` → `consolidatorDropsSilentlyOnInvalidJSON` test to assert empty return.

**[bug]** `MemoryStore.swift` — `promote(keys:)` now calls `scheduleEmbedding` after each promotion so promoted entries receive embeddings and score correctly in semantic search instead of always returning 0.0.

**[bug]** `Session.swift` + `SessionConfiguration.swift` — memory retrieval injection previously hardcoded `topK: 10` and `threshold: 0.3`, ignoring `SwiftClawConfig` values. `SessionConfiguration` now carries `retrievalTopK` and `retrievalThreshold`; `RunCommand` and `ChatViewModel` propagate config-file values through.

**[feature]** `StreamChunk.swift`, `Response.swift`, `ModelBackend.swift`, `OpenAITypes.swift`, `HTTPBackend.swift`, `Session.swift` — end-to-end token usage tracking for the HTTP backend. `TokenUsage` struct (promptTokens, completionTokens, totalTokens) added to `StreamChunk` and `GenerationResponse`. `HTTPBackend` now sends `stream_options: {include_usage: true}` and parses the final usage-only SSE chunk. Usage flows through `Session.runLoop` into every `.turn` event. One new test verifies SSE usage chunk parsing.

**[feature]** `Session.swift` — parallel tool execution when no approval delegate is present. Multiple tool calls in a single turn now execute concurrently via `withThrowingTaskGroup`; results are re-ordered by original call index before being appended to history. Sequential execution is preserved for approval-delegate flows to maintain interactive ordering.

**[quality]** `ContextCompressor.swift` — `estimateTokens` now sums `content.count + toolCallChars` (arguments + name) before dividing by 4, preventing systematic under-counting in tool-heavy sessions that could delay compression and risk context overflow.

**[quality]** `MemoryStore.swift` — `search` now captures `layerVal` in the scored tuple at scoring time, eliminating O(n×k) `MemoryEntry` allocations in the access-count update loop.

**[test]** 4 new tests, 1 renamed test; total count 237 (was 233).

**Summary:** 2 security fixes, 3 bug fixes, 2 features added, 2 quality improvements, 237/237 tests passing.

---

## [4.4] — 2026-03-17

### Bug fixes + P0 calendar tools

**[bug]** `Version.swift` — corrected `SwiftClawVersion.version` from stale `"0.1.0"` to `"4.4.0"`; startup banner now reports the real version.

**[bug]** `RunCommand.swift` — `SwiftClawConfig` fields `consolidationInterval` and `compressionTokenThreshold` were loaded from `~/.swiftclaw/config.json` but never applied to `SessionConfiguration`; config file changes now take effect.

**[quality]** `MemoryConsolidator.swift` — added markdown code-fence stripping before JSON decode; prevents silent fallback-to-single-fact when the model wraps its response in ` ```json ` fences despite instructions.

**[feature]** `CalendarEventsTool`, `CalendarCreateTool`, `CalendarSmartCreateTool` — three new `SwiftClawPippin` tools backed by `pippin calendar` (list events, create event, natural-language smart-create). All registered in `PippinToolFactory`. `CalendarCreateTool` and `CalendarSmartCreateTool` set `requiresConfirmation = true`. Roadmap: P0 Calendar tool exposure.

**[test]** `PlaceholderTests.swift` — updated `versionExists()` assertion to expect `"4.4.0"`.

**Summary:** 4 issues fixed, 1 feature added, 233/233 tests passing.

---

## [4.3] — 2026-03-16

### SwiftUI polish

- Warm russet color palette throughout the macOS app
- Time-grouped sidebar (Today / Yesterday / This Week / Older)
- Live status bar showing token count, model, and backend
- Richer settings popover with memory and adapter controls

---

## [4.2] — 2026-03-14

### SwiftUI settings persistence + download command

- SwiftUI app persists backend, model, sandbox, and memory settings to `~/.swiftclaw/config.json`
- `swiftclaw download [--model ID]` command pre-downloads a model to the cache without starting a session

---

## [4.1] — 2026-03-12

### MLX embedding model

- `EmbeddingProvider` protocol in `SwiftClawCore` — actor-constrained, `nonisolated var dimensions`
- `MLXEmbeddingEngine` in `SwiftClawMLX` — lazy-loads `nomic-ai/nomic-embed-text-v1.5` via `MLXEmbedders`; gracefully degrades to hash-based fallback on load failure
- `MemoryStore` accepts `(any EmbeddingProvider)?`; dimension-mismatch guard prevents stale vector comparisons
- `MemoryStore.reindex()` — nulls embeddings and schedules background re-embedding after engine swap
- `RunCommand` wires `MLXEmbeddingEngine` for `--backend mlx --memory`; hash fallback for HTTP

---

## [4.0] — 2026-03-12

### Semantic memory system

- New `SwiftClawMemory` SPM target
- `MemoryStore` actor — SQLite + FTS5 via GRDB; two-layer architecture (working / longTerm); JSON migration from legacy `*.json` files
- `EmbeddingEngine` — deterministic hash-based 768-dim vectors
- `MemoryRetriever` — hybrid scoring: semantic × 0.5 + BM25 × 0.25 + recency × 0.15 + frequency × 0.10
- `MemoryProvider` protocol in `SwiftClawCore` — replaces `AgentMemory` actor
- 4 memory tools via `MemoryToolFactory.allTools(store:)`: `memory_write`, `memory_read`, `memory_search`, `memory_delete`
- `Session.endSession()` promotes working → longTerm and clears working layer
- `--memory` flag on `swiftclaw run` enables two-layer memory
- REPL commands: `/memory`, `/memory search <query>`, `/memory clear working`, `/memory clear all`

---

## [3.0] — 2026-03-10

### macOS SwiftUI app

- New `SwiftClawUI` and `SwiftClawApp` SPM targets
- Real-time streaming chat with thinking/reasoning block display
- Collapsible sidebar with session list
- Tool call approval UI
- Quick settings popover (backend, model, sandbox paths)
- Suggestion chips for empty state
- Shares `FileSessionStore` with the CLI — sessions visible in both interfaces

---

## [2.3] — 2026-03-09

### Adapter auto-select and A/B evaluation

- `AdapterSelector` — scores adapters by tag overlap (60%), validation loss (25%), recency (15%)
- `--auto-adapter` flag on `swiftclaw run` selects the best adapter automatically
- `swiftclaw eval "prompt" [--adapter-a <n>] --adapter-b <n>` — side-by-side A/B eval; prompts for winner `[A/B/tie/skip]`
- `EvalStore` — persists results to `~/.swiftclaw/evals/<epoch>.json`
- `swiftclaw adapters tag <name> --add "..." --remove "..."` — tag lifecycle

---

## [2.2] — 2026-03-08

### LoRA fine-tuning from agent traces

- `TraceExporter` in `SwiftClawCore` — exports sessions as LoRA training JSONL (tool-call turns filtered)
- `swiftclaw sessions export <id>` — export CLI subcommand
- `LoRATrainer` in `SwiftClawMLX` — trains adapters via `MLXOptimizers`; stores to `~/.swiftclaw/adapters/<name>/`
- `AdapterStore` — adapter metadata and lifecycle management
- `swiftclaw train --name <n> --sessions <id1,id2> [--iterations N]`
- `swiftclaw adapters list/delete`
- `--adapter <path>` flag on `swiftclaw run` (MLX only)

---

## [2.1] — 2026-03-08

### Security hardening and agentic loop improvements

- Supply-chain hardening against dependency injection attacks
- `ToolRegistry.execute` wraps execution in do/catch; returns `.failure(...)` on throws
- `ToolRegistry.definitions` sorted by name for deterministic LLM tool ordering
- `Session.runLoop` enforces `maxTotalMessages` by trimming oldest non-system messages
- `DoctorCommand` pass/fail tracking; shows all tools via factories
- REPL `/help` and `/tools` commands added
- Unnamed sessions no longer auto-saved to disk

---

## [0.1.0] — 2026-03-11

Initial public release.

### Core Runtime (`SwiftClawCore`)
- Actor-based `Session` for safe concurrent conversation state
- `ModelBackend` protocol enabling pluggable inference backends
- `SwiftClawTool` protocol for custom tool definitions with JSON schema
- `ToolRegistry` for tool registration and dispatch
- `SessionStore` protocol + `FileSessionStore` for persistent sessions (`~/.swiftclaw/sessions/`)
- `ContextCompressor` and `MemoryConsolidator` for long-context handling
- `ToolApprovalDelegate` protocol for interactive tool approval flows

### MLX Backend (`SwiftClawMLX`)
- Native on-device inference via `mlx-swift-lm` (no Python runtime)
- Streaming generation with `AsyncThrowingStream<StreamChunk, Error>`
- `Qwen35ToolCallParser` — fallback `<tool_call>` / `<function=...>` block parser for Qwen3.5

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

### CLI (`swiftclaw`)
- `run` — interactive REPL with session persistence and backend selection
- `sessions list/show/delete` — session management
- `tools` — list registered tools
- `doctor` — system diagnostics (MLX, model cache, config)

### Tests
- 175 tests across 5 targets
- `MockBackend` pattern for protocol-isolated core tests (no model download required)
