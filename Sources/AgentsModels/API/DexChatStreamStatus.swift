import Foundation

public struct DexChatStreamStatus: APIModel, Hashable {
    public let type: String = "status"
    public var value: String

    public init(value: String) {
        self.value = value
    }

    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let type = try container.decodeIfPresent(String.self, forKey: .type), type != "status" {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unexpected stream discriminator")
        }
        value = try container.decode(String.self, forKey: .value)
    }
}

/// OpenAPI schema spelling; the shorter name mirrors the backend payload type.
public typealias DexChatResponseUpdateDexChatStreamStatus = DexChatStreamStatus
