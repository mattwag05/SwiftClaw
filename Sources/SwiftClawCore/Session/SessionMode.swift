/// The operational mode of a session.
///
/// - `chat`: General conversational mode (Pippin + system tools enabled).
/// - `build`: Vibe-coding mode with workspace-scoped file tools, `run_bash`,
///   and Canvas preview. Pippin tools are hidden.
public enum SessionMode: String, Codable, Sendable, Hashable, CaseIterable {
    case chat
    case build
}
