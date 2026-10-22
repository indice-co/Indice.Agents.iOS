import Foundation

/// Raw API payload from agents.json: `AgentCapability`.
public struct AgentCapability: APIModel, Hashable {
    public var name: String
    public var description: String

    public init(
        name: String,
        description: String
    ) {
        self.name = name
        self.description = description
    }

    private enum CodingKeys: String, CodingKey {
        case name, description
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
    }
}
