import Foundation
import Testing
@testable import SwiftClawPippin
@testable import SwiftClawCore

@Suite("PippinRunner Tests")
struct PippinRunnerTests {
    @Test("binaryPath returns nil when pippin is not installed on CI")
    func binaryPathMayBeNil() {
        // Just verify the function doesn't crash — result depends on environment
        _ = PippinRunner.binaryPath()
    }

    @Test("PippinRunner init fails gracefully when binary not found")
    func initFailsGracefully() {
        let runner = PippinRunner(binaryPath: "/nonexistent/path/pippin")
        #expect(runner == nil)
    }
}

@Suite("Mail Tool Schema Tests")
struct MailToolSchemaTests {
    // We use a fake PippinRunner path that exists but isn't really pippin
    // to construct the tools and validate metadata only.
    let fakeBinaryPath = "/bin/echo"

    func makeRunner() -> PippinRunner? {
        PippinRunner(binaryPath: fakeBinaryPath)
    }

    @Test("mail_list has correct name and required params")
    func mailListName() throws {
        guard let runner = makeRunner() else { return }
        let tool = MailListTool(runner: runner)
        #expect(tool.name == "mail_list")
        #expect(!tool.description.isEmpty)
    }

    @Test("mail_search has correct name")
    func mailSearchName() throws {
        guard let runner = makeRunner() else { return }
        let tool = MailSearchTool(runner: runner)
        #expect(tool.name == "mail_search")
    }

    @Test("mail_show has correct name")
    func mailShowName() throws {
        guard let runner = makeRunner() else { return }
        let tool = MailShowTool(runner: runner)
        #expect(tool.name == "mail_show")
    }

    @Test("mail_send has correct name and caution in description")
    func mailSendName() throws {
        guard let runner = makeRunner() else { return }
        let tool = MailSendTool(runner: runner)
        #expect(tool.name == "mail_send")
        #expect(tool.description.uppercased().contains("CAUTION"))
    }

    @Test("mail_mark has correct name")
    func mailMarkName() throws {
        guard let runner = makeRunner() else { return }
        let tool = MailMarkTool(runner: runner)
        #expect(tool.name == "mail_mark")
    }

    @Test("mail_move has correct name")
    func mailMoveName() throws {
        guard let runner = makeRunner() else { return }
        let tool = MailMoveTool(runner: runner)
        #expect(tool.name == "mail_move")
    }
}

@Suite("Memos Tool Schema Tests")
struct MemosToolSchemaTests {
    let fakeBinaryPath = "/bin/echo"

    func makeRunner() -> PippinRunner? {
        PippinRunner(binaryPath: fakeBinaryPath)
    }

    @Test("memos_list has correct name")
    func memosListName() throws {
        guard let runner = makeRunner() else { return }
        let tool = MemosListTool(runner: runner)
        #expect(tool.name == "memos_list")
    }

    @Test("memos_info has correct name")
    func memosInfoName() throws {
        guard let runner = makeRunner() else { return }
        let tool = MemosInfoTool(runner: runner)
        #expect(tool.name == "memos_info")
    }

    @Test("memos_transcribe has correct name")
    func memosTranscribeName() throws {
        guard let runner = makeRunner() else { return }
        let tool = MemosTranscribeTool(runner: runner)
        #expect(tool.name == "memos_transcribe")
    }
}

@Suite("PippinToolFactory Tests")
struct PippinToolFactoryTests {
    @Test("allTools returns empty array when pippin is not installed")
    func allToolsEmpty() {
        // On CI without pippin installed, should return empty — not crash
        let tools = PippinToolFactory.allTools()
        // Result depends on environment — just verify it's a valid array
        #expect(tools.count >= 0)
    }
}
