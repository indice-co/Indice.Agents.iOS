import Foundation

/// Raw API payload from agents.json: `DexChatMessage`.
public struct DexChatMessage: APIModel, Hashable {
    public var messageId: String?
    public var authorName: String?
    public var role: DexChatRole?
    public var content: ChatMessageContent?
    public var createdAt: Date?
    public var liked: Bool?
    public var citations: [Citation]?
    public var sources: [SourceDocumentLink]?

    public init(
        messageId: String? = nil,
        authorName: String? = nil,
        role: DexChatRole? = nil,
        content: ChatMessageContent? = nil,
        createdAt: Date? = nil,
        liked: Bool? = nil,
        citations: [Citation]? = nil,
        sources: [SourceDocumentLink]? = nil
    ) {
        self.messageId = messageId
        self.authorName = authorName
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.liked = liked
        self.citations = citations
        self.sources = sources
    }

    private enum CodingKeys: String, CodingKey {
        case messageId, authorName, role, content, createdAt, liked, citations, sources
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageId = try container.decodeIfPresent(String.self, forKey: .messageId)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        role = try container.decodeIfPresent(DexChatRole.self, forKey: .role)
        content = try container.decodeIfPresent(ChatMessageContent.self, forKey: .content)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        liked = try container.decodeIfPresent(Bool.self, forKey: .liked)
        citations = try container.decodeIfPresent([Citation].self, forKey: .citations)
        sources = try container.decodeIfPresent([SourceDocumentLink].self, forKey: .sources)
    }
}
