import Foundation

/// Raw API payload from agents.json: `AgentLink`.
public struct AgentLink: APIModel, Hashable {
    public var type: String
    public var url: String

    public init(
        type: String,
        url: String
    ) {
        self.type = type
        self.url = url
    }

    private enum CodingKeys: String, CodingKey {
        case type, url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        url = try container.decode(String.self, forKey: .url)
    }
}
