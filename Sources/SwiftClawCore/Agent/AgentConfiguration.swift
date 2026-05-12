/// Configuration for an agent: name, system prompt, tools, and generation settings.
public struct AgentConfiguration: Sendable {
    public let name: String
    public let systemPrompt: String
    public let tools: [any SwiftClawTool]
    public let modelId: String
    public let generationConfig: GenerationConfig
    public let credentialProxy: any CredentialProxy

    public init(
        name: String,
        systemPrompt: String,
        tools: [any SwiftClawTool],
        modelId: String,
        generationConfig: GenerationConfig = GenerationConfig(),
        credentialProxy: any CredentialProxy = NoOpCredentialProxy()
    ) {
        self.name = name
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.modelId = modelId
        self.generationConfig = generationConfig
        self.credentialProxy = credentialProxy
    }
}
