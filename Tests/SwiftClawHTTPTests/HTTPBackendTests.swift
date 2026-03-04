import Testing
import Foundation
@testable import SwiftClawHTTP
import SwiftClawCore

@Suite("SSEParser Tests")
struct SSEParserTests {
    let parser = SSEParser()

    @Test("Parses text delta chunk")
    func parsesTextDelta() throws {
        let line = #"data: {"choices":[{"delta":{"content":"Hello"},"finish_reason":null}]}"#
        let chunk = try parser.parse(line: line)
        #expect(chunk?.choices.first?.delta.content == "Hello")
    }

    @Test("Returns nil for empty line")
    func returnsNilForEmptyLine() throws {
        #expect(try parser.parse(line: "") == nil)
    }

    @Test("Returns nil for non-data line")
    func returnsNilForEventLine() throws {
        #expect(try parser.parse(line: "event: message") == nil)
    }

    @Test("Throws SSEDoneError for [DONE]")
    func throwsForDone() {
        #expect(throws: SSEDoneError.self) {
            try parser.parse(line: "data: [DONE]")
        }
    }

    @Test("Parses finish reason stop")
    func parsesFinishReasonStop() throws {
        let line = #"data: {"choices":[{"delta":{},"finish_reason":"stop"}]}"#
        let chunk = try parser.parse(line: line)
        #expect(chunk?.choices.first?.finishReason == "stop")
    }

    @Test("Parses tool call delta")
    func parsesToolCallDelta() throws {
        let line = #"""
        data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_abc","function":{"name":"shell","arguments":""}}]},"finish_reason":null}]}
        """#
        let chunk = try parser.parse(line: line)
        let toolCall = chunk?.choices.first?.delta.toolCalls?.first
        #expect(toolCall?.index == 0)
        #expect(toolCall?.id == "call_abc")
        #expect(toolCall?.function?.name == "shell")
    }

    @Test("Parses finish_reason tool_calls")
    func parsesFinishReasonToolCalls() throws {
        let line = #"data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}"#
        let chunk = try parser.parse(line: line)
        #expect(chunk?.choices.first?.finishReason == "tool_calls")
    }
}

@Suite("OpenAI Message Mapping")
struct OpenAIMessageMappingTests {
    @Test("Maps system message")
    func mapsSystemMessage() {
        let msg = Message(role: .system, content: "You are helpful.")
        let oai = OpenAIMessage(from: msg)
        #expect(oai.role == "system")
        #expect(oai.content == "You are helpful.")
        #expect(oai.toolCalls == nil)
    }

    @Test("Maps user message")
    func mapsUserMessage() {
        let msg = Message(role: .user, content: "Hello")
        let oai = OpenAIMessage(from: msg)
        #expect(oai.role == "user")
        #expect(oai.content == "Hello")
    }

    @Test("Maps tool result message")
    func mapsToolMessage() {
        let msg = Message(role: .tool, content: "result", toolCallId: "call_123")
        let oai = OpenAIMessage(from: msg)
        #expect(oai.role == "tool")
        #expect(oai.content == "result")
        #expect(oai.toolCallId == "call_123")
    }

    @Test("Maps assistant message with tool calls — content is nil")
    func mapsAssistantWithToolCalls() {
        let tc = ToolCallRequest(id: "call_x", name: "shell", arguments: "{}")
        let msg = Message(role: .assistant, content: "", toolCalls: [tc])
        let oai = OpenAIMessage(from: msg)
        #expect(oai.role == "assistant")
        #expect(oai.content == nil)
        #expect(oai.toolCalls?.count == 1)
        #expect(oai.toolCalls?.first?.id == "call_x")
    }

    @Test("Serializes request to JSON with correct shape")
    func serializesRequest() throws {
        let request = ChatCompletionRequest(
            model: "qwen2.5:7b",
            messages: [OpenAIMessage(from: Message(role: .user, content: "Hi"))],
            tools: nil,
            stream: true,
            temperature: 0.7,
            maxTokens: 1024,
            topP: nil
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["model"] as? String == "qwen2.5:7b")
        #expect(json?["stream"] as? Bool == true)
        #expect(json?["max_tokens"] as? Int == 1024)
    }
}
