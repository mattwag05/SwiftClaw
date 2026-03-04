# SwiftClaw

A macOS-first, Swift-native AI agent framework with on-device MLX inference. Privacy-first, self-hosted, no cloud surface.

## Overview

SwiftClaw lets you build agentic applications in Swift that run fully on-device using Apple Silicon. It handles the agentic loop (prompt → LLM → tool calls → results → loop), exposes a clean protocol-based tool system, and talks to local MLX models via [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm).

**Philosophy (GrimClaw-aligned):** All model weights and agent state stay local by default. No vendor lock-in — agents are Swift code + config, not tied to a cloud SDK.

## Requirements

- macOS 15+
- Apple Silicon (M1 or later)
- Swift 6.2+
- [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) (pulled automatically via SPM)

## Quick Start

```bash
# Build
swift build

# Check system compatibility
swift run swiftclaw doctor

# List available tools
swift run swiftclaw tools

# Start interactive Sysop Agent session
swift run swiftclaw run
```

The first `run` downloads the default model (`mlx-community/Qwen3.5-9B-MLX-4bit`, ~5GB) from Hugging Face.

## Package Structure

```
SwiftClaw/
  Sources/
    SwiftClawCore/      # Agent runtime, session, tool protocol, model backend protocol
    SwiftClawMLX/       # Concrete MLX backend using mlx-swift-lm
    SwiftClawTools/     # Built-in tools (system info, disk, processes, shell)
    swiftclaw/          # CLI executable
  Tests/
    SwiftClawCoreTests/
    SwiftClawToolsTests/
```

### Libraries

| Target | Purpose |
|--------|---------|
| `SwiftClawCore` | Core types: `Agent`, `Session` actor, `SwiftClawTool` protocol, `ModelBackend` protocol, `JSONSchema` |
| `SwiftClawMLX` | `MLXBackend` — wraps mlx-swift-lm's `ModelContainer` |
| `SwiftClawTools` | Drop-in tools: `SystemInfoTool`, `DiskSpaceTool`, `ProcessListTool`, `ShellTool` |

## Defining an Agent

```swift
import SwiftClawCore
import SwiftClawMLX
import SwiftClawTools

let backend = try await loadMLXBackend(modelId: "mlx-community/Qwen3.5-9B-MLX-4bit")

let agent = Agent(configuration: AgentConfiguration(
    name: "MyAgent",
    systemPrompt: "You are a helpful macOS assistant.",
    tools: [SystemInfoTool(), DiskSpaceTool()],
    modelId: "mlx-community/Qwen3.5-9B-MLX-4bit"
))

let session = Session(agent: agent, backend: backend)
let events = await session.respond(to: "How much disk space do I have?")
for try await event in events {
    switch event {
    case let .textDelta(text): print(text, terminator: "")
    case .done: print()
    default: break
    }
}
```

## Writing a Custom Tool

```swift
import SwiftClawCore

struct GreetTool: SwiftClawTool {
    let name = "greet"
    let description = "Greet someone by name."
    let parameterSchema: JSONSchema = .object(
        properties: ["name": .string(description: "Name to greet")],
        required: ["name"]
    )

    func execute(arguments: String) async throws -> ToolResult {
        struct Args: Decodable { var name: String }
        let args = try JSONDecoder().decode(Args.self, from: Data(arguments.utf8))
        return .success("Hello, \(args.name)!")
    }
}
```

## Built-in Tools (Sysop Agent)

| Tool | Description |
|------|-------------|
| `system_info` | Hostname, CPU cores, memory, macOS version |
| `disk_space` | Total, used, and free disk space for any path |
| `process_list` | Running processes sorted by memory usage |
| `shell` | Sandboxed shell execution (allowlist-based) |

The `shell` tool runs through `ShellSandbox` which rejects pipes, redirects, command substitution, and disallowed commands.

## CLI Commands

| Command | Description |
|---------|-------------|
| `swiftclaw run [--model ID] [--max-tokens N]` | Interactive Sysop Agent REPL |
| `swiftclaw tools [--json]` | List registered tools |
| `swiftclaw doctor` | Check MLX availability and system compatibility |

## Architecture

- **`Session` is an actor** — owns the mutable conversation array; data-race-safe by default
- **`Agent` is a struct** — immutable config + tool registry; freely `Sendable`
- **`ModelBackend` is a protocol** — swap in an HTTP backend (e.g., pi-mono) without changing the agentic loop
- **Tool arguments are JSON strings** — avoids `Any` which isn't `Sendable`
- **Swift 6 strict concurrency** — no workarounds; compiles clean with zero warnings

## Running Tests

```bash
swift test
```

40 tests across `SwiftClawCoreTests` and `SwiftClawToolsTests`. Core tests use a `MockBackend` — no model download needed.

## Roadmap

- **v0.1.0-beta** (current): Core runtime, MLX backend, Sysop Agent CLI
- **v1**: iOS support, pi-mono adapter, persistent memory, local agent templates

## License

MIT
