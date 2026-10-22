import Foundation

/// Raw API payload from agents.json: `ConversationListItem`.
public struct ConversationListItem: APIModel, Hashable, Identifiable {
    public var id: UUID?
    public var title: String?
    public var createdAt: Date?
    public var lastActivityAt: Date?
    public var totalPromptTokens: Int64?
    public var totalCompletionTokens: Int64?
    public var pin: Bool?

    public init(
        id: UUID? = nil,
        title: String? = nil,
        createdAt: Date? = nil,
        lastActivityAt: Date? = nil,
        totalPromptTokens: Int64? = nil,
        totalCompletionTokens: Int64? = nil,
        pin: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.totalPromptTokens = totalPromptTokens
        self.totalCompletionTokens = totalCompletionTokens
        self.pin = pin
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, createdAt, lastActivityAt, totalPromptTokens, totalCompletionTokens, pin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        lastActivityAt = try container.decodeIfPresent(Date.self, forKey: .lastActivityAt)
        totalPromptTokens = try container.decodeAPINumberIfPresent(Int64.self, forKey: .totalPromptTokens)
        totalCompletionTokens = try container.decodeAPINumberIfPresent(Int64.self, forKey: .totalCompletionTokens)
        pin = try container.decodeIfPresent(Bool.self, forKey: .pin)
    }
}
