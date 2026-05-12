import Testing
import Foundation
@testable import SwiftClawCore

@Suite("WorkspaceSandbox")
struct WorkspaceSandboxTests {

    // MARK: - assertInWorkspace

    @Test("target equal to base is allowed")
    func targetEqualsBase() throws {
        let base = URL(fileURLWithPath: "/tmp/workspace")
        try WorkspaceSandbox.assertInWorkspace(base: base, target: base)
    }

    @Test("target is direct child")
    func targetIsDirectChild() throws {
        let base = URL(fileURLWithPath: "/tmp/workspace")
        let target = URL(fileURLWithPath: "/tmp/workspace/file.txt")
        try WorkspaceSandbox.assertInWorkspace(base: base, target: target)
    }

    @Test("target is nested descendant")
    func targetIsNestedDescendant() throws {
        let base = URL(fileURLWithPath: "/tmp/workspace")
        let target = URL(fileURLWithPath: "/tmp/workspace/subdir/deep/file.swift")
        try WorkspaceSandbox.assertInWorkspace(base: base, target: target)
    }

    @Test("target outside workspace throws")
    func targetOutsideWorkspace() {
        let base = URL(fileURLWithPath: "/tmp/workspace")
        let target = URL(fileURLWithPath: "/etc/passwd")
        #expect(throws: SwiftClawError.self) {
            try WorkspaceSandbox.assertInWorkspace(base: base, target: target)
        }
    }

    @Test("path traversal with .. throws")
    func pathTraversalDotDot() {
        let base = URL(fileURLWithPath: "/tmp/workspace")
        // standardizedFileURL resolves ".." so this lands at /tmp/evil
        let target = URL(fileURLWithPath: "/tmp/workspace/../evil")
        #expect(throws: SwiftClawError.self) {
            try WorkspaceSandbox.assertInWorkspace(base: base, target: target)
        }
    }

    @Test("sibling directory prefix does not escape")
    func siblingDirectoryPrefix() {
        // /tmp/workspace2 must not pass as a child of /tmp/workspace
        let base = URL(fileURLWithPath: "/tmp/workspace")
        let target = URL(fileURLWithPath: "/tmp/workspace2/file.txt")
        #expect(throws: SwiftClawError.self) {
            try WorkspaceSandbox.assertInWorkspace(base: base, target: target)
        }
    }

    // MARK: - resolve

    @Test("relative path resolves inside workspace")
    func relativePathInsideWorkspace() throws {
        let base = URL(fileURLWithPath: "/tmp/workspace")
        let resolved = try WorkspaceSandbox.resolve(path: "subdir/file.txt", in: base)
        #expect(resolved.path == "/tmp/workspace/subdir/file.txt")
    }

    @Test("absolute path inside workspace is accepted")
    func absolutePathInsideWorkspace() throws {
        let base = URL(fileURLWithPath: "/tmp/workspace")
        let resolved = try WorkspaceSandbox.resolve(path: "/tmp/workspace/file.swift", in: base)
        #expect(resolved.path == "/tmp/workspace/file.swift")
    }

    @Test("absolute path outside workspace throws")
    func absolutePathOutsideWorkspace() {
        let base = URL(fileURLWithPath: "/tmp/workspace")
        #expect(throws: SwiftClawError.self) {
            try WorkspaceSandbox.resolve(path: "/etc/passwd", in: base)
        }
    }

    @Test("relative path traversal throws")
    func relativePathTraversal() {
        let base = URL(fileURLWithPath: "/tmp/workspace")
        #expect(throws: SwiftClawError.self) {
            try WorkspaceSandbox.resolve(path: "../../etc/passwd", in: base)
        }
    }

    @Test("resolve returns standardized URL")
    func resolveReturnsStandardized() throws {
        let base = URL(fileURLWithPath: "/tmp/workspace")
        let resolved = try WorkspaceSandbox.resolve(path: "a/./b/../c.txt", in: base)
        #expect(resolved.path == "/tmp/workspace/a/c.txt")
    }
}
