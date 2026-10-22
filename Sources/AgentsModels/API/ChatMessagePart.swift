import Foundation

/// Raw API payload from agents.json: `ChatMessagePart`.
public struct ChatMessagePart: APIModel, Hashable {
    public var value: String?
    public var contentType: String?
    public var name: String?

    public init(
        value: String? = nil,
        contentType: String? = nil,
        name: String? = nil
    ) {
        self.value = value
        self.contentType = contentType
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case value, contentType, name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        name = try container.decodeIfPresent(String.self, forKey: .name)
    }
}
