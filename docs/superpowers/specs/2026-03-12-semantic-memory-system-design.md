# Semantic Memory System — Design Spec

**Date:** 2026-03-12
**Status:** Reviewed
**Scope:** Full memory redesign — two-layer architecture, SQLite+FTS5 storage, MLX embeddings, hybrid retrieval, memory tools

---

## Context

SwiftClaw has an `AgentMemory` actor that provides persistent key-value storage and a `MemoryConsolidator` that auto-extracts facts from conversation. However, the current system has three gaps:

1. **No agent control** — the model cannot explicitly read, write, search, or delete memories via tools
2. **No layer separation** — all memories are equal; no distinction between session-scoped working memory and cross-session long-term memory
3. **No selective retrieval** — `formatted()` dumps ALL memories into the system prompt regardless of relevance, causing unbounded context growth

This redesign addresses all three gaps with a unified semantic memory system.

---

## Architecture

### New SPM Target: `SwiftClawMemory`

**Dependencies:** GRDB ~> 7.0 (SQLite, Swift 6 concurrency support), SwiftClawCore (protocols), mlx-swift-lm (embedding model loading via `MLXLMCommon.ModelContainer`)

**Import graph:**
```
SwiftClawCore (defines MemoryProvider protocol, MemoryEntry, MemoryLayer)
    ↑
SwiftClawMemory (GRDB + MLX embeddings, implements MemoryProvider)
    ↑
swiftclaw CLI / SwiftClawApp (creates concrete MemoryStore, passes to Session)
```

Core stays Foundation-only. The GRDB and MLX embedding dependencies are isolated in `SwiftClawMemory`.

### Protocol: `MemoryProvider`

Defined in `SwiftClawCore`:

```swift
public protocol MemoryProvider: Actor {
    func get(_ key: String, layer: MemoryLayer?) async -> MemoryEntry?  // nil = search both layers, working first
    func set(_ key: String, entry: MemoryEntry, layer: MemoryLayer) async throws
    func delete(_ key: String, layer: MemoryLayer) async throws
    func search(query: String, layer: MemoryLayer?, topK: Int) async throws -> [ScoredMemory]
    func promote(keys: [String]) async throws  // moves from working → long-term; skips missing keys; overwrites existing long-term entries; deletes working copy
    func allEntries(layer: MemoryLayer?) async -> [MemoryEntry]
    func clearLayer(_ layer: MemoryLayer) async throws
}

public enum MemoryLayer: String, Codable, Sendable {
    case working    // session-scoped, cleared on session end
    case longTerm   // persists across sessions
}

public struct ScoredMemory: Sendable {
    public let entry: MemoryEntry
    public let score: Float  // 0.0–1.0, hybrid relevance
}
```

### Replacing `AgentMemory`

The existing `AgentMemory` actor is replaced by the `MemoryProvider` protocol. `Session` accepts `memory: (any MemoryProvider)?` instead of `memory: AgentMemory?`. The concrete `MemoryStore` actor in `SwiftClawMemory` implements `MemoryProvider`.

---

## SQLite Schema

**Database location:** `~/.swiftclaw/memory/memory.db`

```sql
CREATE TABLE memories (
    key TEXT NOT NULL,
    layer TEXT NOT NULL CHECK(layer IN ('working', 'longTerm')),
    content TEXT NOT NULL,
    source TEXT NOT NULL,         -- session ID, 'user', or 'consolidator'
    created_at REAL NOT NULL,     -- Unix timestamp
    updated_at REAL NOT NULL,
    access_count INTEGER DEFAULT 0,
    last_accessed_at REAL,
    embedding BLOB,               -- Float32 array, nullable until embedded
    PRIMARY KEY (key, layer)
);

CREATE VIRTUAL TABLE memories_fts USING fts5(
    key, content,
    content='memories',
    content_rowid='rowid'
);

-- FTS sync triggers
CREATE TRIGGER memories_ai AFTER INSERT ON memories BEGIN
    INSERT INTO memories_fts(rowid, key, content) VALUES (new.rowid, new.key, new.content);
END;

CREATE TRIGGER memories_ad AFTER DELETE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, key, content) VALUES ('delete', old.rowid, old.key, old.content);
END;

CREATE TRIGGER memories_au AFTER UPDATE OF key, content ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, key, content) VALUES ('delete', old.rowid, old.key, old.content);
    INSERT INTO memories_fts(rowid, key, content) VALUES (new.rowid, new.key, new.content);
END;
```

