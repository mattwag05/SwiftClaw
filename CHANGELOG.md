# Changelog

All notable changes to SwiftClaw are documented here.

## [5.2] — 2026-05-08

### Perplexity Computer-style UI overhaul

**[feature]** New `PXTheme` namespace (`Sources/SwiftClawUI/Theme/PerplexityTheme.swift`) — dark-first palette (`#0c0c0d` window → `#1a1a1d` surfaces), teal `#1ea7b5` accent, geometry/motion tokens, italic-serif `PXWordmark` lockup.

**[feature]** `PerplexityRoot` (`Sources/SwiftClawApp/Layout/PerplexityRoot.swift`) — 2-column layout replacing the legacy 3-column `NavigationSplitView`. Hosts `PerplexitySidebar` + dynamic main pane that switches between `PerplexityChatPane`, `SpacesPane`, `ArtifactsPane`, `CustomizePane` based on `NavSelection`. Reveal-sidebar floating button (with traffic-light clearance) when sidebar is collapsed via ⌘\.

**[feature]** `PerplexitySidebar` — single-column dark sidebar with prominent "+ New Thread" button, four nav items (All Threads / Spaces / Artifacts / Customize), inline new-space link, search field, "RECENT" group with Today/Yesterday headers and polite empty state, monospaced backend·model footer, hover-aware `NavRow`/`SessionRow` (`Sources/SwiftClawApp/Layout/SidebarRows.swift`).

**[feature]** `PerplexityChatPane` — empty state with centered wordmark + state-aware model byline (live status dot: success/warning/danger/idle + label) + composer + keyboard shortcut hint row + suggestion chips. Active state: top bar with usage indicator, stop button, top-right new-thread "+", transcript via `GemmaMessageList` (24pt padding, bounded width), and pinned composer well with chatBg gradient fade-in.

