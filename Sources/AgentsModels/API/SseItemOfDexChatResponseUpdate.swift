import Foundation

/// Raw API payload from agents.json: `SseItemOfDexChatResponseUpdate`.
public struct SseItemOfDexChatResponseUpdate: APIModel, Hashable {
    public var data: DexChatResponseUpdate?
    public var eventType: String?
    public var eventId: String?
    public var reconnectionInterval: String?

    public init(
        data: DexChatResponseUpdate? = nil,
        eventType: String? = nil,
        eventId: String? = nil,
        reconnectionInterval: String? = nil
    ) {
        self.data = data
        self.eventType = eventType
        self.eventId = eventId
        self.reconnectionInterval = reconnectionInterval
    }

    private enum CodingKeys: String, CodingKey {
        case data, eventType, eventId, reconnectionInterval
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decodeIfPresent(DexChatResponseUpdate.self, forKey: .data)
        eventType = try container.decodeIfPresent(String.self, forKey: .eventType)
        eventId = try container.decodeIfPresent(String.self, forKey: .eventId)
        reconnectionInterval = try container.decodeIfPresent(String.self, forKey: .reconnectionInterval)
    }
}