### Database Migrations

Use GRDB's `DatabaseMigrator` from the start for future-proof schema evolution:

```swift
var migrator = DatabaseMigrator()
migrator.registerMigration("v1-initial") { db in
    // CREATE TABLE memories, FTS5, triggers (as above)
}
// Future: migrator.registerMigration("v2-...") { db in ... }
try migrator.migrate(dbPool)
```

### MemoryEntry Updates

Add fields to `MemoryEntry`:
- `accessCount: Int` (default 0) — custom `Decodable` init with `decodeIfPresent` defaulting to 0 for backward compat with legacy JSON
- `lastAccessedAt: Date?` (default nil) — already optional, `Codable` synthesis handles missing keys

Existing fields (`key`, `content`, `updatedAt`, `source`) remain unchanged.

### Migration from JSON

On first launch, `MemoryStore` checks for `~/.swiftclaw/memory/*.json` files:
1. Reads each namespace JSON file
2. Imports all entries as `layer: .longTerm`
3. Embeds content via `EmbeddingEngine`
4. Renames JSON files to `.json.migrated`

---

## Embedding Engine

### `EmbeddingEngine` Actor

Located in `SwiftClawMemory`. Wraps an MLX embedding model.

**Model:** `nomic-ai/nomic-embed-text-v1.5` (137M params, 768-dim vectors, ~270MB quantized)
**Cache:** `~/Library/Caches/models/nomic-ai/nomic-embed-text-v1.5-MLX` (standard HuggingFace cache path)

**Interface:**
```swift
public actor EmbeddingEngine {
    public init(modelId: String = "nomic-ai/nomic-embed-text-v1.5-MLX")
    public func embed(_ text: String) async throws -> [Float]
    public func embed(texts: [String]) async throws -> [[Float]]
}
```

**Behavior:**
- **Lazy loading:** Model loads on first `embed()` call, not at app startup
- **Batch support:** `embed(texts:)` for bulk operations (migration, consolidation)
- Uses mlx-swift-lm's `ModelContainer` for model loading (same pattern as `MLXBackend`)

### Cosine Similarity

Computed via Accelerate/vDSP for SIMD performance:

```swift
import Accelerate

func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    var dot: Float = 0, normA: Float = 0, normB: Float = 0
    vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
    vDSP_svesq(a, 1, &normA, vDSP_Length(a.count))
    vDSP_svesq(b, 1, &normB, vDSP_Length(b.count))
    guard normA > 0, normB > 0 else { return 0 }
    return dot / (sqrt(normA) * sqrt(normB))
}
```

### Embedding Lifecycle

1. `MemoryStore.set()` stores the entry immediately with `embedding = nil`
2. A background `Task` calls `EmbeddingEngine.embed()` and updates the row
3. `search()` works without embeddings — falls back to FTS5-only scoring

**Task cancellation:** `MemoryStore` maintains a `Set<Task<Void, Never>>` of in-flight embedding tasks. Tasks self-remove on completion via `defer`. `MemoryStore.shutdown()` cancels all pending tasks — called by `Session` on end, and by CLI/app on exit.

---

## Hybrid Retrieval

### `MemoryRetriever` Struct

Located in `SwiftClawMemory`. Orchestrates search across FTS5 and vector similarity.

**`search(query:layer:topK:) -> [ScoredMemory]`:**

1. **FTS5 keyword search** — query `memories_fts`, get BM25 scores (SQLite built-in `rank`)
2. **Vector similarity** — embed query via `EmbeddingEngine`, compute cosine similarity against stored embeddings
3. **Hybrid scoring:**
   ```
   score = (semantic_similarity * 0.50)
         + (bm25_normalized    * 0.25)
         + (recency_score      * 0.15)
         + (access_frequency   * 0.10)
   ```
   - `recency_score = 1.0 / (1.0 + days_since_update)`
   - `access_frequency = min(1.0, access_count / 10.0)`
   - BM25 normalized via `log(1 + abs(bm25)) / log(1 + max_expected_bm25)` capped at 1.0 (log-dampened, stable across result sets)
4. **Return top-K** sorted by score descending

**Graceful degradation:** If no embeddings are stored (embedding model not downloaded, or entries pending embedding), returns FTS5-only results with `semantic_similarity = 0`.

