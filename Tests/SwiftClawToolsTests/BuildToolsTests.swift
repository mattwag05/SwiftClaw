import Testing
import Foundation
@testable import SwiftClawTools
@testable import SwiftClawCore

@Suite("Build Tools", .serialized)
struct BuildToolsTests {

    private func makeWorkspace() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("sc-build-tools-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - BuildWriteFileTool

    @Test("write creates a new file in workspace")
    func writeCreatesFile() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }

        let tool = BuildWriteFileTool(workspaceURL: ws)
        let args = #"{"path":"hello.txt","content":"Hello World"}"#
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)

        let content = try String(contentsOf: ws.appendingPathComponent("hello.txt"))
        #expect(content == "Hello World")
    }

    @Test("write strips markdown fence for html files")
    func writeStripsHtmlFence() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }

        let tool = BuildWriteFileTool(workspaceURL: ws)
        let fenced = "```\n<html><body>hi</body></html>\n```"
        let args = "{\"path\":\"index.html\",\"content\":\"\(fenced.replacingOccurrences(of: "\n", with: "\\n"))\"}"
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)

        let content = try String(contentsOf: ws.appendingPathComponent("index.html"))
        #expect(!content.hasPrefix("```"))
    }

    @Test("write outside workspace is rejected")
    func writeOutsideWorkspace() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }

        let tool = BuildWriteFileTool(workspaceURL: ws)
        let args = #"{"path":"../../etc/passwd","content":"x"}"#
        let result = try await tool.execute(arguments: args)
        #expect(result.isError)
    }

    @Test("write emits fileStreaming and fileWritten events")
    func writeEmitsEvents() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }

        nonisolated(unsafe) var events: [SessionEvent] = []
        let tool = BuildWriteFileTool(workspaceURL: ws, eventSink: { events.append($0) })
        let args = #"{"path":"test.txt","content":"data"}"#
        _ = try await tool.execute(arguments: args)

        #expect(events.contains { if case .fileStreaming = $0 { true } else { false } })
        #expect(events.contains { if case .fileWritten = $0 { true } else { false } })
    }

    // MARK: - BuildReadFileTool

    @Test("read returns file content")
    func readReturnsContent() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }
        try "Swift is great".write(to: ws.appendingPathComponent("code.swift"), atomically: true, encoding: .utf8)

        let tool = BuildReadFileTool(workspaceURL: ws)
        let result = try await tool.execute(arguments: #"{"path":"code.swift"}"#)
        #expect(!result.isError)
        #expect(result.content.contains("Swift is great"))
    }

    @Test("read missing file returns error")
    func readMissingFile() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }

        let tool = BuildReadFileTool(workspaceURL: ws)
        let result = try await tool.execute(arguments: #"{"path":"missing.txt"}"#)
        #expect(result.isError)
    }

    @Test("read outside workspace is rejected")
    func readOutsideWorkspace() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }

        let tool = BuildReadFileTool(workspaceURL: ws)
        let result = try await tool.execute(arguments: #"{"path":"../../etc/hosts"}"#)
        #expect(result.isError)
    }

    // MARK: - BuildEditFileTool

    @Test("edit replaces string in file")
    func editReplacesString() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }
        let file = ws.appendingPathComponent("greet.txt")
        try "Hello World".write(to: file, atomically: true, encoding: .utf8)

        let tool = BuildEditFileTool(workspaceURL: ws)
        let args = #"{"path":"greet.txt","old_string":"World","new_string":"Swift"}"#
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        let content = try String(contentsOf: file)
        #expect(content == "Hello Swift")
    }

    @Test("edit with replace_all replaces all occurrences")
    func editReplaceAll() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }
        let file = ws.appendingPathComponent("rep.txt")
        try "aXaXa".write(to: file, atomically: true, encoding: .utf8)

        let tool = BuildEditFileTool(workspaceURL: ws)
        let args = #"{"path":"rep.txt","old_string":"X","new_string":"_","replace_all":true}"#
        _ = try await tool.execute(arguments: args)
        let content = try String(contentsOf: file)
        #expect(content == "a_a_a")
    }

    @Test("edit missing old_string returns error")
    func editMissingOldString() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }
        try "hello".write(to: ws.appendingPathComponent("f.txt"), atomically: true, encoding: .utf8)

        let tool = BuildEditFileTool(workspaceURL: ws)
        let args = #"{"path":"f.txt","old_string":"not_there","new_string":"x"}"#
        let result = try await tool.execute(arguments: args)
        #expect(result.isError)
    }

    // MARK: - BuildListFilesTool

    @Test("list returns files in workspace")
    func listFilesInWorkspace() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }
        try "a".write(to: ws.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "b".write(to: ws.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)

        let tool = BuildListFilesTool(workspaceURL: ws)
        let result = try await tool.execute(arguments: "{}")
        #expect(!result.isError)
        #expect(result.content.contains("a.txt"))
        #expect(result.content.contains("b.txt"))
    }

    @Test("list skips node_modules")
    func listSkipsNodeModules() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }
        let nm = ws.appendingPathComponent("node_modules")
        try FileManager.default.createDirectory(at: nm, withIntermediateDirectories: true)
        try "x".write(to: nm.appendingPathComponent("pkg.js"), atomically: true, encoding: .utf8)

        let tool = BuildListFilesTool(workspaceURL: ws)
        let result = try await tool.execute(arguments: "{}")
        #expect(!result.content.contains("node_modules"))
    }

    // MARK: - BuildDeleteFileTool

    @Test("delete removes an existing file")
    func deleteRemovesFile() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }
        let file = ws.appendingPathComponent("del.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)

        let tool = BuildDeleteFileTool(workspaceURL: ws)
        let result = try await tool.execute(arguments: #"{"path":"del.txt"}"#)
        #expect(!result.isError)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("delete missing file returns error")
    func deleteMissingFile() async throws {
        let ws = try makeWorkspace()
        defer { cleanup(ws) }

        let tool = BuildDeleteFileTool(workspaceURL: ws)
        let result = try await tool.execute(arguments: #"{"path":"ghost.txt"}"#)
        #expect(result.isError)
    }
}

// MARK: - CalcTool tests

@Suite("CalcTool")
struct CalcToolTests {
    private let tool = CalcTool()

    @Test("basic addition")
    func addition() async throws {
        let r = try await tool.execute(arguments: #"{"expression":"2+3"}"#)
        #expect(r.content == "5")
    }

    @Test("multiplication")
    func multiplication() async throws {
        let r = try await tool.execute(arguments: #"{"expression":"4*7"}"#)
        #expect(r.content == "28")
    }

    @Test("power operator")
    func power() async throws {
        let r = try await tool.execute(arguments: #"{"expression":"2**10"}"#)
        #expect(r.content == "1024")
    }

    @Test("parentheses")
    func parentheses() async throws {
        let r = try await tool.execute(arguments: #"{"expression":"(2+3)*4"}"#)
        #expect(r.content == "20")
    }

    @Test("unary minus")
    func unaryMinus() async throws {
        let r = try await tool.execute(arguments: #"{"expression":"-5+10"}"#)
        #expect(r.content == "5")
    }

    @Test("sqrt function")
    func sqrtFunction() async throws {
        let r = try await tool.execute(arguments: #"{"expression":"sqrt(144)"}"#)
        #expect(r.content == "12")
    }

    @Test("division by zero returns error")
    func divisionByZero() async throws {
        let r = try await tool.execute(arguments: #"{"expression":"1/0"}"#)
        #expect(r.isError)
    }

    @Test("unknown function returns error")
    func unknownFunction() async throws {
        let r = try await tool.execute(arguments: #"{"expression":"magic(5)"}"#)
        #expect(r.isError)
    }

    @Test("floating point result")
    func floatingPoint() async throws {
        let r = try await tool.execute(arguments: #"{"expression":"1/3"}"#)
        #expect(r.content.hasPrefix("0.333"))
    }
}
