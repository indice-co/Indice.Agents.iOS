import Foundation

/// Raw API payload from agents.json: `DexChatResponse`.
public struct DexChatResponse: APIModel, Hashable {
    public var conversationId: UUID?
    public var responseId: String?
    public var messages: [DexChatMessage]?
    public var modelId: String?
    public var createdAt: Date?
    public var finishReason: DexChatFinishReason?
    public var usage: DexChatUsage?
    public var limitReached: Bool?
    public var guestSession: GuestSession?
    public var text: String?

    public init(
        conversationId: UUID? = nil,
        responseId: String? = nil,
        messages: [DexChatMessage]? = nil,
        modelId: String? = nil,
        createdAt: Date? = nil,
        finishReason: DexChatFinishReason? = nil,
        usage: DexChatUsage? = nil,
        limitReached: Bool? = nil,
        guestSession: GuestSession? = nil,
        text: String? = nil
    ) {
        self.conversationId = conversationId
        self.responseId = responseId
        self.messages = messages
        self.modelId = modelId
        self.createdAt = createdAt
        self.finishReason = finishReason
        self.usage = usage
        self.limitReached = limitReached
        self.guestSession = guestSession
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case conversationId, responseId, messages, modelId, createdAt, finishReason, usage, limitReached, guestSession, text
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conversationId = try container.decodeIfPresent(UUID.self, forKey: .conversationId)
        responseId = try container.decodeIfPresent(String.self, forKey: .responseId)
        messages = try container.decodeIfPresent([DexChatMessage].self, forKey: .messages)
        modelId = try container.decodeIfPresent(String.self, forKey: .modelId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        finishReason = try container.decodeIfPresent(DexChatFinishReason.self, forKey: .finishReason)
        usage = try container.decodeIfPresent(DexChatUsage.self, forKey: .usage)
        limitReached = try container.decodeIfPresent(Bool.self, forKey: .limitReached)
        guestSession = try container.decodeIfPresent(GuestSession.self, forKey: .guestSession)
        text = try container.decodeIfPresent(String.self, forKey: .text)
    }
}
