import Foundation
import AgentsModels

/// Server metadata for the active conversation, separate from its live messages.
/// Usage and message count describe the saved conversation, not local partial replies.
public struct ChatSessionMetadata: Sendable, Equatable {
    public let id: UUID?
    public let title: String?
    public let createdAt: Date?
    public let lastActivityAt: Date?
    public let messageCount: Int?
    public let usage: DexChatUsage?

    public init(
        id: UUID? = nil,
        title: String? = nil,
        createdAt: Date? = nil,
        lastActivityAt: Date? = nil,
        messageCount: Int? = nil,
        usage: DexChatUsage? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.messageCount = messageCount
        self.usage = usage
    }

    init(conversation: DexConversation, chatID: UUID) {
        self.init(
            id: chatID,
            title: conversation.title,
            createdAt: conversation.createdAt,
            lastActivityAt: conversation.lastActivityAt,
            messageCount: conversation.messageCount,
            usage: conversation.usage
        )
    }
}
