import Foundation
@testable import SwiftClawCore
import Testing

@Suite("TraceExporter")
struct TraceExporterTests {
    // MARK: - Helpers

    private func decode(_ data: Data) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private func messages(_ data: Data) throws -> [[String: Any]] {
        let obj = try decode(data)
        return obj["messages"] as! [[String: Any]]
    }

    // MARK: - Basic export

    @Test("Basic system+user+assistant export produces valid JSONL")
    func basicExport() throws {
        let msgs: [Message] = [
            Message(role: .system, content: "You are a helpful assistant."),
            Message(role: .user, content: "Hello"),
            Message(role: .assistant, content: "Hi there!"),
        ]
        let data = try TraceExporter.exportLine(messages: msgs)
        let parsed = try messages(data)
        #expect(parsed.count == 3)
        #expect(parsed[0]["role"] as? String == "system")
        #expect(parsed[0]["content"] as? String == "You are a helpful assistant.")
        #expect(parsed[1]["role"] as? String == "user")
        #expect(parsed[2]["role"] as? String == "assistant")
        #expect(parsed[2]["content"] as? String == "Hi there!")
    }

    // MARK: - Tool call mapping

    @Test("Assistant message with tool calls maps to tool_calls array")
    func toolCallMapping() throws {
        let call = ToolCallRequest(id: "call-1", name: "get_weather", arguments: "{\"city\":\"NYC\"}")
        let msgs: [Message] = [
            Message(role: .assistant, content: "", toolCalls: [call]),
        ]
        let data = try TraceExporter.exportLine(messages: msgs)
        let parsed = try messages(data)
        #expect(parsed.count == 1)

        let assistantMsg = parsed[0]
        #expect(assistantMsg["role"] as? String == "assistant")
        // content should be null (NSNull) when empty and tool calls present
        #expect(assistantMsg["content"] is NSNull)

        let toolCalls = try #require(assistantMsg["tool_calls"] as? [[String: Any]])
        #expect(toolCalls.count == 1)
        #expect(toolCalls[0]["id"] as? String == "call-1")
        #expect(toolCalls[0]["type"] as? String == "function")

        let fn = try #require(toolCalls[0]["function"] as? [String: Any])
        #expect(fn["name"] as? String == "get_weather")
        #expect(fn["arguments"] as? String == "{\"city\":\"NYC\"}")
    }

    // MARK: - Tool result mapping

    @Test("Tool message maps to tool_call_id")
    func toolResultMapping() throws {
        let msgs: [Message] = [
            Message(role: .tool, content: "Sunny, 72°F", toolCallId: "call-1"),
        ]
        let data = try TraceExporter.exportLine(messages: msgs)
        let parsed = try messages(data)
        #expect(parsed.count == 1)
        #expect(parsed[0]["role"] as? String == "tool")
        #expect(parsed[0]["content"] as? String == "Sunny, 72°F")
        #expect(parsed[0]["tool_call_id"] as? String == "call-1")
    }

    // MARK: - Multi-session export

    @Test("exportAll produces one JSONL line per session")
    func multiSessionExport() throws {
        let session1: [Message] = [
            Message(role: .user, content: "What's 2+2?"),
            Message(role: .assistant, content: "4"),
        ]
        let session2: [Message] = [
            Message(role: .user, content: "What's the capital of France?"),
            Message(role: .assistant, content: "Paris"),
        ]
        let data = try TraceExporter.exportAll([session1, session2])
        let text = try #require(String(data: data, encoding: .utf8))
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 2)

        // Each line is valid JSON with a "messages" key
        for line in lines {
            let lineData = try #require(line.data(using: .utf8))
            let obj = try #require(JSONSerialization.jsonObject(with: lineData) as? [String: Any])
            #expect(obj["messages"] != nil)
        }
    }

    // MARK: - Empty content on tool-calling assistant

    @Test("Empty content on tool-calling assistant turn encodes as null")
    func emptyContentBecomesNull() throws {
        let call = ToolCallRequest(id: "c1", name: "foo", arguments: "{}")
        let msg = Message(role: .assistant, content: "", toolCalls: [call])
        let data = try TraceExporter.exportLine(messages: [msg])
        let parsed = try messages(data)
        #expect(parsed[0]["content"] is NSNull)
    }

    @Test("Non-empty content on tool-calling assistant is preserved")
    func nonEmptyContentPreservedOnToolCall() throws {
        let call = ToolCallRequest(id: "c1", name: "foo", arguments: "{}")
        let msg = Message(role: .assistant, content: "Calling foo...", toolCalls: [call])
        let data = try TraceExporter.exportLine(messages: [msg])
        let parsed = try messages(data)
        #expect(parsed[0]["content"] as? String == "Calling foo...")
    }

    // MARK: - Credential proxy

    @Test("Tool message content is redacted when proxy is active")
    func toolMessageRedacted() throws {
        let awsKey = "AKIAIOSFODNN7EXAMPLE"
        let msgs: [Message] = [
            Message(role: .tool, content: "key=\(awsKey)", toolCallId: "c1"),
        ]
        let data = try TraceExporter.exportLine(messages: msgs, proxy: RegexCredentialProxy())
        let parsed = try messages(data)
        let content = parsed[0]["content"] as? String ?? ""
        #expect(content.contains("[REDACTED:aws_key]"))
        #expect(!content.contains(awsKey))
    }

    @Test("Assistant tool_calls arguments are redacted when proxy is active")
    func toolCallArgumentsRedacted() throws {
        let token = "ghp_" + String(repeating: "X", count: 36)
        let call = ToolCallRequest(id: "c2", name: "shell", arguments: "{\"command\":\"echo \(token)\"}")
        let msgs: [Message] = [
            Message(role: .assistant, content: "", toolCalls: [call]),
        ]
        let data = try TraceExporter.exportLine(messages: msgs, proxy: RegexCredentialProxy())
        let parsed = try messages(data)
        let toolCalls = try #require(parsed[0]["tool_calls"] as? [[String: Any]])
        let fn = try #require(toolCalls[0]["function"] as? [String: Any])
        let args = fn["arguments"] as? String ?? ""
        #expect(args.contains("[REDACTED:github]"))
        #expect(!args.contains(token))
    }

    @Test("NoOp proxy leaves export content unchanged")
    func noOpProxyExport() throws {
        let awsKey = "AKIAIOSFODNN7EXAMPLE"
        let msgs: [Message] = [
            Message(role: .tool, content: "key=\(awsKey)", toolCallId: "c1"),
        ]
        let data = try TraceExporter.exportLine(messages: msgs, proxy: NoOpCredentialProxy())
        let parsed = try messages(data)
        #expect((parsed[0]["content"] as? String ?? "").contains(awsKey))
    }
}
