# Changelog

All notable changes to SwiftClaw are documented here.

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
