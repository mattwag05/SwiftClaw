# SwiftClaw — Product Requirements Document

**Version:** 4.8.0
**Last updated:** 2026-04-24
**Owner:** @mattwag05
**Repo:** https://github.com/mattwag05/SwiftClaw

---

## 1. Vision

SwiftClaw is a **macOS-first, Swift-native AI agent framework** that runs fully on-device using Apple Silicon. It gives Swift developers a clean, protocol-based way to build agentic applications — the agentic loop (prompt → LLM → tool calls → results → loop), a first-class tool system, persistent session state, semantic memory, and LoRA fine-tuning — without vendor lock-in and without a cloud surface.

**Philosophy.** Model weights and agent state stay local by default. Agents are plain Swift code + config, not an SDK bound to a particular provider. Privacy and self-hosting are the default, not a premium tier.

## 2. Target Users

- **Swift developers on Apple Silicon** who want to ship local AI features in macOS apps without piping data to OpenAI/Anthropic.
- **Homelab / privacy-focused power users** who already run Ollama locally and want a single Swift framework that speaks both MLX (on-device) and the OpenAI-compatible HTTP protocol.
- **Researchers and tinkerers** doing LoRA experiments on their own machine — train adapters from conversation traces, A/B eval them, tag and route them at inference time.
- **The author (dogfooding).** SwiftClaw is the agent runtime under other projects in `~/Desktop/Projects/` (Pippin integration, Personal Agent, future Headwater automations).

## 3. Non-Goals

- **Cloud-first / SaaS.** No hosted backend, no account system, no telemetry.
- **Cross-platform parity at launch.** iOS, Linux, and Windows are long-term (P3). macOS 15+ on Apple Silicon is the only supported target today.
- **Proprietary skill format.** Any ecosystem convergence (e.g. agentskills.io) is a future migration, not a fork point.
- **Lock-in to a single model family.** Qwen3.5 is the default because it works well; the architecture must stay backend- and model-agnostic.

## 4. Current State (v4.8, 2026-04-21)

### 4.1 Shipped Capabilities

**Runtime.**
- Swift 6.2, strict concurrency, zero warnings.
- `Session` actor owns mutable conversation state; `Agent` is an immutable `Sendable` struct.
- `ModelBackend` protocol with two production backends: `MLXBackend` (on-device via mlx-swift-lm) and `HTTPBackend` (OpenAI-compatible, Foundation-only, SSE streaming).
- `FileSessionStore` at `~/.swiftclaw/sessions/<id>.json` — create/resume/export sessions; shared between CLI and SwiftUI app.
- `ProcessMonitor` actor for sentinel-based child process management (`__READY__` marker polling replaces sleep hacks).
- Context compression + memory consolidation hooks with config-driven thresholds (`consolidationInterval`, `compressionTokenThreshold`).

**Inference.**
- MLX default model: `mlx-community/Qwen3.5-9B-MLX-4bit`.
- HTTP default: `qwen2.5:7b` on `http://localhost:11434/v1` (Ollama).
- Qwen3.5 tool-call handling via text-injection + `Qwen35ToolCallParser` (works around the EOS-after-think failure mode of native tool specs).
- Streaming text, tool calls, and token usage through a unified `StreamChunk` enum; usage includes Anthropic cache read/creation token counts when applicable.
- **Anthropic prompt caching** (v4.6): system prompt + tool definitions marked `cache_control: ephemeral`; memory section split as an uncached block. Auto-detected from the API URL, opt-in via `--cache-mode`.

**Tools.**
- **Sysadmin (4):** `system_info`, `disk_space`, `process_list`, `shell` (sandboxed — allowlist + redirect/pipe guard + path-traversal block).
- **File ops (5):** `read_file`, `write_file`, `edit_file`, `list_directory`, `find_files`. `read_file` and `edit_file` support **hash-anchored edits** (v4.8) — per-line SHA256 hashes prevent stale-edit corruption.
- **Environment (3):** `env_vars` (credential pattern redaction), `date_time`, `clipboard`.
- **Process (4):** `start_process`, `process_output`, `stop_process`, `list_monitored_processes`.
- **Memory (4, opt-in via `--memory`):** `memory_write`, `memory_read`, `memory_search`, `memory_delete`.
- **Pippin Mail (6):** `mail_list`, `mail_show`, `mail_search`, `mail_send`, `mail_mark`, `mail_move`.
- **Pippin Memos (3):** `memos_list`, `memos_info`, `memos_transcribe`.
- **Pippin Calendar (3):** `calendar_events`, `calendar_create`, `calendar_smart_create`.
- Parallel tool execution via `withThrowingTaskGroup` when no approval delegate is present.

