import Foundation

/// Raw API payload from agents.json: `AgentAuthor`.
public struct AgentAuthor: APIModel, Hashable {
    public var name: String
    public var email: String?
    public var url: String?

    public init(
        name: String,
        email: String? = nil,
        url: String? = nil
    ) {
        self.name = name
        self.email = email
        self.url = url
    }

    private enum CodingKeys: String, CodingKey {
        case name, email, url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        url = try container.decodeIfPresent(String.self, forKey: .url)
    }
}
