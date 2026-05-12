import Foundation
@testable import SwiftClawCore
import Testing

// MARK: - XMLActionParser tests

@Suite("XMLActionParser")
struct XMLActionParserTests {
    let parser = XMLActionParser()

    // MARK: findAction

    @Test func findsSimpleAction() {
        let text = """
        I'll write the file.
        <action name="write_file">
        <path>index.html</path>
        <content>hello</content>
        </action>
        Done.
        """
        guard let (before, action, after) = parser.findAction(in: text) else {
            Issue.record("findAction returned nil")
            return
        }
        #expect(before == "I'll write the file.\n")
        #expect(action.name == "write_file")
        #expect(after.trimmingCharacters(in: .whitespacesAndNewlines) == "Done.")
    }

    @Test func parsesMultipleParams() {
        let text = #"<action name="run_bash"><command>ls -la</command><cwd>/tmp</cwd></action>"#
        guard let (_, action, _) = parser.findAction(in: text) else {
            Issue.record("findAction returned nil")
            return
        }
        #expect(action.name == "run_bash")
        let args = try? JSONDecoder().decode([String: String].self, from: Data(action.arguments.utf8))
        #expect(args?["command"] == "ls -la")
        #expect(args?["cwd"] == "/tmp")
    }

    @Test func parsesActionWithSingleQuotedName() {
        let text = "<action name='calc'><expression>2+2</expression></action>"
        guard let (_, action, _) = parser.findAction(in: text) else {
            Issue.record("findAction returned nil")
            return
        }
        #expect(action.name == "calc")
    }

    @Test func returnsNilForIncompleteAction() {
        let text = "Starting <action name=\"write_file\"><path>index.html"
        let result = parser.findAction(in: text)
        #expect(result == nil)
    }

    @Test func returnsNilForNoAction() {
        let result = parser.findAction(in: "Just plain text, no action here.")
        #expect(result == nil)
    }

    @Test func parsesActionWithNoParams() {
        let text = "<action name=\"noop\"></action>"
        guard let (_, action, _) = parser.findAction(in: text) else {
            Issue.record("findAction returned nil")
            return
        }
        #expect(action.name == "noop")
        #expect(action.arguments == "{}")
    }

    @Test func parsesMultilineContent() {
        let content = "line1\nline2\nline3"
        let text = "<action name=\"write_file\"><content>\(content)</content></action>"
        guard let (_, action, _) = parser.findAction(in: text) else {
            Issue.record("findAction returned nil")
            return
        }
        let args = try? JSONDecoder().decode([String: String].self, from: Data(action.arguments.utf8))
        #expect(args?["content"] == content)
    }

    @Test func handlesEmbeddedClosingTagInContent() {
        // Content that itself contains XML-like text should not confuse the action close detector
        let text = "<action name=\"write_file\"><path>out.html</path><content><h1>Title</h1></content></action>"
        guard let (_, action, _) = parser.findAction(in: text) else {
            Issue.record("findAction returned nil")
            return
        }
        let args = try? JSONDecoder().decode([String: String].self, from: Data(action.arguments.utf8))
        #expect(args?["content"] == "<h1>Title</h1>")
    }

    @Test func beforeAndAfterCorrect() {
        let text = "BEFORE<action name=\"t\"><x>v</x></action>AFTER"
        guard let (before, _, after) = parser.findAction(in: text) else {
            Issue.record("findAction returned nil")
            return
        }
        #expect(before == "BEFORE")
        #expect(after == "AFTER")
    }

    // MARK: safePrefix

    @Test func safePrefixWithNoActionStart() {
        let (emit, buffer) = parser.safePrefix(of: "Hello world!")
        #expect(emit == "Hello world!")
        #expect(buffer == "")
    }

    @Test func safePrefixBuffersPartialSentinel() {
        // Text ends with `<act` — a prefix of `<action`
        let (emit, buffer) = parser.safePrefix(of: "Hello <act")
        #expect(emit == "Hello ")
        #expect(buffer == "<act")
    }

    @Test func safePrefixBuffersSingleAngle() {
        let (emit, buffer) = parser.safePrefix(of: "Hello <")
        #expect(emit == "Hello ")
        #expect(buffer == "<")
    }

    @Test func safePrefixWhenFullSentinelPresent() {
        let (emit, buffer) = parser.safePrefix(of: "Text <action name=\"t\">more")
        #expect(emit == "Text ")
        #expect(buffer == "<action name=\"t\">more")
    }

    @Test func safePrefixEmptyString() {
        let (emit, buffer) = parser.safePrefix(of: "")
        #expect(emit == "")
        #expect(buffer == "")
    }

    @Test func safePrefixJustSentinel() {
        let (emit, buffer) = parser.safePrefix(of: "<action")
        #expect(emit == "")
        #expect(buffer == "<action")
    }

    // MARK: cleanFileContent

    @Test func cleanFileContentStripsHTMLFence() {
        let raw = "```html\n<h1>Title</h1>\n```"
        let cleaned = parser.cleanFileContent(raw)
        #expect(cleaned == "<h1>Title</h1>")
    }

    @Test func cleanFileContentStripsPlainFence() {
        let raw = "```\nhello world\n```"
        let cleaned = parser.cleanFileContent(raw)
        #expect(cleaned == "hello world")
    }

    @Test func cleanFileContentPassesThroughNonFenced() {
        let raw = "<html><body>content</body></html>"
        let cleaned = parser.cleanFileContent(raw)
        #expect(cleaned == raw)
    }

    @Test func cleanFileContentPreservesInternalNewlines() {
        let raw = "```json\n{\n  \"key\": \"value\"\n}\n```"
        let cleaned = parser.cleanFileContent(raw)
        #expect(cleaned == "{\n  \"key\": \"value\"\n}")
    }
}