**[feature]** `PXComposer` (`Sources/SwiftClawUI/Chat/PXComposer.swift`) — pill-shaped input using `TextField(axis:.vertical)`. Action chip row: paperclip → `AttachPopoverView` (clipboard preview + file picker + screenshot/window placeholders), globe → web-context toggle (persisted, injects per-message prompt prelude), at → `MentionPopoverView` (active app name, clipboard, today's date/time as natural-language snippets), Chat/Build mode menu, mic → coming-soon popover, circular send button with pulse + glow when text non-empty. Cmd+L focuses via NotificationCenter; ↩ sends, ⇧↩ newlines.

**[feature]** `PerplexityCommandBar` + `CommandBarController` + `GlobalHotkeyMonitor` — floating `NSPanel` HUD-blur surface summoned by double-Command gesture (Carbon-NSEvent flagsChanged tap detector) or ⌃⌘P Carbon hotkey fallback. State machine: idle (composer) → working (pulsing dot + live preview + stop) → done (auto-dismiss after 4.5s). Avoids ⌥⌘Space because it conflicts with Finder's "Show Find".

**[feature]** `HotkeyHintOverlay` — first-launch compact pill teaching the double-Command gesture (matches video frame_20). Auto-fades after 30s; persists `sc.hasSeenHotkeyHint` so it never returns.

**[feature]** `SpacesPane` / `ArtifactsPane` / `CustomizePane` — distinct content surfaces for each non-chat sidebar item. `ArtifactsPane` scans `~/.swiftclaw/workspaces/` and renders a most-recently-touched grid. `CustomizePane` exposes theme/font-scale/suggestion-chip/serif-wordmark/activation-trigger toggles, all wired to live UI.

**[feature]** `ActivationSettingsView` — new Settings → Activation tab with command-bar trigger picker, default-mode dropdown, suggest-open-docs toggle, prevent-system-sleep toggle, "Show command bar now" tester, and a yellow accessibility callout (with "Open System Settings" + "Re-check") when `AXIsProcessTrusted()` is false so users know why the gesture isn't firing.

**[feature]** `PerplexityWindowChrome` — hidden titlebar, inset traffic lights, behind-window vibrancy (dark mode) / solid (light mode). Default size 1180×760, min 920×600.

**[feature]** Command palette additions (`Commands.swift`): "Summon Command Bar" (⌃⌘P), "Focus Composer" (⌘L), eight most-recent threads for fuzzy thread-switching with ⌘K + typing.

**[feature]** App default theme is now dark; HTTP backend default model is `gemma4:latest` (matches `feat/gemma-port` branch and the typical Ollama install on this Mac).

**[feature]** Backend pre-warm — HTTP backend now initializes during `ChatViewModel.init`'s startup task instead of lazily on first send; the green "ready" status dot appears before the user types.

**[bug]** `ChatViewModel.send()` no longer silently drops a turn when `newChat()`'s `loadBackend` fails — appends the user message and a warning bubble pointing to Settings → General.

**[bug]** `SessionMetadata.mode` was defaulting to `.chat` in `newChat()` regardless of the user's current `sessionMode` — Build mode never persisted on save/reload. Now passes the live `sessionMode`.

**[bug]** Auto-save persisted stale metadata — `mode` / `canvasSplit` / `updatedAt` now refresh from live state on every save and write back to `currentMetadata`.

**[bug]** `lastTokenUsage` was sticky across session changes — empty-state usage indicator showed the previous session's token count. Reset in `newChat`/`selectSession`/`deleteSession`.

**[bug]** `selectSession` load failure left `selectedSessionId` pointing at the broken session id — UI looked stuck. Now rolls back selection + clears session/metadata on error.

**[bug]** Streaming bubble leaked as forever-streaming after cancellation — when `for try await` exited via `Task.isCancelled` break, the `.done` case never fired and the catch block didn't fire without an error, so the in-progress assistant bubble stayed in `isStreaming: true` state forever. Now finalized to `.assistant(currentText)` (or removed if empty) before `doSend` exits.

**[bug]** Sidebar footer double-truncated to "qw…codin…" because internal trim added "…" then SwiftUI's `.middle` truncation added "…" again. Now uses tail truncation only.

**[bug]** `⌥⌘Space` Carbon hotkey conflicted with Finder's "Show Find" globally — replaced with `⌃⌘P` (no known system binding).

**[quality]** Polished warning bubble — amber-tinted card with border instead of a thin caption row.

**[quality]** Consolidated keyboard shortcuts — removed three duplicate `⌘N` declarations, two duplicate `⌘\` declarations, and the hidden Button workaround. The `⌘\` chain now flows menu → notification → root listener.

**[quality]** Pre-token thinking dots (`ThinkingDotsView`) replace an invisible caret when streaming starts with no text yet.

**[quality]** Removed `ContentView.swift`, `ChatDetailView.swift`, `Layout/SidebarNavView.swift`, `Layout/SessionListColumn.swift` — superseded by the new `Perplexity*` layout.

**Summary:** 17 new files, 7 deleted, 10 real bugs fixed, full Perplexity Computer-style UI/UX rebuild, 460/460 tests passing.

---

## [5.1] — 2026-05-04

### Credential Proxy

**[security]** `CredentialProxy` protocol (`Sources/SwiftClawCore/Security/CredentialProxy.swift`) — `NoOpCredentialProxy` (passthrough) and `RegexCredentialProxy` (redacts well-known secret shapes). Built-in patterns: AWS access key IDs (`AKIA…`), GitHub PATs (`ghp_/gho_/ghs_/ghu_/ghr_`), Anthropic keys (`sk-ant-…`), OpenAI keys (`sk-…`), Stripe keys (`sk_live_/sk_test_…`), Slack tokens (`xox[abprs]-…`), JWTs (three-segment `eyJ…`), PEM private-key blocks. Each match replaced with `[REDACTED:<family>]`. Accepts `extraPatterns: [(label, pattern)]` for user-defined additions.

**[security]** `ToolRegistry` — accepts `proxy: any CredentialProxy` (default `NoOpCredentialProxy()`). Scrubs tool call **arguments** before `tool.execute` and tool result **content** after, so the redacted string is the only copy that ever enters the message history (sessions, next LLM prompt, and training export all derive from messages).

**[security]** `AgentConfiguration` — new `credentialProxy: any CredentialProxy` field (default `NoOpCredentialProxy()`); passed through to `ToolRegistry` at `Agent.init`.

**[security]** `TraceExporter.exportAll` and `exportLine` — accept optional `proxy` parameter; scrub `Message.content` and `ToolCallRequest.arguments` before encoding ChatML. Defense-in-depth for the highest-risk sink (LoRA training JSONL).

**[feature]** `SwiftClawConfig` — two new backward-compatible fields: `credentialProxyEnabled: Bool` (default `true`), `credentialProxyExtraPatterns: [String]` (default `[]`). Old `config.json` files decode cleanly.

**[feature]** CLI `run` — credential proxy active by default (reads config); `--no-credential-proxy` flag disables for debugging.

**[feature]** CLI `sessions export` — proxy applied to JSONL output by default; `--no-credential-proxy` flag for raw export.

**[feature]** `ChatViewModel` — both `newChat()` and `selectSession()` build and inject the proxy from config.

**[test]** `CredentialProxyTests` — 12 tests: each built-in pattern family (positive + negative-control), multi-secret string, custom extra pattern, `NoOpCredentialProxy` passthrough.

**[test]** `ToolRegistryProxyTests` — 5 tests: result redaction, argument redaction (args scrubbed before tool sees them), no-op passthrough, default-init regression guard, unknown-tool error path.

**[test]** `TraceExporterTests` — 3 new tests: tool message content redacted in JSONL export, assistant `tool_calls.arguments` redacted, no-op proxy leaves content unchanged.

**Summary:** 1 new type, 8 features/security hardening changes, 20 new tests, 376/376 tests passing.

---

## [5.0] — 2026-05-04

### Lazy skill loading

**[feature]** `SwiftClawSkills` — new SPM library target. `Skill` (metadata struct), `SkillStore` (actor — lazily scans `~/.swiftclaw/skills/*/SKILL.md` on first access, caches results), `SkillLoader` (hand-rolled agentskills.io YAML frontmatter parser; `name` + `description` required, `triggers` optional), `SkillLoadTool` (fetches full markdown body on demand), `SkillPromptSection` (builds `## Available Skills` system-prompt appendix).

**[feature]** `SwiftClawConfig` — two new backward-compatible fields: `skillsEnabled: Bool` (default `false`), `skillsDirectory: String?` (default `~/.swiftclaw/skills`). Old `config.json` files decode cleanly via `decodeIfPresent`.

**[feature]** `RunCommand` — `--skills` flag enables skill loading; resolves `skillsDirectory` from config; appends skill summaries to system prompt and registers `skill_load` tool.

**[feature]** `SkillsCommand` — `swiftclaw skills list [--directory …]` and `swiftclaw skills show <name> [--directory …]` CLI subcommands.

**[feature]** `ChatViewModel` — both `newChat()` and `selectSession()` read `config.skillsEnabled` and inject skill summaries + tool when enabled.

**[quality]** Removed iCloud duplicate files (`ModelsCommand 2.swift`, `MLXModelScannerTests 2.swift`, `ModelDiscoveryServiceTests 2.swift`) that caused spurious linker errors.

**[test]** `SwiftClawSkillsTests` — 20 tests across `SkillLoaderTests` (frontmatter parsing, error cases, list parsing), `SkillStoreTests` (lazy load, caching, missing dir, malformed skill tolerance), `SkillPromptSectionTests` (nil on empty, content coverage, prompt append).

**Summary:** 1 new module, 6 features added, 20 new tests, 355/355 tests passing.

---

## [4.9] — 2026-05-04

### Model picker & discovery

**[feature]** `DiscoveredModel.swift` (Core) — `Sendable, Identifiable` descriptor: `id`, `size`, `parameterSize`, `quantization`, `family`, `source` (`ollama` / `openai` / `mlx`).

**[feature]** `ModelDiscoveryService.swift` (HTTP) — `listOllamaModels(baseURL:)` hits Ollama `GET /api/tags` (strips `/v1` suffix automatically); `getOllamaModelInfo(baseURL:model:)` hits `POST /api/show`; `listOpenAIModels(baseURL:apiKey:)` hits `GET /v1/models`. Accepts injectable `URLSession` for testing.

**[feature]** `MLXModelScanner.swift` (MLX) — walks `~/Library/Caches/models/<org>/<model>/` for `config.json`; infers `parameterSize` from `hidden_size × num_hidden_layers` heuristic; extracts `quantization` from model name. Accepts injectable `cacheBase: URL` for testing.

**[feature]** `ModelsCommand.swift` (CLI) — `swiftclaw models list [--backend mlx|http|all] [--api-url …] [--api-key …]`. Auto-selects Ollama vs OpenAI by URL host. Columnar output: `ID`, `SRC`, `PARAMS`, `QUANT`, `SIZE`.

**[feature]** App UI — `ModelSettingsView`, `GeneralSettingsView`, `QuickSettingsPopover`, `BackendStatusView`, `ChatViewModel` surface discovered models with size/quant/family badges.

**[test]** `ModelDiscoveryServiceTests.swift` — 6 tests via `MockURLProtocol` stub: field mapping, missing details, `/v1` stripping, OpenAI id mapping, Bearer header, non-2xx error throw.

**[test]** `MLXModelScannerTests.swift` — 7 tests via fixture cache dir: field inference, quant detection, skipping missing `config.json`, empty/non-existent cache, multi-org discovery, size computation.

**Summary:** 5 features added, 13 new tests, ~295/295 tests passing.

---

## [4.8] — 2026-04-21

### Hash-anchored file edits

**[feature]** `LineHashing.swift`, `ReadFileTool.swift`, `EditFileTool.swift` — optional line-hash anchoring for stale-safe edits. `read_file` accepts `include_hashes: true` which prefixes each emitted line with an 8-char SHA256 content hash (`a3f8c912 | import Foundation`). `edit_file` accepts optional `anchor_line` (1-based) + `anchor_hash` args; before applying the edit, the tool re-hashes the file's current line at `anchor_line` and rejects the edit with a clear "file has changed since you read it" message if the hash differs. Lets agents use short `old_string`s on large files without risking silent corruption from a stale match elsewhere.

**[test]** 9 new tests in `FileToolsTests.swift` covering `LineHashing.hash` stability, `read_file` hash emission (default off, opt-in on), `edit_file` anchor happy-path (on the edited line and on a different line), stale anchor rejection, partial anchor rejection (line-only or hash-only), and out-of-range anchor line.

**Summary:** 1 feature added, 9 tests added, 280/280 tests passing.

---

## [4.7] — 2026-03-23

### Quality follow-up: EditFileTool precision, CharacterSet static allocation, MemoryConsolidator efficiency

**[quality]** `EditFileTool.swift` — replaced `replacingOccurrences(of:with:)` with `replacingCharacters(in:matchRange,with:)`. The previous form re-scanned the string for the pattern after uniqueness was already verified; the new form replaces exactly the found range, which is both more precise and avoids a redundant O(n) scan. Also removed `.atomic` from the temp-file write (as documented in CLAUDE.md: `.atomic` internally creates its own temp file, so pairing it with `replaceItemAt` performed two rename syscalls). Cleaned up occurrence-detection control flow from switch-on-count to early-return on second occurrence.

**[quality]** `FileSessionStore.swift` — hoisted `allowedSessionIdChars: CharacterSet` to a static property. Previously the `CharacterSet` was allocated on every `sanitize(sessionId:)` call; a static let is created once at class load time, saving an allocation on every session access.

**[quality]** `MemoryConsolidator.swift` — fence stripping for the no-closing-marker case now uses `firstIndex(of:"\n")` with `String(raw[raw.index(after:newlineIdx)...])` instead of `components(separatedBy:"\n").dropFirst().joined(separator:"\n")`. The previous form allocated an `[Substring]` array and did a join; the new form slices directly, O(n) with no allocations.

**Summary:** 3 quality improvements, 0 tests changed, 271/271 tests passing.

---

## [4.6] — 2026-03-22

### Prompt caching + sentinel process monitoring + edit_file tool + security hardening + quality fixes

**[feature]** `CacheMode.swift`, `HTTPBackend.swift`, `OpenAITypes.swift` — end-to-end Anthropic prompt caching for the HTTP backend. System prompt and tool definitions are marked with `cache_control: {type: "ephemeral"}` when `cacheMode == .anthropic`, reducing API costs 50%+ on cache hits. Stable base prompt and dynamic memory section are split into two content blocks (base cached, memory uncached). Auto-detects Anthropic API from URL. `--cache-mode` CLI flag. OpenAI mode supported as a no-op for explicit configuration.

**[feature]** `TokenUsage` now carries `cacheReadTokens: Int?` and `cacheCreationTokens: Int?`. HTTP backend parses Anthropic's `cache_read_input_tokens` / `cache_creation_input_tokens` from SSE usage chunks. Cache stats displayed in REPL when non-nil. `SwiftClawConfig` gains `cacheMode: CacheMode` (default `.none`), backward-compatible.

**[feature]** `ProcessMonitor.swift`, `ProcessState.swift` — new actor in `SwiftClawCore` for launching and monitoring long-running child processes. Sentinel `__READY__` marker detection on stdout (configurable marker + timeout). Ring buffer (100 lines) per process. SIGTERM → 2s → SIGKILL stop sequence. `shutdown()` for session cleanup. All `Process` interaction isolated to `DispatchQueue.global().async` for Swift 6 concurrency safety.

**[feature]** `StartProcessTool`, `ProcessOutputTool`, `StopProcessTool`, `ListMonitoredProcessesTool` — four new tools in `SwiftClawTools` for LLM-driven process management. `start_process` and `stop_process` require confirmation. `SwiftClawToolFactory.processTools(monitor:)` factory method. Session wires `ProcessMonitor` lifecycle (auto-shutdown on `endSession()`). REPL `/processes`, `/processes show <id>`, `/processes stop <id>`.

**[feature]** `EditFileTool.swift`, `ToolFactory.swift` — new `edit_file` tool (12th built-in tool). Performs find-and-replace editing on sandboxed files: the agent supplies the exact current text to replace (`old_string`) and the replacement (`new_string`). Edit is rejected if `old_string` is not found (stale edit detection) or appears more than once (ambiguous). Prevents the common failure mode where the agent overwrites wrong content after the file changed since it last read it. Roadmap: hash-anchored edits (oh-my-openagent / P1).

**[security]** `FileSessionStore.swift` — session ID sanitization now uses a character whitelist (alphanumeric + hyphen, underscore, period) instead of a blocklist. Previously allowed newlines, spaces, shell metacharacters, and other special characters that could cause unexpected filesystem behavior. Three new tests validate: newline injection, space injection, and valid punctuation round-trip.

**[bug]** `MemoryConsolidator.swift` — markdown fence stripping now robustly extracts content between the opening ` ```[language]?\n ` and the last ` \n``` ` marker. The previous `dropLast()` approach would silently fail when the model added text after the closing fence, causing JSON decode to fail and the entire consolidation response to be dropped.

**[quality]** `MemoryStore.swift` — removed dead `removeEmbeddingTask(_:)` method. The self-removal pattern inside `scheduleEmbedding` handles task cleanup directly; this method was never called.

**[quality]** `RunCommand.swift` — replaced silent `try?` for `MemoryStore` initialization with `do-catch` that logs the error to stderr and re-throws. Previously, a failed memory store init silently continued with `agentMemory = nil` — `--memory` appeared to work but was a no-op.

**[test]** 21 new tests total: 12 covering prompt caching types, token usage backward compat, ProcessMonitor lifecycle, and process tool registration; 9 covering EditFileTool (5), FileSessionStore sanitization (3), and ToolFactory count/names (1). Total: 258 tests.

**Summary:** 5 features added, 1 security fix, 1 bug fix, 2 quality improvements, 258/258 tests passing.

---

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
