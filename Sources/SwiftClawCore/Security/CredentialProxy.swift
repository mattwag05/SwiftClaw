import Foundation

/// Intercepts secrets in tool arguments and results before they enter the message history.
public protocol CredentialProxy: Sendable {
    func scrub(_ s: String) -> String
}

// MARK: - No-op

public struct NoOpCredentialProxy: CredentialProxy {
    public init() {}
    public func scrub(_ s: String) -> String {
        s
    }
}

// MARK: - Regex-based

/// Detects and replaces well-known secret patterns with labelled placeholders.
///
/// Patterns target structured tokens (AWS keys, GitHub PATs, Anthropic/OpenAI keys, Stripe
/// keys, Slack tokens, JWTs, PEM private-key blocks) rather than high-entropy heuristics
/// to keep false-positive rates low.
public struct RegexCredentialProxy: CredentialProxy {
    public static let customLabel = "custom"

    private let rules: [(label: String, regex: NSRegularExpression)]

    public init(extraPatterns: [(label: String, pattern: String)] = []) {
        var compiled: [(String, NSRegularExpression)] = []
        for (label, pattern) in Self.builtInPatterns + extraPatterns {
            if let rx = try? NSRegularExpression(
                pattern: pattern,
                options: [.dotMatchesLineSeparators]
            ) {
                compiled.append((label, rx))
            }
        }
        rules = compiled
    }

    public func scrub(_ s: String) -> String {
        var result = s
        for (label, regex) in rules {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: "[REDACTED:\(label)]"
            )
        }
        return result
    }

    // MARK: - Built-in patterns

    private static let builtInPatterns: [(label: String, pattern: String)] = [
        // PEM private-key block — must run first so it doesn't leave orphan headers
        (
            "private_key",
            "-----BEGIN [A-Z ]*PRIVATE KEY-----[\\s\\S]*?-----END [A-Z ]*PRIVATE KEY-----"
        ),
        // JWT (three base64url segments separated by dots)
        (
            "jwt",
            "eyJ[A-Za-z0-9_-]+\\.eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+"
        ),
        // AWS access key ID
        (
            "aws_key",
            "AKIA[0-9A-Z]{16}"
        ),
        // GitHub PATs (classic ghp_, OAuth gho_, server-to-server ghs_, user-to-server ghu_, refresh ghr_)
        (
            "github",
            "gh[oprs]_[A-Za-z0-9]{36}"
        ),
        // Anthropic API key
        (
            "anthropic",
            "sk-ant-[A-Za-z0-9_-]{20,}"
        ),
        // OpenAI API key (standard sk- and project-scoped sk-proj-)
        (
            "openai",
            "sk-(?:proj-)?[A-Za-z0-9]{32,}"
        ),
        // Stripe live/test secret key
        (
            "stripe",
            "sk_(?:live|test)_[A-Za-z0-9]{24,}"
        ),
        // Slack tokens (bot, user, workspace, app, refresh)
        (
            "slack",
            "xox[abprs]-[A-Za-z0-9-]+"
        ),
    ]
}
