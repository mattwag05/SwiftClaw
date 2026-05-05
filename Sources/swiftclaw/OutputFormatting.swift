/// Pad a string to a fixed width for tabular CLI output.
func col(_ s: String, _ w: Int) -> String {
    s.padding(toLength: w, withPad: " ", startingAt: 0)
}

/// Parse a comma-separated CLI tag string into trimmed, lowercased tags.
func parseTags(_ raw: String) -> [String] {
    raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
}

/// Format a byte count as a human-readable string (e.g. "4.2GB", "512MB").
func humanBytes(_ bytes: Int64) -> String {
    let gb = Double(bytes) / 1_073_741_824
    if gb >= 1 { return String(format: "%.1fGB", gb) }
    let mb = Double(bytes) / 1_048_576
    if mb >= 1 { return String(format: "%.0fMB", mb) }
    return "\(bytes)B"
}
