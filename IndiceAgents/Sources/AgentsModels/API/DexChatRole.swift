import Foundation

/// Raw API payload from agents.json: `DexChatRole`.
public enum DexChatRole: String, APIModel, Hashable, CaseIterable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    case tool = "tool"
}
