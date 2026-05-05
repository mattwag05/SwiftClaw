import Foundation
import SwiftClawCore
@testable import SwiftClawHTTP
import Testing

// MARK: - URL stub

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeStubSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeResponse(_ url: URL, status: Int = 200) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
}

// MARK: - Tests

@Suite("ModelDiscoveryService Tests", .serialized)
struct ModelDiscoveryServiceTests {
    let baseURL = URL(string: "http://localhost:11434/v1")!
    let openaiURL = URL(string: "https://api.openai.com/v1")!

    @Test("listOllamaModels maps fields correctly")
    func ollamaListMapsFields() async throws {
        let json = """
        {"models":[{"name":"qwen2.5:7b","size":4700000000,"details":{"family":"qwen2","parameter_size":"7B","quantization_level":"Q4_K_M"}}]}
        """.data(using: .utf8)!

        MockURLProtocol.handler = { _ in (makeResponse(self.baseURL), json) }
        let svc = ModelDiscoveryService(session: makeStubSession())
        let models = try await svc.listOllamaModels(baseURL: baseURL)

        #expect(models.count == 1)
        let m = models[0]
        #expect(m.id == "qwen2.5:7b")
        #expect(m.size == 4_700_000_000)
        #expect(m.parameterSize == "7B")
        #expect(m.quantization == "Q4_K_M")
        #expect(m.family == "qwen2")
        #expect(m.source == .ollama)
    }

    @Test("listOllamaModels handles missing details")
    func ollamaListNoDetails() async throws {
        let json = """
        {"models":[{"name":"llama3:8b"}]}
        """.data(using: .utf8)!

        MockURLProtocol.handler = { _ in (makeResponse(self.baseURL), json) }
        let svc = ModelDiscoveryService(session: makeStubSession())
        let models = try await svc.listOllamaModels(baseURL: baseURL)

        #expect(models.count == 1)
        #expect(models[0].id == "llama3:8b")
        #expect(models[0].parameterSize == nil)
        #expect(models[0].quantization == nil)
        #expect(models[0].source == .ollama)
    }

    @Test("listOllamaModels strips /v1 suffix for tags URL")
    func ollamaStripsV1() async throws {
        let json = #"{"models":[]}"#.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            return (makeResponse(req.url!), json)
        }
        let svc = ModelDiscoveryService(session: makeStubSession())
        _ = try await svc.listOllamaModels(baseURL: #require(URL(string: "http://localhost:11434/v1")))
        #expect(capturedURL?.absoluteString == "http://localhost:11434/api/tags")
    }

    @Test("listOpenAIModels maps ids correctly")
    func openAIListMapsIds() async throws {
        let json = """
        {"data":[{"id":"gpt-4o-mini"},{"id":"gpt-4o"}]}
        """.data(using: .utf8)!

        MockURLProtocol.handler = { _ in (makeResponse(self.openaiURL), json) }
        let svc = ModelDiscoveryService(session: makeStubSession())
        let models = try await svc.listOpenAIModels(baseURL: openaiURL, apiKey: nil)

        #expect(models.count == 2)
        #expect(models[0].id == "gpt-4o-mini")
        #expect(models[1].id == "gpt-4o")
        #expect(models[0].source == .openai)
    }

    @Test("listOpenAIModels sends Bearer header when apiKey given")
    func openAISendsAuthHeader() async throws {
        let json = #"{"data":[]}"#.data(using: .utf8)!
        var capturedAuth: String?
        MockURLProtocol.handler = { req in
            capturedAuth = req.value(forHTTPHeaderField: "Authorization")
            return (makeResponse(req.url!), json)
        }
        let svc = ModelDiscoveryService(session: makeStubSession())
        _ = try await svc.listOpenAIModels(baseURL: openaiURL, apiKey: "sk-test")
        #expect(capturedAuth == "Bearer sk-test")
    }

    @Test("listOllamaModels throws on non-2xx response")
    func ollamaThrowsOnError() async throws {
        MockURLProtocol.handler = { _ in
            (makeResponse(self.baseURL, status: 503), Data())
        }
        let svc = ModelDiscoveryService(session: makeStubSession())
        do {
            _ = try await svc.listOllamaModels(baseURL: baseURL)
            Issue.record("Expected listOllamaModels to throw on 503 response")
        } catch ModelDiscoveryError.requestFailed {
            // expected
        }
    }
}
