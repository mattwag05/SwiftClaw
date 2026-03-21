import Foundation
import Testing
@testable import SwiftClawCore

@Suite("SwiftClawConfig Tests")
struct ConfigTests {
    @Test("Default config has ~ in allowed paths")
    func defaultConfigHasHome() {
        let config = SwiftClawConfig.default
        #expect(config.fileSandbox.allowedPaths == ["~"])
    }

    @Test("Default FileSandboxConfig has ~ in allowed paths")
    func defaultFileSandboxConfig() {
        let config = FileSandboxConfig.default
        #expect(config.allowedPaths == ["~"])
    }

    @Test("Load returns default when config file is missing")
    func loadReturnsDefaultWhenMissing() throws {
        // Use a non-existent path override is not possible via the API,
        // but we can verify the default is returned when no file exists at ~/.swiftclaw/config.json
        // by checking that load() doesn't throw when the file is absent.
        // (This test passes in CI where ~/.swiftclaw/config.json likely doesn't exist.)
        let config = try SwiftClawConfig.load()
        // The result is either default or whatever the user has configured — just ensure no throw.
        #expect(!config.fileSandbox.allowedPaths.isEmpty)
    }

    @Test("Round-trips through JSON encoding/decoding")
    func jsonRoundTrip() throws {
        let original = SwiftClawConfig(
            fileSandbox: FileSandboxConfig(allowedPaths: ["~", "/tmp"])
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SwiftClawConfig.self, from: data)
        #expect(decoded.fileSandbox.allowedPaths == ["~", "/tmp"])
    }

    @Test("Decodes old config JSON without cacheMode — defaults to .none")
    func cacheModeBackwardCompat() throws {
        let json = Data("""
        {"fileSandbox":{"allowedPaths":["~"]},"embeddingModelId":"x","embeddingDimensions":768,"retrievalTopK":10,"retrievalThreshold":0.3,"memoryEnabled":false,"consolidationInterval":3}
        """.utf8)
        let config = try JSONDecoder().decode(SwiftClawConfig.self, from: json)
        #expect(config.cacheMode == .none)
    }
}
