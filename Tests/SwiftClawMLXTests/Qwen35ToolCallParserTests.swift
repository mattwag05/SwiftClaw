import Testing
@testable import SwiftClawMLX

@Suite("Qwen35ToolCallParser")
struct Qwen35ToolCallParserTests {

    @Test("Single tool call with one parameter")
    func singleToolCallWithParameter() {
        let text = """
        <tool_call>
        <function=shell>
        <parameter=command>
        ls /tmp
        </parameter>
        </function>
        </tool_call>
        """
        let result = Qwen35ToolCallParser.parse(text: text)
        #expect(result.toolCalls.count == 1)
        #expect(result.toolCalls[0].name == "shell")
        #expect(result.toolCalls[0].arguments.contains("\"command\""))
        #expect(result.toolCalls[0].arguments.contains("ls /tmp"))
        #expect(!result.toolCalls[0].id.isEmpty)
    }

    @Test("Zero-arg tool call")
    func zeroArgToolCall() {
        let text = "<tool_call>\n<function=system_info></function>\n</tool_call>"
        let result = Qwen35ToolCallParser.parse(text: text)
        #expect(result.toolCalls.count == 1)
        #expect(result.toolCalls[0].name == "system_info")
        #expect(result.toolCalls[0].arguments == "{}")
    }

    @Test("Multiple tool calls in one generation")
    func multipleToolCalls() {
        let text = """
        <tool_call>
        <function=system_info></function>
        </tool_call>
        <tool_call>
        <function=shell>
        <parameter=command>
        pwd
        </parameter>
        </function>
        </tool_call>
        """
        let result = Qwen35ToolCallParser.parse(text: text)
        #expect(result.toolCalls.count == 2)
        #expect(result.toolCalls[0].name == "system_info")
        #expect(result.toolCalls[1].name == "shell")
    }

    @Test("Multiple parameters in one call")
    func multipleParameters() {
        let text = """
        <tool_call>
        <function=some_tool>
        <parameter=alpha>
        valueA
        </parameter>
        <parameter=beta>
        valueB
        </parameter>
        </function>
        </tool_call>
        """
        let result = Qwen35ToolCallParser.parse(text: text)
        #expect(result.toolCalls.count == 1)
        let args = result.toolCalls[0].arguments
        #expect(args.contains("\"alpha\""))
        #expect(args.contains("\"valueA\""))
        #expect(args.contains("\"beta\""))
        #expect(args.contains("\"valueB\""))
    }

    @Test("No tool calls returns empty array and full text")
    func noToolCalls() {
        let text = "This is regular text with no tool calls."
        let result = Qwen35ToolCallParser.parse(text: text)
        #expect(result.toolCalls.isEmpty)
        #expect(result.remainingText == text)
    }

    @Test("Multiline parameter value is preserved")
    func multilineParameterValue() {
        let text = """
        <tool_call>
        <function=shell>
        <parameter=command>
        echo "line1"
        echo "line2"
        </parameter>
        </function>
        </tool_call>
        """
        let result = Qwen35ToolCallParser.parse(text: text)
        #expect(result.toolCalls.count == 1)
        let args = result.toolCalls[0].arguments
        #expect(args.contains("line1"))
        #expect(args.contains("line2"))
    }

    @Test("Leading and trailing newlines trimmed from parameter values")
    func newlineTrimming() {
        let inner = "<function=tool>\n<parameter=key>\nhello\n</parameter>\n</function>"
        let call = Qwen35ToolCallParser.parseBlock(inner)
        #expect(call != nil)
        // Value should be "hello" not "\nhello" or "hello\n"
        #expect(call?.arguments.contains("\"hello\"") == true)
        #expect(call?.arguments.contains("\\nhello") == false)
        #expect(call?.arguments.contains("hello\\n") == false)
    }

    @Test("Text before tool call is preserved in remainingText")
    func textBeforeToolCallPreserved() {
        let text = "Some reasoning text\n<tool_call>\n<function=system_info></function>\n</tool_call>"
        let result = Qwen35ToolCallParser.parse(text: text)
        #expect(result.toolCalls.count == 1)
        #expect(result.remainingText.contains("Some reasoning text"))
        #expect(!result.remainingText.contains("<tool_call>"))
        #expect(!result.remainingText.contains("</tool_call>"))
    }

    // MARK: - Bare <function=...> tests (text-injection format)

    @Test("Bare function with no params (no outer tool_call)")
    func bareFunctionNoParams() {
        let text = "<function=date_time>\n</function>"
        let result = Qwen35ToolCallParser.parse(text: text)
        #expect(result.toolCalls.count == 1)
        #expect(result.toolCalls[0].name == "date_time")
        #expect(result.toolCalls[0].arguments == "{}")
    }

    @Test("Bare function with parameter")
    func bareFunctionWithParameter() {
        let text = "<function=shell>\n<parameter=command>ls</parameter>\n</function>"
        let result = Qwen35ToolCallParser.parse(text: text)
        #expect(result.toolCalls.count == 1)
        #expect(result.toolCalls[0].name == "shell")
        #expect(result.toolCalls[0].arguments.contains("\"command\""))
        #expect(result.toolCalls[0].arguments.contains("ls"))
    }

    @Test("Mixed — text before and after a bare function block")
    func bareFunctionMixed() {
        let text = "Here is my answer:\n<function=date_time>\n</function>\nDone."
        let result = Qwen35ToolCallParser.parse(text: text)
        #expect(result.toolCalls.count == 1)
        #expect(result.toolCalls[0].name == "date_time")
        let remaining = result.remainingText
        #expect(remaining.contains("Here is my answer"))
        #expect(remaining.contains("Done."))
        #expect(!remaining.contains("<function="))
    }

    @Test("Multiple bare function blocks in one text")
    func multipleBareFunctions() {
        let text = """
        <function=date_time>
        </function>
        <function=shell>
        <parameter=command>pwd</parameter>
        </function>
        """
        let result = Qwen35ToolCallParser.parse(text: text)
        #expect(result.toolCalls.count == 2)
        #expect(result.toolCalls[0].name == "date_time")
        #expect(result.toolCalls[1].name == "shell")
    }

    @Test("Each tool call gets a unique ID")
    func uniqueIds() {
        let text = """
        <tool_call>
        <function=system_info></function>
        </tool_call>
        <tool_call>
        <function=system_info></function>
        </tool_call>
        """
        let result = Qwen35ToolCallParser.parse(text: text)
        #expect(result.toolCalls.count == 2)
        #expect(result.toolCalls[0].id != result.toolCalls[1].id)
    }
}
