import Foundation
import Testing
@testable import SwiftClawTools
@testable import SwiftClawCore

@Suite("File Tools Tests")
struct FileToolsTests {
    let tmpDir = FileManager.default.temporaryDirectory.path

    // MARK: - ReadFileTool

    @Test("read_file has correct name")
    func readFileToolName() {
        let tool = ReadFileTool(sandbox: FileSandbox(allowedPaths: ["/tmp"]))
        #expect(tool.name == "read_file")
    }

    @Test("read_file reads an existing file")
    func readFileToolReadsFile() async throws {
        let path = "\(tmpDir)/swiftclaw-test-\(UUID().uuidString).txt"
        let content = "Hello\nLine2\nLine3"
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = ReadFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let result = try await tool.execute(arguments: "{\"path\":\"\(path)\"}")
        #expect(!result.isError)
        #expect(result.content.contains("Hello"))
        #expect(result.content.contains("Line2"))
    }

    @Test("read_file applies offset and limit")
    func readFileToolOffsetLimit() async throws {
        let path = "\(tmpDir)/swiftclaw-offset-\(UUID().uuidString).txt"
        let content = (1...10).map { "line\($0)" }.joined(separator: "\n")
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = ReadFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let result = try await tool.execute(
            arguments: "{\"path\":\"\(path)\",\"offset\":3,\"limit\":2}")
        #expect(!result.isError)
        #expect(result.content.contains("line3"))
        #expect(result.content.contains("line4"))
        #expect(!result.content.contains("line5"))
    }

    @Test("read_file rejects path outside sandbox")
    func readFileToolRejectsSandbox() async throws {
        let tool = ReadFileTool(sandbox: FileSandbox(allowedPaths: ["/tmp"]))
        let result = try await tool.execute(arguments: "{\"path\":\"/etc/passwd\"}")
        #expect(result.isError)
    }

    @Test("read_file returns error for missing file")
    func readFileToolMissingFile() async throws {
        let tool = ReadFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let result = try await tool.execute(
            arguments: "{\"path\":\"\(tmpDir)/nonexistent-\(UUID().uuidString).txt\"}")
        #expect(result.isError)
    }

    // MARK: - WriteFileTool

    @Test("write_file has correct name")
    func writeFileToolName() {
        let tool = WriteFileTool(sandbox: FileSandbox(allowedPaths: ["/tmp"]))
        #expect(tool.name == "write_file")
    }

    @Test("write_file writes content to a file")
    func writeFileToolWrites() async throws {
        let path = "\(tmpDir)/swiftclaw-write-\(UUID().uuidString).txt"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = WriteFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let args = "{\"path\":\"\(path)\",\"content\":\"test content\"}"
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.content.contains("bytes"))

