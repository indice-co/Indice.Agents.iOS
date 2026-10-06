import Foundation

/// Raw API payload from agents.json: `ChatRequest`.
public struct ChatRequest: APIModel, Hashable {
    public var text: String?
    public var authorName: String?
    public var agentName: String?

    public init(
        text: String? = nil,
        authorName: String? = nil,
        agentName: String? = nil
    ) {
        self.text = text
        self.authorName = authorName
        self.agentName = agentName
    }

    private enum CodingKeys: String, CodingKey {
        case text, authorName, agentName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        agentName = try container.decodeIfPresent(String.self, forKey: .agentName)
    }
}

extension ChatRequest: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self.init(text: value) }
}
