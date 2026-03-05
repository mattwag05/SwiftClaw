import Foundation
import Testing
@testable import SwiftClawTools
@testable import SwiftClawCore

@Suite("Environment Tools Tests")
struct EnvironmentToolsTests {
    // MARK: - EnvVarsTool

    @Test("env_vars has correct name")
    func envVarsToolName() {
        let tool = EnvVarsTool()
        #expect(tool.name == "env_vars")
    }

    @Test("env_vars reads HOME variable")
    func envVarsToolReadsHome() async throws {
        let tool = EnvVarsTool()
        let result = try await tool.execute(arguments: "{\"name\":\"HOME\"}")
        #expect(!result.isError)
        #expect(result.content.hasPrefix("HOME="))
    }

    @Test("env_vars returns error for unset variable")
    func envVarsToolUnknownVar() async throws {
        let tool = EnvVarsTool()
        let result = try await tool.execute(
            arguments: "{\"name\":\"SWIFTCLAW_DEFINITELY_NOT_SET_XYZ\"}")
        #expect(result.isError)
    }

    @Test("env_vars dumps all variables when name is omitted")
    func envVarsToolDumpsAll() async throws {
        let tool = EnvVarsTool()
        let result = try await tool.execute(arguments: "{}")
        #expect(!result.isError)
        // Should contain at least one KEY=VALUE pair
        #expect(result.content.contains("="))
    }

    // MARK: - DateTimeTool

    @Test("date_time has correct name")
    func dateTimeToolName() {
        let tool = DateTimeTool()
        #expect(tool.name == "date_time")
    }

    @Test("date_time returns ISO 8601 by default")
    func dateTimeToolReturnsISO() async throws {
        let tool = DateTimeTool()
        let result = try await tool.execute(arguments: "{}")
        #expect(!result.isError)
        // ISO 8601: e.g. 2026-03-05T12:00:00+00:00
        #expect(result.content.contains("T"))
        #expect(result.content.contains(":"))
    }

    @Test("date_time accepts UTC timezone")
    func dateTimeToolUTC() async throws {
        let tool = DateTimeTool()
        let result = try await tool.execute(arguments: "{\"timezone\":\"UTC\"}")
        #expect(!result.isError)
        // macOS normalizes UTC to GMT internally — accept either
        #expect(result.content.contains("UTC") || result.content.contains("GMT"))
    }

    @Test("date_time rejects invalid timezone")
    func dateTimeToolInvalidTimezone() async throws {
        let tool = DateTimeTool()
        let result = try await tool.execute(
            arguments: "{\"timezone\":\"Not/AReal_Zone\"}")
        #expect(result.isError)
    }

    @Test("date_time accepts custom format")
    func dateTimeToolCustomFormat() async throws {
        let tool = DateTimeTool()
        let result = try await tool.execute(
            arguments: "{\"format\":\"yyyy\"}")
        #expect(!result.isError)
        // Should contain a 4-digit year
        #expect(result.content.contains("202"))
    }

    // MARK: - ClipboardTool

    @Test("clipboard has correct name")
    func clipboardToolName() {
        let tool = ClipboardTool()
        #expect(tool.name == "clipboard")
    }

    @Test("clipboard write then read round-trips")
    @MainActor
    func clipboardToolWriteRead() async throws {
        let tool = ClipboardTool()
        let unique = "SwiftClaw-test-\(UUID().uuidString)"

        let writeResult = try await tool.execute(
            arguments: "{\"action\":\"write\",\"content\":\"\(unique)\"}")
        #expect(!writeResult.isError)

        let readResult = try await tool.execute(arguments: "{\"action\":\"read\"}")
        #expect(!readResult.isError)
        #expect(readResult.content.contains(unique))
    }

    @Test("clipboard write rejects missing content")
    func clipboardToolWriteMissingContent() async throws {
        let tool = ClipboardTool()
        let result = try await tool.execute(arguments: "{\"action\":\"write\"}")
        #expect(result.isError)
    }

    @Test("clipboard rejects unknown action")
    func clipboardToolUnknownAction() async throws {
        let tool = ClipboardTool()
        let result = try await tool.execute(arguments: "{\"action\":\"copy\"}")
        #expect(result.isError)
    }
}