### System Prompt Injection

Replaces `memory.formatted()` in `Session.runLoop`:

```
## Relevant Memories
- user_preference_timezone: User prefers UTC display (score: 0.92)
- project_deadline: SwiftClaw v1 deadline is April 15 (score: 0.87)
- ...
```

Retrieved via `retriever.search(query: lastUserMessage, topK: 10)`. Only memories scoring above a configurable threshold (default 0.3) are injected.

---

## Memory Tools

Four tools conforming to `SwiftClawTool`, registered via `MemoryToolFactory.allTools(store:)`:

| Tool | Description | Arguments |
|------|-------------|-----------|
| `memory_write` | Store a fact for future recall | `key: String`, `content: String`, `layer: String` (default: "working") |
| `memory_read` | Read a specific memory by key | `key: String`, `layer: String?` (searches both if omitted) |
| `memory_search` | Semantic + keyword search across memories | `query: String`, `topK: Int` (default: 5), `layer: String?` |
| `memory_delete` | Remove a memory | `key: String`, `layer: String` |

**Registration pattern:** Follows `PippinToolFactory` (caseless enum for namespace):
```swift
public enum MemoryToolFactory {
    public static func allTools(store: any MemoryProvider) -> [any SwiftClawTool]
}
```

Called in `RunCommand` and `ChatViewModel` alongside existing tool factories.

---

## Two-Layer Memory Lifecycle

### Working Memory (Session-Scoped)

- **Auto-populated:** `MemoryConsolidator` writes to `layer: .working` every N turns (existing post-turn consolidation behavior, now targeting working layer)
- **Explicit writes:** Model calls `memory_write` tool (defaults to working layer)
- **Cleared:** On session end, after promotion pass

### Long-Term Memory (Persistent)

- **Auto-promoted:** At session end, consolidator runs a final pass on working memories, promotes important ones to long-term via `promote(keys:)`
- **Explicit writes:** Model calls `memory_write(layer: "longTerm")`
- **Never auto-deleted**

### Session Lifecycle Hooks

1. **Session start** → Retrieve relevant long-term memories via `MemoryRetriever`, inject into first system prompt
2. **Each turn** → Re-retrieve based on latest user message (new search, updated top-K)
3. **Session end** → Run consolidation on working layer → promote important facts to long-term → clear working layer

### REPL Commands

- `/memory` — show all memories (both layers) with layer labels
- `/memory search <query>` — semantic search across both layers
- `/memory clear working` — clear working layer
- `/memory clear all` — clear both layers (prompts for confirmation before clearing long-term)

---

## Configuration

New fields in `SwiftClawConfig` (`~/.swiftclaw/config.json`):

```json
{
    "memoryEnabled": true,
    "embeddingModelId": "nomic-ai/nomic-embed-text-v1.5-MLX",
    "embeddingDimensions": 768,
    "retrievalTopK": 10,
    "retrievalThreshold": 0.3,
    "consolidationInterval": 3,
    "compressionTokenThreshold": 4000
}
```

Existing `memoryEnabled` and `consolidationInterval` fields are preserved (moved from `SessionConfiguration` to `SwiftClawConfig`; `SessionConfiguration` retains `memoryEnabled` and `consolidationInterval` for backward compat but defers to `SwiftClawConfig` values). New fields have sensible defaults.

---

## Error Handling

New error cases in `SwiftClawError`:
- `.embeddingModelNotFound(String)` — embedding model not cached locally
- `.embeddingFailed(String)` — MLX embedding inference error
- `.memoryDatabaseError(String)` — GRDB/SQLite error wrapper

Embedding failures are non-fatal — `MemoryStore` logs a warning and falls back to FTS5-only retrieval.

---

## Testing Strategy

### Unit Tests (SwiftClawMemoryTests)

1. **MemoryStore CRUD** — write/read/delete across both layers, verify SQLite persistence
2. **FTS5 search** — keyword matching accuracy, BM25 scoring
3. **Migration** — JSON → SQLite migration with correct layer assignment
4. **EmbeddingEngine** — mock with fixed vectors, verify cosine similarity math
5. **MemoryRetriever** — hybrid scoring with known vectors/BM25 scores, verify ranking
6. **Memory tools** — each tool's execute method with valid/invalid arguments

### Integration Tests

