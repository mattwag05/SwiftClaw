/// Pad a string to a fixed width for tabular CLI output.
func col(_ s: String, _ w: Int) -> String {
    s.padding(toLength: w, withPad: " ", startingAt: 0)
}

/// Parse a comma-separated CLI tag string into trimmed, lowercased tags.
func parseTags(_ raw: String) -> [String] {
    raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
}
