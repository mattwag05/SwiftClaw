import Foundation
@testable import SwiftClawCore
@testable import SwiftClawTools
import Testing

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
        let content = (1 ... 10).map { "line\($0)" }.joined(separator: "\n")
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = ReadFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let result = try await tool.execute(
            arguments: "{\"path\":\"\(path)\",\"offset\":3,\"limit\":2}"
        )
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
            arguments: "{\"path\":\"\(tmpDir)/nonexistent-\(UUID().uuidString).txt\"}"
        )
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
            arguments: "{\"path\":\"/etc/test.txt\",\"content\":\"x\"}"
        )
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
            arguments: "{\"pattern\":\"*.zzznomatch\",\"path\":\"/tmp\"}"
        )
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
            arguments: "{\"path\":\"/etc/passwd\",\"old_string\":\"root\",\"new_string\":\"x\"}"
        )
        #expect(result.isError)
    }

    // MARK: - LineHashing

    @Test("LineHashing.hash is stable and 8 hex chars")
    func lineHashingIsStable() {
        let h = LineHashing.hash("hello")
        #expect(h.count == 8)
        #expect(h == LineHashing.hash("hello"))
        #expect(h != LineHashing.hash("hello "))
        #expect(h.allSatisfy { "0123456789abcdef".contains($0) })
    }

    // MARK: - read_file line hashes

    @Test("read_file omits hashes by default")
    func readFileNoHashesByDefault() async throws {
        let path = "\(tmpDir)/swiftclaw-nohash-\(UUID().uuidString).txt"
        try "alpha\nbeta\ngamma".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = ReadFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let result = try await tool.execute(arguments: "{\"path\":\"\(path)\"}")
        #expect(!result.isError)
        #expect(result.content.contains("alpha"))
        #expect(!result.content.contains(" | alpha"))
    }

    @Test("read_file emits line hashes when requested")
    func readFileEmitsLineHashes() async throws {
        let path = "\(tmpDir)/swiftclaw-hash-\(UUID().uuidString).txt"
        try "alpha\nbeta".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = ReadFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let result = try await tool.execute(
            arguments: "{\"path\":\"\(path)\",\"include_hashes\":true}"
        )
        #expect(!result.isError)
        let alphaHash = LineHashing.hash("alpha")
        let betaHash = LineHashing.hash("beta")
        #expect(result.content.contains("\(alphaHash) | alpha"))
        #expect(result.content.contains("\(betaHash) | beta"))
    }

    @Test("read_file rejects invalid include_hashes string")
    func readFileRejectsInvalidIncludeHashesString() async throws {
        let path = "\(tmpDir)/swiftclaw-bad-hash-flag-\(UUID().uuidString).txt"
        try "alpha".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = ReadFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        await #expect(throws: DecodingError.self) {
            _ = try await tool.execute(arguments: "{\"path\":\"\(path)\",\"include_hashes\":\"foo\"}")
        }
    }

    // MARK: - edit_file anchor

    @Test("edit_file succeeds when anchor matches")
    func editFileAnchorMatches() async throws {
        let path = "\(tmpDir)/swiftclaw-anchor-ok-\(UUID().uuidString).txt"
        let original = "line one\nline two\nline three"
        try original.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let anchorHash = LineHashing.hash("line two")
        let tool = EditFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let args = """
        {"path":"\(path)","old_string":"line two","new_string":"REPLACED","anchor_line":2,"anchor_hash":"\(anchorHash)"}
        """
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        let updated = try String(contentsOfFile: path, encoding: .utf8)
        #expect(updated == "line one\nREPLACED\nline three")
    }

    @Test("edit_file anchor can point at a different line than the edit")
    func editFileAnchorOnDifferentLine() async throws {
        let path = "\(tmpDir)/swiftclaw-anchor-far-\(UUID().uuidString).txt"
        let original = "func foo() {\n    return 1\n}"
        try original.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let anchorHash = LineHashing.hash("func foo() {")
        let tool = EditFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let args = """
        {"path":"\(path)","old_string":"return 1","new_string":"return 42","anchor_line":1,"anchor_hash":"\(anchorHash)"}
        """
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
    }

    @Test("edit_file rejects stale anchor")
    func editFileStaleAnchor() async throws {
        let path = "\(tmpDir)/swiftclaw-anchor-stale-\(UUID().uuidString).txt"
        try "line one\nline two\nline three".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let bogusHash = "deadbeef"
        let tool = EditFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let args = """
        {"path":"\(path)","old_string":"line two","new_string":"x","anchor_line":2,"anchor_hash":"\(bogusHash)"}
        """
        let result = try await tool.execute(arguments: args)
        #expect(result.isError)
        #expect(result.content.contains("has changed"))
        #expect(result.content.contains("line 2"))
        #expect(result.content.contains(bogusHash))
        // File must be unchanged
        let after = try String(contentsOfFile: path, encoding: .utf8)
        #expect(after == "line one\nline two\nline three")
    }

    @Test("edit_file rejects partial anchor (line only)")
    func editFilePartialAnchorLineOnly() async throws {
        let path = "\(tmpDir)/swiftclaw-anchor-partial1-\(UUID().uuidString).txt"
        try "foo".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = EditFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let args = """
        {"path":"\(path)","old_string":"foo","new_string":"bar","anchor_line":1}
        """
        let result = try await tool.execute(arguments: args)
        #expect(result.isError)
        #expect(result.content.contains("together"))
    }

    @Test("edit_file rejects partial anchor (hash only)")
    func editFilePartialAnchorHashOnly() async throws {
        let path = "\(tmpDir)/swiftclaw-anchor-partial2-\(UUID().uuidString).txt"
        try "foo".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = EditFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let args = """
        {"path":"\(path)","old_string":"foo","new_string":"bar","anchor_hash":"deadbeef"}
        """
        let result = try await tool.execute(arguments: args)
        #expect(result.isError)
        #expect(result.content.contains("together"))
    }

    @Test("edit_file rejects out-of-range anchor line")
    func editFileAnchorOutOfRange() async throws {
        let path = "\(tmpDir)/swiftclaw-anchor-oor-\(UUID().uuidString).txt"
        try "one\ntwo".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let tool = EditFileTool(sandbox: FileSandbox(allowedPaths: [tmpDir]))
        let args = """
        {"path":"\(path)","old_string":"one","new_string":"x","anchor_line":99,"anchor_hash":"deadbeef"}
        """
        let result = try await tool.execute(arguments: args)
        #expect(result.isError)
        #expect(result.content.contains("out of range"))
    }
}
