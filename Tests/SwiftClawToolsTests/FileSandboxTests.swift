import Foundation
import Testing
@testable import SwiftClawTools

@Suite("FileSandbox Tests")
struct FileSandboxTests {
    let home = NSHomeDirectory()

    @Test("Allows home directory itself")
    func allowsHomeDirectory() throws {
        let sandbox = FileSandbox(allowedPaths: ["~"])
        let result = try sandbox.validate(path: "~")
        #expect(result == home)
    }

    @Test("Allows path under home directory")
    func allowsPathUnderHome() throws {
        let sandbox = FileSandbox(allowedPaths: ["~"])
        let result = try sandbox.validate(path: "~/Downloads")
        #expect(result.hasPrefix(home))
        #expect(result.hasSuffix("Downloads"))
    }

    @Test("Allows absolute path in allowlist")
    func allowsAbsolutePath() throws {
        let sandbox = FileSandbox(allowedPaths: ["/tmp"])
        let result = try sandbox.validate(path: "/tmp/test.txt")
        #expect(result.hasPrefix("/tmp"))
    }

    @Test("Rejects path outside allowlist")
    func rejectsOutsidePath() {
        let sandbox = FileSandbox(allowedPaths: ["~"])
        #expect(throws: FileSandboxError.self) {
            try sandbox.validate(path: "/etc/passwd")
        }
    }

    @Test("Rejects empty path")
    func rejectsEmptyPath() {
        let sandbox = FileSandbox(allowedPaths: ["~"])
        #expect(throws: FileSandboxError.self) {
            try sandbox.validate(path: "")
        }
    }

    @Test("Expands tilde to home directory")
    func expandsTilde() throws {
        let sandbox = FileSandbox(allowedPaths: ["~"])
        let result = try sandbox.validate(path: "~/Documents/file.txt")
        #expect(result == "\(home)/Documents/file.txt")
    }

    @Test("Rejects path that escapes via double-dot traversal")
    func rejectsTraversalAttempt() {
        let sandbox = FileSandbox(allowedPaths: ["/tmp/safe"])
        // /tmp/safe/../../../etc/passwd resolves to /etc/passwd
        #expect(throws: FileSandboxError.self) {
            try sandbox.validate(path: "/tmp/safe/../../../etc/passwd")
        }
    }
}
