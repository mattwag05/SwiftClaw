@testable import SwiftClawCore
import Testing

@Suite("CredentialProxy")
struct CredentialProxyTests {
    // MARK: - NoOpCredentialProxy

    @Test("NoOpCredentialProxy returns input unchanged")
    func noOpPassthrough() {
        let proxy = NoOpCredentialProxy()
        let secret = "AKIATESTKEY1234567"
        #expect(proxy.scrub(secret) == secret)
    }

    // MARK: - AWS access key

    @Test("Detects AWS access key ID")
    func awsKey() {
        let proxy = RegexCredentialProxy()
        let input = "key=AKIAIOSFODNN7EXAMPLE result ok"
        let output = proxy.scrub(input)
        #expect(output.contains("[REDACTED:aws_key]"))
        #expect(!output.contains("AKIAIOSFODNN7EXAMPLE"))
    }

    @Test("Does not flag short AKI prefix")
    func awsKeyShortPrefix() {
        let proxy = RegexCredentialProxy()
        #expect(proxy.scrub("AKI") == "AKI")
    }

    // MARK: - GitHub PATs

    @Test("Detects GitHub PAT (ghp_)")
    func githubPatGhp() {
        let proxy = RegexCredentialProxy()
        let token = "ghp_" + String(repeating: "A", count: 36)
        let output = proxy.scrub("Authorization: Bearer \(token)")
        #expect(output.contains("[REDACTED:github]"))
        #expect(!output.contains(token))
    }

    @Test("Detects GitHub OAuth token (gho_)")
    func githubPatGho() {
        let proxy = RegexCredentialProxy()
        let token = "gho_" + String(repeating: "B", count: 36)
        #expect(proxy.scrub(token).contains("[REDACTED:github]"))
    }

    // MARK: - Anthropic API key

    @Test("Detects Anthropic API key")
    func anthropicKey() {
        let proxy = RegexCredentialProxy()
        let key = "sk-ant-api03-" + String(repeating: "x", count: 40)
        let output = proxy.scrub("key: \(key)")
        #expect(output.contains("[REDACTED:anthropic]"))
        #expect(!output.contains(key))
    }

    // MARK: - OpenAI API key

    @Test("Detects OpenAI API key")
    func openaiKey() {
        let proxy = RegexCredentialProxy()
        let key = "sk-" + String(repeating: "z", count: 48)
        let output = proxy.scrub("OPENAI_API_KEY=\(key)")
        #expect(output.contains("[REDACTED:openai]"))
        #expect(!output.contains(key))
    }

    // MARK: - Stripe key

    @Test("Detects Stripe live secret key")
    func stripeKey() {
        let proxy = RegexCredentialProxy()
        let key = "sk_live_" + String(repeating: "s", count: 30)
        #expect(proxy.scrub(key).contains("[REDACTED:stripe]"))
    }

    // MARK: - Slack token

    @Test("Detects Slack bot token")
    func slackToken() {
        let proxy = RegexCredentialProxy()
        let token = "xoxb-FAKE-TEST-TOKEN-notreal"
        #expect(proxy.scrub(token).contains("[REDACTED:slack]"))
    }

    // MARK: - JWT

    @Test("Detects JWT")
    func jwt() {
        let proxy = RegexCredentialProxy()
        let token = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        let output = proxy.scrub("token=\(token) authorized")
        #expect(output.contains("[REDACTED:jwt]"))
        #expect(!output.contains("eyJhbGci"))
    }

    // MARK: - PEM private key

    @Test("Detects PEM private key block")
    func pemPrivateKey() {
        let proxy = RegexCredentialProxy()
        let pem = """
        -----BEGIN RSA PRIVATE KEY-----
        MIIEowIBAAKCAQEA2a2rwplBQLF29amygykEMmYz0+Kcj3bKBp29P2rFj7rGFY
        -----END RSA PRIVATE KEY-----
        """
        let output = proxy.scrub("Key:\n\(pem)\nend")
        #expect(output.contains("[REDACTED:private_key]"))
        #expect(!output.contains("BEGIN RSA PRIVATE KEY"))
    }

    // MARK: - Multi-secret string

    @Test("Replaces multiple distinct secrets in one string")
    func multipleSecrets() {
        let proxy = RegexCredentialProxy()
        let awsKey = "AKIAIOSFODNN7EXAMPLE"
        let slackToken = "xoxb-FAKE-TEST-TOKEN-notreal"
        let input = "aws=\(awsKey) slack=\(slackToken)"
        let output = proxy.scrub(input)
        #expect(output.contains("[REDACTED:aws_key]"))
        #expect(output.contains("[REDACTED:slack]"))
        #expect(!output.contains(awsKey))
        #expect(!output.contains(slackToken))
    }

    // MARK: - Custom extra patterns

    @Test("Custom extra pattern is applied")
    func customPattern() {
        let proxy = RegexCredentialProxy(extraPatterns: [("my_token", "MY_TOKEN_[A-Z0-9]+")])
        let output = proxy.scrub("auth=MY_TOKEN_ABC123")
        #expect(output.contains("[REDACTED:my_token]"))
        #expect(!output.contains("MY_TOKEN_ABC123"))
    }
}
