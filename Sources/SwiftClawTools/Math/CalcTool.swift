import Foundation
import SwiftClawCore

/// Evaluates a mathematical expression using a pure-Swift recursive descent parser.
///
/// Supported: `+`, `-`, `*`, `/`, `**` (power), unary `-`, parentheses, and the functions
/// `sqrt`, `abs`, `floor`, `ceil`, `round`, `sin`, `cos`, `tan`, `log`, `log10`, `exp`.
public struct CalcTool: SwiftClawTool {
    public let name = "calc"
    public let requiresConfirmation = false
    public let description = "Evaluate a mathematical expression. Supports +, -, *, /, ** (power), parentheses, and functions: sqrt, abs, floor, ceil, round, sin, cos, tan, log, log10, exp."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "expression": .string(description: "Mathematical expression to evaluate"),
        ],
        required: ["expression"]
    )

    public init() {}

    private struct Arguments: Decodable {
        var expression: String
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        let expr = args.expression.trimmingCharacters(in: .whitespaces)
        guard !expr.isEmpty else { return .failure("Empty expression") }

        do {
            var parser = ExpressionParser(input: expr)
            let result = try parser.parse()
            if result.truncatingRemainder(dividingBy: 1) == 0 && abs(result) < 1e15 {
                return .success(String(format: "%.0f", result))
            }
            return .success(String(result))
        } catch let error as CalcError {
            return .failure(error.message)
        } catch {
            return .failure("Parse error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Parser

private struct CalcError: Error {
    let message: String
}

private struct ExpressionParser {
    private let tokens: [Token]
    private var pos = 0

    init(input: String) {
        var lexer = Lexer(input: input)
        tokens = lexer.tokenize()
    }

    mutating func parse() throws -> Double {
        let result = try parseAddSub()
        guard pos >= tokens.count else {
            throw CalcError(message: "Unexpected token: \(tokens[pos])")
        }
        return result
    }

    // MARK: Recursive descent

    private mutating func parseAddSub() throws -> Double {
        var left = try parseMulDiv()
        while pos < tokens.count {
            if case .op("+") = tokens[pos] {
                pos += 1; left += try parseMulDiv()
            } else if case .op("-") = tokens[pos] {
                pos += 1; left -= try parseMulDiv()
            } else { break }
        }
        return left
    }

    private mutating func parseMulDiv() throws -> Double {
        var left = try parsePower()
        while pos < tokens.count {
            if case .op("*") = tokens[pos] {
                pos += 1; left *= try parsePower()
            } else if case .op("/") = tokens[pos] {
                pos += 1
                let rhs = try parsePower()
                guard rhs != 0 else { throw CalcError(message: "Division by zero") }
                left /= rhs
            } else { break }
        }
        return left
    }

    private mutating func parsePower() throws -> Double {
        let base = try parseUnary()
        if pos < tokens.count, case .op("**") = tokens[pos] {
            pos += 1
            let exp = try parseUnary()
            return pow(base, exp)
        }
        return base
    }

    private mutating func parseUnary() throws -> Double {
        if pos < tokens.count, case .op("-") = tokens[pos] {
            pos += 1
            let v = try parseUnary()
            return -v
        }
        return try parsePrimary()
    }

    private mutating func parsePrimary() throws -> Double {
        guard pos < tokens.count else {
            throw CalcError(message: "Unexpected end of expression")
        }
        switch tokens[pos] {
        case .number(let v):
            pos += 1
            return v
        case .ident(let name):
            pos += 1
            guard pos < tokens.count, case .lparen = tokens[pos] else {
                throw CalcError(message: "Expected '(' after function '\(name)'")
            }
            pos += 1
            let arg = try parseAddSub()
            guard pos < tokens.count, case .rparen = tokens[pos] else {
                throw CalcError(message: "Missing ')' after function '\(name)'")
            }
            pos += 1
            return try applyFunction(name, arg)
        case .lparen:
            pos += 1
            let inner = try parseAddSub()
            guard pos < tokens.count, case .rparen = tokens[pos] else {
                throw CalcError(message: "Missing closing ')'")
            }
            pos += 1
            return inner
        default:
            throw CalcError(message: "Unexpected token: \(tokens[pos])")
        }
    }

    private func applyFunction(_ name: String, _ arg: Double) throws -> Double {
        switch name.lowercased() {
        case "sqrt":   return sqrt(arg)
        case "abs":    return abs(arg)
        case "floor":  return floor(arg)
        case "ceil":   return ceil(arg)
        case "round":  return round(arg)
        case "sin":    return sin(arg)
        case "cos":    return cos(arg)
        case "tan":    return tan(arg)
        case "log":    return log(arg)
        case "log10":  return log10(arg)
        case "exp":    return exp(arg)
        default:       throw CalcError(message: "Unknown function: \(name)")
        }
    }
}

// MARK: - Lexer

private enum Token {
    case number(Double)
    case ident(String)
    case op(String)
    case lparen
    case rparen
}

private struct Lexer {
    private let input: [Character]
    private var i: Int = 0

    init(input: String) {
        self.input = Array(input)
    }

    mutating func tokenize() -> [Token] {
        var tokens: [Token] = []
        while i < input.count {
            let c = input[i]
            if c.isWhitespace { i += 1; continue }
            if c.isNumber || c == "." {
                tokens.append(lexNumber())
            } else if c.isLetter || c == "_" {
                tokens.append(lexIdent())
            } else if c == "*" && i + 1 < input.count && input[i + 1] == "*" {
                tokens.append(.op("**")); i += 2
            } else if "+-*/".contains(c) {
                tokens.append(.op(String(c))); i += 1
            } else if c == "(" {
                tokens.append(.lparen); i += 1
            } else if c == ")" {
                tokens.append(.rparen); i += 1
            } else {
                i += 1
            }
        }
        return tokens
    }

    private mutating func lexNumber() -> Token {
        var s = ""
        while i < input.count && (input[i].isNumber || input[i] == "." || input[i] == "e" || input[i] == "E"
              || ((input[i] == "+" || input[i] == "-") && i > 0 && (input[i-1] == "e" || input[i-1] == "E"))) {
            s.append(input[i]); i += 1
        }
        return .number(Double(s) ?? 0)
    }

    private mutating func lexIdent() -> Token {
        var s = ""
        while i < input.count && (input[i].isLetter || input[i].isNumber || input[i] == "_") {
            s.append(input[i]); i += 1
        }
        return .ident(s)
    }
}
