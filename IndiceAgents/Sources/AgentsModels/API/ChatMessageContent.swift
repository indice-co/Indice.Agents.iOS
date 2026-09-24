import Foundation

/// Raw API payload from agents.json: `ChatMessageContent`.
public struct ChatMessageContent: APIModel, Hashable {
    public var parts: [ChatMessagePart]?

    public init(
        parts: [ChatMessagePart]? = nil
    ) {
        self.parts = parts
    }

    private enum CodingKeys: String, CodingKey {
        case parts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        parts = try container.decodeIfPresent([ChatMessagePart].self, forKey: .parts)
    }
}
