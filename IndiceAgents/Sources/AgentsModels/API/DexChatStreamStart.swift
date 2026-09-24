import Foundation

public struct DexChatStreamStart: APIModel, Hashable {
    public let type: String = "start"
    public var conversationId: UUID?
    public var guestSession: GuestSession?

    public init(conversationId: UUID? = nil, guestSession: GuestSession? = nil) {
        self.conversationId = conversationId
        self.guestSession = guestSession
    }

    private enum CodingKeys: String, CodingKey {
        case type, conversationId, guestSession
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let type = try container.decodeIfPresent(String.self, forKey: .type), type != "start" {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unexpected stream discriminator")
        }
        conversationId = try container.decodeIfPresent(UUID.self, forKey: .conversationId)
        guestSession = try container.decodeIfPresent(GuestSession.self, forKey: .guestSession)
    }
}

/// OpenAPI schema spelling; the shorter name mirrors the backend payload type.
public typealias DexChatResponseUpdateDexChatStreamStart = DexChatStreamStart
