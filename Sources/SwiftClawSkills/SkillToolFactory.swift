import SwiftClawCore

/// Factory that creates skill-related tools backed by a given SkillStore.
public enum SkillToolFactory {
    public static func allTools(store: SkillStore) -> [any SwiftClawTool] {
        [SkillLoadTool(store: store)]
    }
}