7. **Session + MemoryProvider** — verify memory injection into system prompt, consolidation writes, promotion at session end
8. **End-to-end with mock backend** — run a multi-turn conversation, verify memories accumulate and retrieve correctly
9. **Graceful degradation** — verify `search()` returns valid FTS5-only results when all `embedding` columns are NULL (embedding model unavailable)
10. **Existing test updates** — update `MemoryConsolidatorTests` and `MemoryEntryTests` to use `MemoryProvider` protocol (mock or in-memory `MemoryStore` with temp dir) instead of removed `AgentMemory`

### Test Isolation

- `MemoryStore(baseDir:)` accepts a temp directory for test isolation (same pattern as `FileSessionStore(baseDir:)`)
- `EmbeddingEngine` mockable via protocol extraction if needed; alternatively, test with pre-computed embeddings stored as fixtures

---

## Files to Create

| File | Target | Description |
|------|--------|-------------|
| `Sources/SwiftClawCore/Memory/MemoryProvider.swift` | Core | Protocol + `MemoryLayer` + `ScoredMemory` |
| `Sources/SwiftClawMemory/MemoryStore.swift` | Memory | SQLite-backed actor implementing `MemoryProvider` |
| `Sources/SwiftClawMemory/EmbeddingEngine.swift` | Memory | MLX embedding model wrapper |
| `Sources/SwiftClawMemory/MemoryRetriever.swift` | Memory | Hybrid FTS5 + vector search |
| `Sources/SwiftClawMemory/Tools/MemoryWriteTool.swift` | Memory | `memory_write` tool |
| `Sources/SwiftClawMemory/Tools/MemoryReadTool.swift` | Memory | `memory_read` tool |
| `Sources/SwiftClawMemory/Tools/MemorySearchTool.swift` | Memory | `memory_search` tool |
| `Sources/SwiftClawMemory/Tools/MemoryDeleteTool.swift` | Memory | `memory_delete` tool |
| `Sources/SwiftClawMemory/MemoryToolFactory.swift` | Memory | Tool registration factory |
| `Tests/SwiftClawMemoryTests/MemoryStoreTests.swift` | Tests | CRUD, FTS5, migration |
| `Tests/SwiftClawMemoryTests/MemoryRetrieverTests.swift` | Tests | Hybrid scoring |
| `Tests/SwiftClawMemoryTests/MemoryToolTests.swift` | Tests | Tool execution |

## Files to Modify

| File | Change |
|------|--------|
| `Package.swift` | Add GRDB ~> 7.0 dependency, new `SwiftClawMemory` target (deps: GRDB, SwiftClawCore, MLXLMCommon), `SwiftClawMemoryTests` target; add `SwiftClawMemory` to `swiftclaw` CLI and `SwiftClawApp` target dependencies |
| `Sources/SwiftClawCore/Memory/MemoryEntry.swift` | Add `accessCount`, `lastAccessedAt` fields |
| `Sources/SwiftClawCore/Session/Session.swift` | Change `memory: AgentMemory?` → `memory: (any MemoryProvider)?`, update retrieval calls, add session end promotion |
| `Sources/SwiftClawCore/Memory/MemoryConsolidator.swift` | Accept `any MemoryProvider` instead of `AgentMemory`, write to `.working` layer |
| `Sources/swiftclaw/RunCommand.swift` | Create `MemoryStore` instead of `AgentMemory`, register memory tools, update REPL commands |
| `Sources/SwiftClawApp/ChatViewModel.swift` | Create `MemoryStore` instead of `AgentMemory`, register memory tools |
| `Sources/SwiftClawCore/Store/AgentMemory.swift` | Remove (replaced by `MemoryProvider` protocol + `MemoryStore`) |

---

## Verification

1. `swift build` — all targets compile with zero errors
2. `swift test` — all existing 175 tests pass + new `SwiftClawMemoryTests` pass
3. `.build/release/swiftclaw run --memory` — verify:
   - Memories auto-consolidate after 3 turns
   - `/memory` shows working + long-term entries
   - `/memory search <query>` returns ranked results
   - Model can call `memory_write`, `memory_read`, `memory_search`, `memory_delete`
4. Session resume: start with `--session test`, build memories, quit, resume — long-term memories persist
5. Migration: place a legacy `~/.swiftclaw/memory/default.json`, launch → verify imported as long-term entries