        let written = try String(contentsOfFile: path, encoding: .utf8)
        #expect(written == "test content")
    }

    @Test("write_file rejects path outside sandbox")
    func writeFileToolRejectsSandbox() async throws {
        let tool = WriteFileTool(sandbox: FileSandbox(allowedPaths: ["/tmp"]))
        let result = try await tool.execute(
            arguments: "{\"path\":\"/etc/test.txt\",\"content\":\"x\"}")
        #expect(result.isError)
    }

    // MARK: - ListDirectoryTool

    @Test("list_directory has correct name")
    func listDirectoryToolName() {
        let tool = ListDirectoryTool(sandbox: FileSandbox(allowedPaths: ["/tmp"]))
        #expect(tool.name == "list_directory")
    }

    @Test("list_directory lists /tmp")
    func listDirectoryToolListsTmp() async throws {
        let tool = ListDirectoryTool(sandbox: FileSandbox(allowedPaths: ["/tmp"]))
        let result = try await tool.execute(arguments: "{\"path\":\"/tmp\"}")
        #expect(!result.isError)
        #expect(result.content.contains("/tmp/"))
    }

    @Test("list_directory rejects path outside sandbox")
    func listDirectoryToolRejectsSandbox() async throws {
        let tool = ListDirectoryTool(sandbox: FileSandbox(allowedPaths: ["/tmp"]))
        let result = try await tool.execute(arguments: "{\"path\":\"/etc\"}")
        #expect(result.isError)
    }

    @Test("list_directory returns error for file path")
    func listDirectoryToolRejectsFile() async throws {
        let path = "\(tmpDir)/swiftclaw-dir-test-\(UUID().uuidString).txt"
        try "x".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = ListDirectoryTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let result = try await tool.execute(arguments: "{\"path\":\"\(path)\"}")
        #expect(result.isError)
    }

    // MARK: - FindFilesTool

    @Test("find_files has correct name")
    func findFilesToolName() {
        let tool = FindFilesTool(sandbox: FileSandbox(allowedPaths: ["/tmp"]))
        #expect(tool.name == "find_files")
    }

    @Test("find_files finds matching files")
    func findFilesToolFindsFiles() async throws {
        let dir = "\(tmpDir)/swiftclaw-find-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        try "a".write(toFile: "\(dir)/foo.swift", atomically: true, encoding: .utf8)
        try "b".write(toFile: "\(dir)/bar.txt", atomically: true, encoding: .utf8)

        let tool = FindFilesTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let args = "{\"pattern\":\"*.swift\",\"path\":\"\(dir)\"}"
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.content.contains("foo.swift"))
        #expect(!result.content.contains("bar.txt"))
    }

    @Test("find_files returns message when nothing found")
    func findFilesToolNothingFound() async throws {
        let tool = FindFilesTool(sandbox: FileSandbox(allowedPaths: ["/tmp"]))
        let result = try await tool.execute(
            arguments: "{\"pattern\":\"*.zzznomatch\",\"path\":\"/tmp\"}")
        #expect(!result.isError)
        #expect(result.content.contains("No files found"))
    }

    // MARK: - EditFileTool

    @Test("edit_file has correct name")
    func editFileToolName() {
        let tool = EditFileTool(sandbox: FileSandbox(allowedPaths: ["/tmp"]))
        #expect(tool.name == "edit_file")
    }

    @Test("edit_file replaces unique string")
    func editFileToolReplacesString() async throws {
        let path = "\(tmpDir)/swiftclaw-edit-\(UUID().uuidString).txt"
        let original = "line one\nline two\nline three"
        try original.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = EditFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let args = """
            {"path":"\(path)","old_string":"line two","new_string":"REPLACED"}
            """
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)

        let updated = try String(contentsOfFile: path, encoding: .utf8)
        #expect(updated == "line one\nREPLACED\nline three")
    }

    @Test("edit_file fails when old_string not found")
    func editFileToolNotFound() async throws {
        let path = "\(tmpDir)/swiftclaw-edit-nf-\(UUID().uuidString).txt"
        try "hello world".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = EditFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let args = """
            {"path":"\(path)","old_string":"nonexistent","new_string":"x"}
            """
        let result = try await tool.execute(arguments: args)
        #expect(result.isError)
        #expect(result.content.contains("not found"))
    }

    @Test("edit_file fails when old_string is ambiguous")
    func editFileToolAmbiguous() async throws {
        let path = "\(tmpDir)/swiftclaw-edit-amb-\(UUID().uuidString).txt"
        try "foo\nfoo\nbar".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = EditFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let args = """
            {"path":"\(path)","old_string":"foo","new_string":"baz"}
            """
        let result = try await tool.execute(arguments: args)
        #expect(result.isError)
        #expect(result.content.contains("more than once"))
    }

    @Test("edit_file rejects empty old_string")
    func editFileToolRejectsEmptyOldString() async throws {
        let path = "\(tmpDir)/swiftclaw-edit-empty-\(UUID().uuidString).txt"
        try "hello".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = EditFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let args = """
            {"path":"\(path)","old_string":"","new_string":"x"}
            """
        let result = try await tool.execute(arguments: args)
        #expect(result.isError)
    }

    @Test("edit_file rejects path outside sandbox")
    func editFileToolRejectsSandbox() async throws {
        let tool = EditFileTool(sandbox: FileSandbox(allowedPaths: ["/tmp"]))
        let result = try await tool.execute(
            arguments: "{\"path\":\"/etc/passwd\",\"old_string\":\"root\",\"new_string\":\"x\"}")
        #expect(result.isError)
    }
}
