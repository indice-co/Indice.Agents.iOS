import Foundation

/// Raw API payload from agents.json: `DexConversation`.
public struct DexConversation: APIModel, Hashable {
    public var id: UUID?
    public var title: String?
    public var createdAt: Date?
    public var lastActivityAt: Date?
    public var messageCount: Int?
    public var usage: DexChatUsage?
    public var messages: [DexChatMessage]?

    public init(
        id: UUID? = nil,
        title: String? = nil,
        createdAt: Date? = nil,
        lastActivityAt: Date? = nil,
        messageCount: Int? = nil,
        usage: DexChatUsage? = nil,
        messages: [DexChatMessage]? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.messageCount = messageCount
        self.usage = usage
        self.messages = messages
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, createdAt, lastActivityAt, messageCount, usage, messages
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        lastActivityAt = try container.decodeIfPresent(Date.self, forKey: .lastActivityAt)
        messageCount = try container.decodeAPINumberIfPresent(Int.self, forKey: .messageCount)
        usage = try container.decodeIfPresent(DexChatUsage.self, forKey: .usage)
        messages = try container.decodeIfPresent([DexChatMessage].self, forKey: .messages)
    }
}
