import Foundation

/// Raw API payload from agents.json: `DexChatPatchOp`.
public enum DexChatPatchOp: String, APIModel, Hashable, CaseIterable {
    case add = "add"
    case append = "append"
    case replace = "replace"
}
