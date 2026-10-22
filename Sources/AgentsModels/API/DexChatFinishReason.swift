import Foundation

/// Raw API payload from agents.json: `DexChatFinishReason`.
public enum DexChatFinishReason: String, APIModel, Hashable, CaseIterable {
    case stop = "stop"
    case length = "length"
    case toolCalls = "tool_calls"
    case contentFilter = "content_filter"
    case limit = "limit"
}
