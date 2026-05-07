import Foundation

/// Manages a per-mode allowlist of bash command prefixes for Build-mode safety.
///
/// Architecture:
/// - **Denylist** (static, always wins): blocks commands that are unconditionally
///   unsafe regardless of workspace context (ports Gemma's denylist).
/// - **Allowlist** (per-mode, persisted to disk): commands whose prefix matches
///   are auto-approved without a user prompt.
///
/// Two separate on-disk lists exist:
/// - Build: `~/.swiftclaw/security/build-bash-allowlist.json` — seeded with read-only commands.
/// - Chat: `~/.swiftclaw/security/chat-bash-allowlist.json` — empty by default.
public actor BashAllowlist {

    // MARK: - Denial outcome

    public enum Decision: Sendable {
        /// Command is unconditionally blocked (denylist match). Never allow.
        case blocked
        /// Command is on the allowlist — auto-approve.
        case allowed
        /// No match — prompt the user.
        case requiresPrompt
    }

    // MARK: - On-disk format

    public enum SessionModeKey: String, Codable, Sendable {
        case build
        case chat
    }

    // MARK: - Denylist (ported from Gemma Chat)

    /// Patterns matched against the full command string. Denial is unconditional.
    private static let denylistPatterns: [String] = [
        #"(^|\s)(sudo|su)\s"#,
        #"rm\s+-rf\s+/"#,
        #"\bmkfs\b"#,
        #"\bdd\b.*if=/dev/(zero|urandom|random)"#,
        #"\bformat\b"#,
        #">\s*/dev/(s?d[a-z]|nv)"#,           // Redirecting to raw devices
        #"(curl|wget).*(sh|bash|zsh|fish)\b"#, // curl | sh pattern
        #"\|\s*(sh|bash|zsh|fish)\b"#,          // ... | bash
        #"chmod\s+777"#,
        #"\bnc\b.*-e\b"#,                       // netcat backdoor
        #"base64\s+--decode.*\|\s*(sh|bash)"#,
    ]

    private static let denylistRegexes: [NSRegularExpression] = denylistPatterns.compactMap {
        try? NSRegularExpression(pattern: $0, options: .caseInsensitive)
    }

    // MARK: - Build allowlist seeds

    private static let buildAllowlistSeed: [String] = [
        "ls", "cat", "echo", "pwd", "find", "grep", "head", "tail", "wc",
        "file", "stat", "which", "type", "env", "printenv", "date", "whoami",
        "id", "uname", "hostname", "uptime", "df", "du", "free",
        "node --version", "node -v", "npm --version", "npm -v",
        "python3 --version", "python3 -V", "python --version",
        "swift --version", "swift package describe",
        "git status", "git log", "git diff", "git branch", "git show",
        "make --version", "cmake --version",
    ]

    // MARK: - State

    private let url: URL
    private var prefixes: [String]

    // MARK: - Init

    public init(mode: SessionModeKey, baseDir: URL? = nil) throws {
        let secDir = (baseDir ?? FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".swiftclaw"))
            .appendingPathComponent("security")
        try FileManager.default.createDirectory(at: secDir, withIntermediateDirectories: true)
        let file = secDir.appendingPathComponent("\(mode.rawValue)-bash-allowlist.json")
        url = file

        if FileManager.default.fileExists(atPath: file.path) {
            let data = try Data(contentsOf: file)
            prefixes = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        } else {
            // Seed build allowlist; chat starts empty
            prefixes = mode == .build ? Self.buildAllowlistSeed : []
            let data = try JSONEncoder().encode(prefixes)
            try data.write(to: file, options: .atomic)
        }
    }

    // MARK: - Decision

    /// Evaluate a shell command against denylist and allowlist.
    public func decision(for command: String) -> Decision {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)

        // Denylist always wins.
        for regex in Self.denylistRegexes {
            if regex.firstMatch(in: trimmed, range: range) != nil {
                return .blocked
            }
        }

        // Prevent overmatch: "ls" must not allow "lsof". Require exact match or a
        // whitespace delimiter immediately after the prefix (no string allocations).
        for prefix in prefixes {
            guard trimmed.hasPrefix(prefix) else { continue }
            let rest = trimmed.dropFirst(prefix.count)
            if rest.isEmpty || rest.first == " " || rest.first == "\t" {
                return .allowed
            }
        }

        return .requiresPrompt
    }

    // MARK: - Mutations

    public func add(prefix: String) throws {
        guard !prefix.isEmpty else { return }
        if !prefixes.contains(prefix) {
            prefixes.append(prefix)
            try persist()
        }
    }

    public func remove(prefix: String) throws {
        prefixes.removeAll { $0 == prefix }
        try persist()
    }

    public var allPrefixes: [String] { prefixes }

    // MARK: - Private

    private func persist() throws {
        let data = try JSONEncoder().encode(prefixes)
        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).tmp")
        try data.write(to: tmp)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    }
}