**Semantic memory (`SwiftClawMemory`).**
- `MemoryStore` actor backed by GRDB + SQLite FTS5 at `~/.swiftclaw/memory/memories.db`.
- Two layers — `working` (per-session) promoted to `longTerm` on `endSession()`.
- Hybrid retrieval scoring: semantic 0.5 + BM25 0.25 + recency 0.15 + frequency 0.10.
- `EmbeddingEngine` (hash-based 768-dim default) with `MLXEmbeddingEngine` available in `SwiftClawMLX`.
- `MemoryConsolidator` summarizes working → longTerm with robust markdown-fence stripping.

**LoRA fine-tuning (`SwiftClawMLX`).**
- `LoRATrainer` (native, via `MLXOptimizers`) trains adapters from session JSONL exports.
- `AdapterStore` at `~/.swiftclaw/adapters/<name>/`, `AdapterSelector` scores by tag overlap (60%) + val loss (25%) + recency (15%).
- `EvalStore` persists A/B eval results at `~/.swiftclaw/evals/<epoch>.json`; `swiftclaw eval` prompts for `[A/B/tie/skip]` winner.

**CLI & App.**
- `swiftclaw` CLI: `run`, `doctor`, `tools`, `sessions`, `train`, `adapters`, `eval`, `download`.
- `SwiftClawApp` — macOS SwiftUI app wrapping the same runtime; `@Observable` view models; shares `FileSessionStore` with the CLI.
- `SwiftClawUI` — reusable design system: tokens (`Theme.swift`, `Typography.swift`, `Spacing.swift`), `SC*` primitives, NavigationSplitView with folders + pinning, ⌘K command palette, split settings, reasoning/tool-group/timeline views.
- Dynamic Type support via `@ScaledMetric`; icon-only buttons labeled for VoiceOver.

**CI & release hygiene.**
- GitHub Actions pinned to commit SHAs.
- `Package.resolved` committed to lock transitive deps.
- Unicode safety scan + CodeQL workflow.
- 280/280 tests passing across 6 test targets (`SwiftClawCoreTests`, `SwiftClawHTTPTests`, `SwiftClawMemoryTests`, `SwiftClawMLXTests`, `SwiftClawPippinTests`, `SwiftClawToolsTests`), plus new `SwiftClawUITests` target covering `SessionGrouper`.

### 4.2 In-Flight (uncommitted on current branch)

- **Model discovery service.** `SwiftClawCore/Models/DiscoveredModel.swift` defines a `Sendable, Identifiable` descriptor (id, size, parameter size, quantization, family, source ∈ `{ollama, openai, mlx}`). `SwiftClawHTTP/ModelDiscoveryService.swift` enumerates running HTTP backends; `SwiftClawMLX/MLXModelScanner.swift` scans the local MLX cache.
- **App settings integration.** `ModelSettingsView`, `GeneralSettingsView`, `QuickSettingsPopover`, `ChatViewModel`, and `BackendStatusView` updated to surface discovered models (pick a model from a real list instead of typing a string).
- **Backend capabilities surface.** `ModelCapabilities.swift` + `StreamChunk.swift` tweaks thread capability info through to the UI.

This is the PR 7 / model-picker workstream — ship target is v4.9.

## 5. Release Plan

### 5.1 v4.9 — Model picker & discovery (current sprint)

- [x] Ship `DiscoveredModel` + scanners (Ollama, OpenAI-compatible, MLX cache).
- [x] Model-selection UI in Settings and Quick Settings with size/quant/family badges.
- [x] CLI `swiftclaw models list [--backend mlx|http]` parity.
- [x] Tests for both scanners (mock HTTP responses; fixture MLX cache dir).

### 5.2 Near-term — P0 (Week 1-2 after v4.9)

- **Lazy skill loading.** Send skill summaries first; fetch full content on demand to shrink base prompt.
- **Credential proxy.** Intercept secrets before tool execution; prevent key leakage into LoRA training data / session logs.

