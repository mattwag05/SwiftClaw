import Foundation
import Testing
@testable import SwiftClawCore
@testable import SwiftClawTools

// MARK: - SystemInfoTool Tests

@Test func systemInfoToolProperties() {
    let tool = SystemInfoTool()
    #expect(tool.name == "system_info")
    #expect(!tool.description.isEmpty)
}

@Test func systemInfoToolExecute() async throws {
    let tool = SystemInfoTool()
    let result = try await tool.execute(arguments: "{}")
    #expect(!result.isError)
    #expect(result.content.contains("Hostname:"))
    #expect(result.content.contains("CPU cores:"))
    #expect(result.content.contains("Memory:"))
}

// MARK: - DiskSpaceTool Tests

@Test func diskSpaceToolProperties() {
    let tool = DiskSpaceTool()
    #expect(tool.name == "disk_space")
}

@Test func diskSpaceToolExecute() async throws {
    let tool = DiskSpaceTool()
    let result = try await tool.execute(arguments: "{}")
    #expect(!result.isError)
    #expect(result.content.contains("Total:"))
    #expect(result.content.contains("Free:"))
}

@Test func diskSpaceToolWithPath() async throws {
    let tool = DiskSpaceTool()
    let result = try await tool.execute(arguments: "{\"path\":\"/tmp\"}")
    #expect(!result.isError)
    #expect(result.content.contains("Path: /tmp"))
}

@Test func diskSpaceToolInvalidPath() async throws {
    let tool = DiskSpaceTool()
    let result = try await tool.execute(arguments: "{\"path\":\"/nonexistent/path/abc123\"}")
    #expect(result.isError)
}

// MARK: - ProcessListTool Tests

@Test func processListToolProperties() {
    let tool = ProcessListTool()
    #expect(tool.name == "process_list")
}

@Test func processListToolExecute() async throws {
    let tool = ProcessListTool()
    let result = try await tool.execute(arguments: "{}")
    #expect(!result.isError)
    #expect(result.content.contains("PID"))  // ps header
}

@Test func processListToolWithLimit() async throws {
    let tool = ProcessListTool()
    let result = try await tool.execute(arguments: "{\"limit\":5}")
    #expect(!result.isError)
    // Header + up to 5 processes
    let lines = result.content.components(separatedBy: "\n").filter { !$0.isEmpty }
    #expect(lines.count <= 6)
}

// MARK: - ShellSandbox Tests

@Test func shellSandboxAllowsValidCommand() throws {
    let sandbox = ShellSandbox()
    let (executable, arguments) = try sandbox.validate(command: "ls -la /tmp")
    #expect(executable.hasSuffix("/ls"))
    #expect(arguments == ["-la", "/tmp"])
}

@Test func shellSandboxRejectsPipe() {
    let sandbox = ShellSandbox()
    #expect(throws: ShellSandboxError.self) {
        try sandbox.validate(command: "ls | grep foo")
    }
}

@Test func shellSandboxRejectsSemicolon() {
    let sandbox = ShellSandbox()
    #expect(throws: ShellSandboxError.self) {
        try sandbox.validate(command: "ls; rm -rf /")
    }
}

@Test func shellSandboxRejectsCommandSubstitution() {
    let sandbox = ShellSandbox()
    #expect(throws: ShellSandboxError.self) {
        try sandbox.validate(command: "echo $(whoami)")
    }
}

@Test func shellSandboxRejectsDisallowedCommand() {
    let sandbox = ShellSandbox()
    #expect(throws: ShellSandboxError.self) {
        try sandbox.validate(command: "rm -rf /")
    }
}

@Test func shellSandboxRejectsEmptyCommand() {
    let sandbox = ShellSandbox()
    #expect(throws: ShellSandboxError.self) {
        try sandbox.validate(command: "")
    }
}

@Test func shellSandboxRejectsRedirect() {
    let sandbox = ShellSandbox()
    #expect(throws: ShellSandboxError.self) {
        try sandbox.validate(command: "echo hello > /tmp/test")
    }
}

@Test func shellSandboxCustomAllowlist() throws {
    let sandbox = ShellSandbox(allowlist: ["echo"])
    let (executable, _) = try sandbox.validate(command: "echo hello")
    #expect(executable.hasSuffix("/echo"))

    #expect(throws: ShellSandboxError.self) {
        try sandbox.validate(command: "ls /tmp")
    }
}

// MARK: - ShellTool Tests

@Test func shellToolProperties() {
    let tool = ShellTool()
    #expect(tool.name == "shell")
}

@Test func shellToolExecuteUptime() async throws {
    let tool = ShellTool()
    let result = try await tool.execute(arguments: "{\"command\":\"uptime\"}")
    #expect(!result.isError)
    #expect(result.content.contains("load average") || result.content.contains("up"))
}

@Test func shellToolRejectsDangerousCommand() async throws {
    let tool = ShellTool()
    let result = try await tool.execute(arguments: "{\"command\":\"rm -rf /\"}")
    #expect(result.isError)
}
