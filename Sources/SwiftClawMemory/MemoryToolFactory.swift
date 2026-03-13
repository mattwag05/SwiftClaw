import Foundation
import SwiftClawCore

/// Factory that creates all memory-related tools backed by a given MemoryProvider.
public enum MemoryToolFactory {
    public static func allTools(store: any MemoryProvider) -> [any SwiftClawTool] {
        return [
            MemoryWriteTool(store: store),
            MemoryReadTool(store: store),
            MemorySearchTool(store: store),
            MemoryDeleteTool(store: store),
        ]
    }
}