### 5.3 Short-term — P1 (Month 1)

- **Apple Container sandbox for `shell`** (macOS 26 native; replaces `FileSandbox`).
- **Per-conversation FIFO queue** — prevents concurrent session corruption when multiple callers hit the same `Session` actor.
- **Hash-anchored edits v2** — multi-line anchors; expose anchor helpers to custom tools.

### 5.4 Mid-term — P2 (Month 2-3)

- **Vision OCR GUI automation** — Vision.framework + `screencapture` to replace JXA on Electron apps.
- **MCP client integration** — Anthropic protocol, 200+ external tool servers.
- **Cross-provider conversation handoff** — `ContextTranslator` protocol for MLX → HTTP fallback mid-conversation.
- **JSONL session branching** — tree-structured history; avoids duplication on forks.
- **Background parallel agent execution.**
- **Metric-driven LoRA iteration loop** — autoresearch-style keep/revert on `val_bpb`.

### 5.5 Long-term — P3

- iOS support.
- Remote/cloud model backends.
- Subagent parallelism (actor-isolated subagents).
- 3-tier context assembly (recent messages + retrieved memories + agent CLAUDE.md).
- GrimClaw ↔ SwiftClaw HTTP bridge (Pi agent delegates macOS tasks).
- A2UI Canvas (agent-generated SwiftUI in the app canvas panel).
- agentskills.io standard migration.

## 6. Architecture Principles

1. **Protocol-first.** `SwiftClawTool`, `ModelBackend`, `MemoryProvider`, `SessionStore` — every replaceable surface is a protocol.
2. **Actors for mutable state, structs for config.** Sessions and stores are actors; agents and configurations are `Sendable` structs.
3. **Swift 6 strict concurrency with no workarounds.** The codebase compiles clean with zero warnings. Concurrency gotchas are documented in `CLAUDE.md`.
4. **Tool arguments are JSON strings.** Avoids `Any`, which isn't `Sendable`.
5. **JSON-encoded integers must decode forgivingly.** `DecodingHelpers.decodeIntOrStringIfPresent` is used for any `Int?` argument because Qwen3.5's XML parser emits strings.
6. **Atomic file writes with `replaceItemAt` only.** Never pair with `.atomic` — documented footgun.
7. **Foundation-only where possible.** HTTP backend uses `URLSession` + custom SSE parsing — no Alamofire, no AsyncHTTPClient.
8. **CLI and App share the same runtime.** Any new capability lands in a library target; CLI and app consume it identically.

## 7. Success Metrics

- **Zero-cloud default.** `--backend mlx` works offline end-to-end including memory, sessions, and LoRA training.
- **Test coverage.** ≥ 280 passing tests; every new feature lands with tests.
- **Build speed.** Clean `swift build` under 90s on M1.
- **Startup latency.** `swiftclaw run` to first prompt under 3s (HTTP backend); under 15s (MLX, cold model load).
- **Prompt cache hit rate ≥ 50%** on HTTP backend sessions longer than 3 turns with stable system prompt.
- **Dogfooding.** SwiftClaw powers at least one other project in `~/Desktop/Projects/` by v5.0.

## 8. Open Questions

- **Apple Container sandbox availability.** macOS 26 ships native `Container`, but API surface and entitlements for non-App-Store binaries still need validation.
- **MCP client surface.** Do we embed a full MCP client in `SwiftClawCore`, or ship it as a separate `SwiftClawMCP` target to keep core slim? Current lean: separate target.
- **LoRA adapter distribution.** Is there a privacy-respecting registry format for sharing adapters across machines/users, or do we punt on distribution until there's demand?
- **iOS port scope.** Full parity, or a reduced `SwiftClawCoreMobile` that drops `shell`/`ProcessMonitor` and targets HTTP-only backends?

## 9. Related Documents

- `README.md` — user-facing quick start and feature list.
- `CHANGELOG.md` — versioned change history.
- `CLAUDE.md` — architecture decisions, gotchas, conventions (AI-maintained).
- `CONTRIBUTING.md` — contributor workflow.
- `docs/superpowers/specs/2026-03-12-semantic-memory-system-design.md` — memory subsystem design.
- Beads issue tracker — source of truth for open work (`bd ready`).
