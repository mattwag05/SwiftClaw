import Testing
import Foundation
@testable import SwiftClawHTTP
@testable import SwiftClawCore

// MARK: - UsagePayload cache field parsing

@Suite("PromptCaching — UsagePayload")
struct UsagePayloadCacheTests {

    @Test("Parses cache_read_input_tokens and cache_creation_input_tokens from SSE chunk")
    func parsesCacheUsageFromSSEChunk() throws {
        let json = """
        {"choices":[],"usage":{"prompt_tokens":100,"completion_tokens":50,"total_tokens":150,"cache_read_input_tokens":80,"cache_creation_input_tokens":20}}
        """
        let parser = SSEParser()
        let chunk = try parser.parse(line: "data: \(json)")
        #expect(chunk?.usage?.promptTokens == 100)
        #expect(chunk?.usage?.completionTokens == 50)
        #expect(chunk?.usage?.totalTokens == 150)
        #expect(chunk?.usage?.cacheReadInputTokens == 80)
        #expect(chunk?.usage?.cacheCreationInputTokens == 20)
    }

    @Test("Decodes UsagePayload without cache fields — fields are nil")
    func decodesWithoutCacheFields() throws {
        let json = Data("""
        {"prompt_tokens":100,"completion_tokens":50,"total_tokens":150}
        """.utf8)
        let payload = try JSONDecoder().decode(UsagePayload.self, from: json)
        #expect(payload.promptTokens == 100)
        #expect(payload.cacheReadInputTokens == nil)
        #expect(payload.cacheCreationInputTokens == nil)
    }
}

// MARK: - AnthropicCacheControl serialization

@Suite("PromptCaching — AnthropicCacheControl")
struct AnthropicCacheControlTests {

    @Test("Encodes ephemeral with type key")
    func encodesEphemeral() throws {
        let cc = AnthropicCacheControl.ephemeral
        let data = try JSONEncoder().encode(cc)
        let dict = try JSONDecoder().decode([String: String].self, from: data)
        #expect(dict["type"] == "ephemeral")
    }

    @Test("AnthropicContentBlock encodes cache_control key when set")
    func contentBlockEncodesCacheControl() throws {
        let block = AnthropicContentBlock(type: "text", text: "hello", cacheControl: .ephemeral)
        let data = try JSONEncoder().encode(block)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(dict?["type"] as? String == "text")
        #expect(dict?["text"] as? String == "hello")
        let cc = dict?["cache_control"] as? [String: String]
        #expect(cc?["type"] == "ephemeral")
    }

    @Test("AnthropicContentBlock omits cache_control when nil")
    func contentBlockOmitsCacheControlWhenNil() throws {
        let block = AnthropicContentBlock(type: "text", text: "hello", cacheControl: nil)
        let data = try JSONEncoder().encode(block)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(dict?["cache_control"] == nil)
    }
}

// MARK: - MessageContent encoding

@Suite("PromptCaching — MessageContent")
struct MessageContentEncodingTests {

    @Test("MessageContent.string encodes as plain string")
    func stringEncodesAsPlainString() throws {
        let mc = MessageContent.string("hello world")
        let data = try JSONEncoder().encode(mc)
        let decoded = try JSONDecoder().decode(String.self, from: data)
        #expect(decoded == "hello world")
    }

    @Test("MessageContent.contentBlocks encodes as JSON array")
    func contentBlocksEncodeAsArray() throws {
        let blocks = [
            AnthropicContentBlock(type: "text", text: "first", cacheControl: .ephemeral),
            AnthropicContentBlock(type: "text", text: "second", cacheControl: nil),
        ]
        let mc = MessageContent.contentBlocks(blocks)
        let data = try JSONEncoder().encode(mc)
        let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        #expect(arr?.count == 2)
        #expect(arr?.first?["text"] as? String == "first")
        #expect(arr?.last?["text"] as? String == "second")
    }
}

// MARK: - CacheMode Codable

@Suite("PromptCaching — CacheMode")
struct CacheModeTests {

    @Test("CacheMode.none round-trips through Codable")
    func noneCodable() throws {
        let encoded = try JSONEncoder().encode(CacheMode.none)
        let decoded = try JSONDecoder().decode(CacheMode.self, from: encoded)
        #expect(decoded == .none)
    }

    @Test("CacheMode.anthropic round-trips through Codable")
    func anthropicCodable() throws {
        let encoded = try JSONEncoder().encode(CacheMode.anthropic)
        let decoded = try JSONDecoder().decode(CacheMode.self, from: encoded)
        #expect(decoded == .anthropic)
    }

    @Test("CacheMode.openai round-trips through Codable")
    func openaiCodable() throws {
        let encoded = try JSONEncoder().encode(CacheMode.openai)
        let decoded = try JSONDecoder().decode(CacheMode.self, from: encoded)
        #expect(decoded == .openai)
    }

    @Test("CacheMode raw values are correct strings")
    func rawValues() {
        #expect(CacheMode.none.rawValue == "none")
        #expect(CacheMode.anthropic.rawValue == "anthropic")
        #expect(CacheMode.openai.rawValue == "openai")
    }
}

// MARK: - TokenUsage Codable

@Suite("PromptCaching — TokenUsage")
struct TokenUsageCachingTests {

    @Test("TokenUsage with cache fields round-trips")
    func roundTripWithCacheFields() throws {
        let usage = TokenUsage(
            promptTokens: 100,
            completionTokens: 50,
            totalTokens: 150,
            cacheReadTokens: 25,
            cacheCreationTokens: 10
        )
        let data = try JSONEncoder().encode(usage)
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: data)
        #expect(decoded.promptTokens == 100)
        #expect(decoded.completionTokens == 50)
        #expect(decoded.totalTokens == 150)
        #expect(decoded.cacheReadTokens == 25)
        #expect(decoded.cacheCreationTokens == 10)
    }

    @Test("TokenUsage missing cache fields decodes to nil — backward compat")
    func backwardCompatMissingCacheFields() throws {
        let json = Data("""
        {"promptTokens":100,"completionTokens":50,"totalTokens":150}
        """.utf8)
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: json)
        #expect(decoded.cacheReadTokens == nil)
        #expect(decoded.cacheCreationTokens == nil)
    }
}
