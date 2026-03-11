---
name: swiftclaw-new-tool
description: Scaffold a new SwiftClawTool with correct protocol conformance, Arguments struct, and ToolFactory registration. Use when adding a new tool to SwiftClawTools or SwiftClawPippin.
disable-model-invocation: true
---

Scaffold a new SwiftClaw tool. Ask the user for:
- Tool name (e.g. `weather`, `note_search`)
- Target: `SwiftClawTools` or `SwiftClawPippin`
- What it does (one sentence)
- Parameters it needs (names, types, required vs optional)

Then create the tool file following these patterns exactly.

## File location

- `Sources/SwiftClawTools/<ToolName>Tool.swift` for SwiftClawTools
- `Sources/SwiftClawPippin/<ToolName>Tool.swift` for SwiftClawPippin

## Required pattern

```swift
import Foundation
import SwiftClawCore

struct <ToolName>Tool: SwiftClawTool {
    static let toolName = "<snake_case_name>"

    struct Arguments: Decodable {
        // For any Int? field that Qwen3.5 may pass as a numeric string:
        let count: Int?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // Accept both Int and String-encoded Int (Qwen3.5 passes all params as strings)
            if let intVal = try? c.decode(Int.self, forKey: .count) {
                count = intVal
            } else if let strVal = try? c.decode(String.self, forKey: .count),
                      let parsed = Int(strVal) {
                count = parsed
            } else {
                count = nil
            }
        }

        enum CodingKeys: String, CodingKey { case count }
    }

    var definition: ToolDefinition {
        ToolDefinition(
            name: Self.toolName,
            description: "<description>",
            parameters: JSONSchema(
                type: "object",
                properties: [
                    "count": JSONSchema(type: "integer", description: "...")
                ],
                required: []
            )
        )
    }

    func execute(argumentsJSON: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(argumentsJSON.utf8))
        // ... implementation ...
        return ToolResult(content: "result")
    }
}
```

## Important gotchas

- All `Int?` fields need the custom `Decodable` init above — Qwen3.5 sends all params as strings
- String? fields can use standard `decode` — no custom init needed
- Use `nonisolated(unsafe)` if you need a var captured by a `DispatchQueue.global().async` closure
- If using `FileManager.DirectoryEnumerator` in async context, use `.allObjects` not `for ... in`

## Registration

After creating the file, add it to the factory:

- For SwiftClawTools: add `<ToolName>Tool()` to the array in `Sources/SwiftClawTools/ToolFactory.swift`
- For SwiftClawPippin: add `<ToolName>Tool()` to `Sources/SwiftClawPippin/PippinToolFactory.swift`

## Test file

Create `Tests/SwiftClawToolsTests/<ToolName>ToolTests.swift` (or `SwiftClawPippinTests/`) with at least:
- A test for normal execution
- A test that passes count/int params as strings (to verify the custom Decodable)
